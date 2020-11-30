`default_nettype none

// driver for 8x8 RGB LED matrix which has 74HC595D chips on board
// like https://leeselectronic.com/en/product/18116.html
module matrix
  (
   input wire       clk,
   input wire [1:0] refresh_speed,
   output wire      matrix_clk,
   output wire      matrix_latch, // labelled CE on my PCB
   output wire      matrix_mosi
   );

   localparam        SERIAL_CLOCK_COUNTER_BITS_FAST = 2;
   localparam        SERIAL_CLOCK_COUNTER_BITS_MEDIUM = 12;
   localparam        SERIAL_CLOCK_COUNTER_BITS_SLOW = 16;

   logic [SERIAL_CLOCK_COUNTER_BITS_SLOW-1:0] r_counter;
   logic                                      r_serial_clk_a;
   logic                                      r_serial_clk_b;
   logic                                      r_serial_clk_c;

   // set up the r_counter for the serial clock
   always_ff @(posedge clk)
      r_counter <= r_counter + 1;

   // calc r_serial_clk and previous
   always_ff @(posedge clk) begin
      case (refresh_speed)
        2'b01:
          r_serial_clk_a <= r_counter[SERIAL_CLOCK_COUNTER_BITS_MEDIUM-1];
        2'b10:
          r_serial_clk_a <= r_counter[SERIAL_CLOCK_COUNTER_BITS_SLOW-1];
        default:
          r_serial_clk_a <= r_counter[SERIAL_CLOCK_COUNTER_BITS_FAST-1];
      endcase
   end // always_ff @ (posedge clk)

   always_ff @(posedge clk)
     r_serial_clk_b <= r_serial_clk_a;

   always_ff @(posedge clk)
     r_serial_clk_c <= r_serial_clk_b;

   logic                                      r_serial_clk;
   // _a is to break a long wire, b is the real clock and c is it's prev
   // value
   assign r_serial_clk = r_serial_clk_b;

   logic r_serial_posedge;
   logic r_serial_negedge;

   always_comb begin
      r_serial_posedge <= r_serial_clk_b == 1'b0 && r_serial_clk_c == 1'b1;
      r_serial_negedge <= r_serial_clk_b == 1'b1 && r_serial_clk_c == 1'b0;
   end

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

   logic [2:0] r_col_num = 0;
   logic [2:0] r_row_num = 0;
   logic   r_matrix_clk;
   logic   r_matrix_latch;
   logic   r_matrix_mosi;

   initial begin
      r_state = RESET;
      r_prev_state = RESET;
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
      r_matrix_clk <= loading && r_serial_clk;
   end

   // latching data into the output register data into shift register
   logic latching = 0;

   always_comb
     latching = r_prev_state == LATCH;

   // the latch clock is running whenever we are latching the outputs
   always_ff @(posedge clk) begin
      r_matrix_latch <= latching && r_serial_clk;
   end

   always_comb begin
      matrix_clk = r_matrix_clk;
      matrix_latch = r_matrix_latch;
      matrix_mosi = r_matrix_mosi;
   end

   logic [4:0] r_pause_counter = 0;
   logic [4:0] reset_counter = 0;

   logic [7:0] r_refresh_counter = 0;
   logic [1:0] refresh_mod_3;
   logic [1:0] r_refresh_mod_3;

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
             reset_counter <= reset_counter + 1;
             if (reset_counter == 5'd31)
               r_state <= LATCH;
          end
          RED: begin
             // color is active-low
             r_matrix_mosi <= ~(r_col_num[0] && (r_refresh_mod_3 == 2'b00));
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) r_state <= BLUE;
          end
          BLUE: begin
             r_matrix_mosi <=  ~(r_col_num[1] && (r_refresh_mod_3 == 2'b01));
             r_col_num <= r_col_num + 1;
             if (r_col_num == 3'b111) r_state <= GREEN;
          end
          GREEN: begin
             r_matrix_mosi <=  ~(r_col_num[2] && (r_refresh_mod_3 == 2'b10));
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
             if (r_pause_counter == 5'hff) begin
                r_state <= RED;
                if (r_row_num == 3'b000)
                  r_refresh_counter <= r_refresh_counter + 1;
             end
          end
        endcase
     end // if (r_serial_negedge)
   end

endmodule
