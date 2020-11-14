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

   localparam        SERIAL_CLOCK_COUNTER_BITS = 15;
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

   logic [SERIAL_CLOCK_COUNTER_BITS-1:0] counter;
   logic                                 serial_clk;
   logic                                 prev_serial_clk;

   // set up the counter for the serial clock
   always_ff @(posedge clk)
      counter <= counter + 1;

   // calc serial_clk and previous
   always_ff @(posedge clk) begin
      // this could be combinational
      prev_serial_clk <= serial_clk;
      serial_clk <= counter[SERIAL_CLOCK_COUNTER_BITS-1];
   end

   logic serial_posedge;
   logic serial_negedge;

   always_comb begin
      serial_posedge = serial_clk == 1'b1 && prev_serial_clk == 1'b0;
      serial_negedge = serial_clk == 1'b0 && prev_serial_clk == 1'b1;
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
   enum bit[6:0] {
                RESET     = 7'b0000001,
                RED       = 7'b0000010,
                BLUE      = 7'b0000100,
                GREEN     = 7'b0001000,
                ROW_ANODE = 7'b0010000,
                LATCH     = 7'b0100000,
                PAUSE     = 7'b1000000} r_state;

   logic [2:0] col_num = 0;
   logic [2:0] row_num = 0;

   wire  matrix_clk = gp[0];
   wire  matrix_ce = gp[1];
   wire  matrix_mosi = gp[2];

//   wire  matrix_clk = gnp[0];
//   wire  matrix_ce = gn[1];
//   wire  matrix_mosi = gn[2];

   logic   r_matrix_ce;
   logic   r_matrix_mosi;

   initial begin
      r_state = RESET;
      r_matrix_ce = 0;
      r_matrix_mosi = 0;
   end

   always_comb
     matrix_clk = serial_clk;

   assign led[0] = matrix_clk;
   assign led[1] = matrix_ce;
   assign led[7:2] = r_state[5:0];

   logic [7:0] pause_counter = 0;
   logic [7:0] reset_counter = 0;

   // catch the serial clk edge to work state
   always_ff @(posedge clk)
     // set up during negedge
     if (serial_negedge) begin
        case (r_state)
          RESET: begin
             // unlatch/free
             r_matrix_ce <= 1'b0;
             r_matrix_mosi <= 1'b1;
             reset_counter <= reset_counter + 1;
             if (reset_counter == 8'hff)
               r_state <= RED;
          end
          RED: begin
             // unlatch/free
             r_matrix_ce <= 1'b0;
             r_matrix_mosi <= 1'b0;
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= BLUE;
          end
          BLUE: begin
             r_matrix_mosi <= 1'b1;
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= GREEN;
          end
          GREEN: begin
             r_matrix_mosi <= 1'b0;
             col_num <= col_num + 1;
             if (col_num == 3'b111) r_state <= ROW_ANODE;
          end
          ROW_ANODE: begin
//             r_matrix_mosi <= (row_num == col_num);
             r_matrix_mosi <= 1'b1;
             col_num <= col_num + 1;
             if (col_num == 3'b111) begin
                row_num <= row_num + 1;
                // latch
                r_matrix_ce <= 1'b1;
                r_state <= RED;
             end
          end
          PAUSE: begin
             // end of row
             pause_counter <= pause_counter + 1;
             if (pause_counter == 8'hff)
               r_state <= RED;
          end
        endcase
     end // if (serial_negedge)

endmodule
