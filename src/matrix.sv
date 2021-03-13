`default_nettype none

// driver for 8x8 RGB LED matrix which has 74HC595D chips on board
// like https://leeselectronic.com/en/product/18116.html
module matrix
  #(
    parameter WB_DATA_WIDTH = 32,
    parameter REG_COUNT = 8, // this can't really be changed but informs the addr width
    parameter WB_ADDR_WIDTH = $clog2(REG_COUNT),
    parameter WB_SEL_WIDTH = WB_DATA_WIDTH / 8
    )
  (
   input logic                      clk,
   input logic                      reset,
   input logic [1:0]                i_refresh_speed,
   output logic                     o_matrix_clk,
   output logic                     o_matrix_latch, // labelled CE on my PCB
   output logic                     o_matrix_mosi,

   input logic                      i_wb_cyc,
   input logic                      i_wb_stb,
   input logic                      i_wb_we,
   input logic [WB_ADDR_WIDTH-1:0]  i_wb_addr,
   input logic [WB_SEL_WIDTH-1:0]   i_wb_sel,
   input logic [WB_DATA_WIDTH-1:0]  i_wb_wdata,

   output logic                     o_wb_ack,
   output logic                     o_wb_stall,
   output logic [WB_DATA_WIDTH-1:0] o_wb_rdata
   );

   // *** BEGIN SLAVE INTERFACE STUFF ***

   // we have 8x 32bit registers for now since we are doing
   // nibble-wise allocation to each RGB LED as 0bxRGB
   // so each row of 8x4bits will fit in a 32bit bus width,
   // and we have 8 rows
   reg [WB_DATA_WIDTH-1:0] memory [REG_COUNT-1:0];
   reg                     r_ack = 0;
   reg [WB_DATA_WIDTH-1:0] r_rdata = 0;

   integer                 i;

   // handling the main read/write operations.
   always_ff @(posedge clk) begin
      r_ack <= 1'b0;
      if (i_wb_stb && !o_wb_stall) begin
         // do them alternately here to save the second BRAM port for the matrix
         if (i_wb_we) begin
            // handle the byte-select here
            for (i=0; i < WB_SEL_WIDTH; i=i+1)
              if (i_wb_sel[i])
                memory[i_wb_addr][(i*8)+7:i*8] <= i_wb_wdata[(i*8)+7:i*8];

         end
         else
           r_rdata <= memory[i_wb_addr];
         // ack it right away
         r_ack <= 1'b1;
      end
      if (reset) begin

        for (i=0;i<REG_COUNT;i++) begin
           memory[i] = 32'h66336633;
         end

/*
         // hardcode a silly picture here until we implement the wishbone master
         memory[0] <= 32'h00666600;
         memory[1] <= 32'h06000060;
         memory[2] <= 32'h60500506;
         memory[3] <= 32'h60000006;
         memory[4] <= 32'h60300306;
         memory[5] <= 32'h60033006;
         memory[6] <= 32'h06000060;
         memory[7] <= 32'h00666600;
*/
         r_rdata <= WB_DATA_WIDTH'd0;
         r_ack <= 1'b0;
      end
   end // always_ff @ (posedge clk)

   // this peripheral cannot stall
   assign o_wb_stall = 1'b0;
   assign o_wb_ack = r_ack;
   assign o_wb_rdata = r_rdata;

   // *** END SLAVE INTERFACE STUFF ***

   // *** BEGIN SLOW SERIAL CLOCK STUFF ***
   localparam        SERIAL_CLOCK_COUNTER_BITS_FAST = 4;
   localparam        SERIAL_CLOCK_COUNTER_BITS_MEDIUM = 14;
   localparam        SERIAL_CLOCK_COUNTER_BITS_SLOW = 18;

   logic [SERIAL_CLOCK_COUNTER_BITS_SLOW-1:0] r_counter;
   logic                                      r_serial_clk;
   logic                                      r_serial_clk_prev;
   logic                                      r_serial_clk_prev2;

   // set up the r_counter for the serial clock
   always_ff @(posedge clk)
      r_counter <= r_counter + 1;

   // calc r_serial_clk and previous
   always_ff @(posedge clk) begin
     r_serial_clk_prev2 <= r_serial_clk_prev;
     r_serial_clk_prev <= r_serial_clk;
      case (i_refresh_speed)
        2'b01:
          r_serial_clk <= r_counter[SERIAL_CLOCK_COUNTER_BITS_MEDIUM-1];
        2'b10:
          r_serial_clk <= r_counter[SERIAL_CLOCK_COUNTER_BITS_SLOW-1];
        default:
          r_serial_clk <= r_counter[SERIAL_CLOCK_COUNTER_BITS_FAST-1];
      endcase
   end // always_ff @ (posedge clk)

   // we are trying to stagger the serial clock stages to gain some MHz, just
   // for fun to try and break 100MHz (even though the matrix cannot handle that)
   logic serial_clk;
   assign serial_clk = r_serial_clk_prev;
   logic serial_clk_prev;
   assign serial_clk_prev = r_serial_clk_prev2;

   logic r_serial_posedge;
   logic r_serial_negedge;

   always_ff @(posedge clk) begin
      r_serial_posedge <= serial_clk_prev == 1'b0 && serial_clk == 1'b1;
      r_serial_negedge <= serial_clk_prev == 1'b1 && serial_clk == 1'b0;
   end

   // *** END SLOW SERIAL CLOCK STUFF ***

   // *** BEGIN PAINTING STATE MACHINE STUFF ***

   // the shift registers are 32 bits long,
   // 8x red, 8x green, 8x blue, 8x row anode
   // in our state machine, we split out the paints of
   // RED/GREEN/BLUE into entirely separate paints of the whole
   // matrix, mostly because the ULX3S power supply doesn't seem
   // sufficient to drive many of the LEDs at the same time, so
   // if you try to paint a row with RGB all somewhat on, the blues
   // won't get enough power to light up.
   typedef enum bit[2:0] { RESET, RED, BLUE, GREEN, ROW_ANODE, LATCH, PAUSE } state_t;
   state_t r_state;
   state_t r_prev_state;

   logic [2:0]  r_col_num;
   logic [2:0]  r_row_num;
   logic        r_matrix_clk;
   logic        r_matrix_latch;
   logic        r_matrix_mosi;

   initial begin
      r_state = RESET;
      r_prev_state = RESET;
      r_col_num = 0;
      r_row_num = 0;
      r_matrix_clk = 0;
      r_matrix_latch = 0;
      r_matrix_mosi = 0;
   end

   // loading data into shift register
   logic loading = 0;

   always_comb
     loading = r_prev_state == RESET ||
               r_prev_state == RED ||
               r_prev_state == BLUE ||
               r_prev_state == GREEN ||
               r_prev_state == ROW_ANODE;

   // the shift clock is running whenever we are shifting data in
   always_ff @(posedge clk) begin
      r_matrix_clk <= loading && serial_clk;
   end

   // latching data into the output register data into shift register
   logic latching = 0;

   always_comb
     latching = r_prev_state == LATCH;

   // the latch clock is running whenever we are latching the outputs
   always_ff @(posedge clk) begin
      r_matrix_latch <= latching && serial_clk;
   end

   assign o_matrix_clk = r_matrix_clk;
   assign o_matrix_latch = r_matrix_latch;
   assign o_matrix_mosi = r_matrix_mosi;

   logic [4:0] r_pause_counter;
   logic [7:0] r_reset_counter;

   logic [7:0] r_refresh_counter;
   logic [1:0] refresh_mod_3;
   logic [1:0] r_refresh_mod_3;

   initial begin
      r_pause_counter = 0;
      r_reset_counter = 0;
      r_refresh_counter = 0;
   end

   // this keeps the current value of red/green/blue handy
   logic [31:0] current_word;
   logic [3:0]  current_nibble;
   logic        current_red;
   logic        current_blue;
   logic        current_green;

   always_comb begin
      current_word = memory[r_row_num];
      current_nibble = (current_word >> 4*(7-r_col_num)) & 4'hf;
      current_red = |(current_nibble & 4'b0100);
      current_green = |(current_nibble & 4'b0010);
      current_blue = |(current_nibble & 4'b0001);
   end



// simpler implementation but much lower fmax
//   always_comb
//     refresh_mod_3 = r_refresh_counter % 3;
   syn_mod3_32 #(.WIDTH(8)) mod3(.in(r_refresh_counter), .out(refresh_mod_3));

   always_ff @(posedge clk)
     r_refresh_mod_3 <= refresh_mod_3;

   // catch the serial clk edge to run state
   always_ff @(posedge clk) begin
     // set up MOSI and change states after negedge
     if (r_serial_negedge) begin
        r_prev_state <= r_state;
        case (r_state)
          RESET: begin
             r_matrix_mosi <= 1'b1;
             r_reset_counter <= r_reset_counter + 1;
             if (r_reset_counter == 8'hff)
               r_state <= LATCH;
          end
          RED: begin
             // color is active-low
             r_matrix_mosi <= ~(current_red && (r_refresh_mod_3 == 2'b00));
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) r_state <= BLUE;
          end
          BLUE: begin
             r_matrix_mosi <=  ~(current_blue && (r_refresh_mod_3 == 2'b01));
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) r_state <= GREEN;
          end
          GREEN: begin
             r_matrix_mosi <=  ~(current_green && (r_refresh_mod_3 == 2'b10));
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) r_state <= ROW_ANODE;
          end
          ROW_ANODE: begin
             r_matrix_mosi <= (r_row_num == r_col_num);
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) begin
                r_row_num <= r_row_num + 1;
                r_state <= LATCH;
             end
          end
          LATCH: begin
             // not really necessary since the shift clock will not fire next
             r_matrix_mosi <= 1'b0;
             r_state <= PAUSE;
          end
          PAUSE: begin
             // end of row
             r_pause_counter <= r_pause_counter + 1;
             if (r_pause_counter == 5'b11111) begin
                r_state <= RED;
                if (r_row_num == 3'b000)
                  r_refresh_counter <= r_refresh_counter + 1;
             end
          end
        endcase
     end // if (r_serial_negedge)
      // handle reset
      if (reset) begin
         r_state <= RESET;
         r_prev_state <= RESET;
         r_matrix_mosi <= 1'b1;
         r_col_num <= 0;
         r_row_num <= 0;
         r_refresh_counter <= 0;
         r_reset_counter <= 0;
      end
   end

   // *** END PAINTING STATE MACHINE STUFF ***

endmodule
