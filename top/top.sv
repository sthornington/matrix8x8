`default_nettype none

module top
  (
   input wire        clk_25mhz,
   input wire [6:0]  btn,
   output wire [7:0] led,
   inout wire [27:0] gp,gn,
   output wire       oled_csn,
   output wire       oled_clk,
   output wire       oled_mosi,
   output wire       oled_dc,
   output wire       oled_resn,
   input wire        ftdi_txd,
   output wire       ftdi_rxd,
   inout wire        sd_clk, sd_cmd,
   inout wire [3:0]  sd_d,
   output wire       wifi_en,
   input wire        wifi_txd,
   output wire       wifi_rxd,
   input wire        wifi_gpio16,
   input wire        wifi_gpio17,
   //output wire wifi_gpio5,
   output wire       wifi_gpio0
   );

   localparam        SERIAL_CLOCK_COUNTER_BITS_FAST = 2;
   localparam        SERIAL_CLOCK_COUNTER_BITS_MEDIUM = 12;
   localparam        SERIAL_CLOCK_COUNTER_BITS_SLOW = 16;
   logic             reset;
   wire              clk = clk_25mhz;

   assign wifi_gpio0 = 1'b1;
//   assign wifi_en    = btn[0];
// do we need a reset?  would it even work?
// we would need to feed through a full 32 bits of
// zeros for LEDs and ones for rows to reset every
// row to blank, then after latching that, we should
// be back to square one
//   assign reset      = btn[0];
   assign wifi_en    = 1'b1;

   // passthru to ESP32 micropython serial console
   assign wifi_rxd = ftdi_txd;
   assign ftdi_rxd = wifi_txd;

   // wifi aliasing for shared pins
   wire              wifi_gpio26 = gp[11];
   wire              wifi_gpio25 = gn[11];

   // in simon's st7789 the wires are crossed physically in the
   // cable so that the labels on the PCB are still correct
   assign oled_clk  = sd_clk;
   assign oled_mosi = sd_cmd;
   assign oled_dc   = wifi_gpio16;
   assign oled_csn  = wifi_gpio17;
   assign oled_resn = wifi_gpio25;

   logic [SERIAL_CLOCK_COUNTER_BITS_SLOW-1:0] counter;
   logic                                      serial_clk;
   logic                                      prev_serial_clk;

   // if true, do a fast scan, otherwise scan slow enough to be visible
   enum                                       { SLOW, MEDIUM, FAST } mode;

   initial mode = FAST;

   always_comb
     if (btn[1])
       mode = MEDIUM;
     else begin
        if (btn[2])
          mode = SLOW;
        else
          mode = FAST;
     end


   // set up the counter for the serial clock
   always_ff @(posedge clk)
      counter <= counter + 1;

   // calc serial_clk and previous
   always_ff @(posedge clk) begin
      // this could be combinational
      prev_serial_clk <= serial_clk;
      case (mode)
        FAST: serial_clk <= counter[SERIAL_CLOCK_COUNTER_BITS_FAST-1];
        MEDIUM: serial_clk <= counter[SERIAL_CLOCK_COUNTER_BITS_MEDIUM-1];
        SLOW: serial_clk <= counter[SERIAL_CLOCK_COUNTER_BITS_SLOW-1];
      endcase
   end

   logic serial_posedge;
   logic serial_negedge;

   always_comb begin
      serial_posedge = prev_serial_clk == 1'b0 && serial_clk == 1'b1;
      serial_negedge = prev_serial_clk == 1'b1 && serial_clk == 1'b0;
   end

   // we need to constantly scan through:
   // 8 bits of red
   // 8 bits of blue
   // 8 bits of green
   // 8 bits of row anodes
   // raise latch/clock-enable
   // lower latch/clock-enable
   // ...
   // repeat that for each row
   typedef enum bit[2:0] { RESET, RED, BLUE, GREEN, ROW_ANODE, LATCH, PAUSE } state_t;
   state_t r_state;
   state_t r_prev_state;

   logic [2:0] col_num = 0;
   logic [2:0] row_num = 0;

   // CLK is really the shift clock
   wire  matrix_clk = gp[27];
   // CE is really the output latch enable
   wire  matrix_ce = gp[26];
   // MOSI is the DS/shift data
   wire  matrix_mosi = gp[25];

   logic   r_matrix_clk;
   logic   r_matrix_ce;
   logic   r_matrix_mosi;

   initial begin
      r_state = RESET;
      r_prev_state = RESET;
      r_matrix_clk = 0;
      r_matrix_ce = 0;
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
      r_matrix_ce <= latching && serial_clk;
   end

   always_comb begin
      matrix_clk = r_matrix_clk;
      matrix_ce = r_matrix_ce;
      matrix_mosi = r_matrix_mosi;
   end

   logic [4:0] pause_counter = 0;
   logic [4:0] reset_counter = 0;

   logic [7:0] refresh_counter = 0;
   logic [1:0] refresh_mod_3 = 0;

   always_comb
     refresh_mod_3 = refresh_counter % 3;

   // catch the serial clk edge to run state
   always_ff @(posedge clk) begin
     // set up MOSI and change states after negedge
     if (serial_negedge) begin
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
             r_matrix_mosi <= ~(col_num[0] && (refresh_mod_3 == 2'b00));
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= BLUE;
          end
          BLUE: begin
             r_matrix_mosi <=  ~(col_num[1] && (refresh_mod_3 == 2'b01));
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= GREEN;
          end
          GREEN: begin
             r_matrix_mosi <=  ~(col_num[2] && (refresh_mod_3 == 2'b10));
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= ROW_ANODE;
          end
          ROW_ANODE: begin
             r_matrix_mosi <= (row_num == col_num);
             col_num <= col_num + 1;
             if (col_num == 3'b111) begin
                row_num <= row_num + 1;
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
             pause_counter <= pause_counter + 1;
             if (pause_counter == 5'hff) begin
                r_state <= RED;
                if (row_num == 3'b000)
                  refresh_counter = refresh_counter + 1;
             end
          end
        endcase
     end // if (serial_negedge)
   end

   assign led[0] = matrix_clk;
   assign led[1] = matrix_ce;
   assign led[2] = matrix_mosi;
   assign led[3] = loading;
   assign led[4] = 1'b0;
   assign led[7:5] = r_state;


endmodule
