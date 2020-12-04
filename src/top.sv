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

   assign wifi_gpio0 = 1'b1;
//   assign wifi_en    = btn[0];
   assign wifi_en    = 1'b1;

   // passthru to ESP32 micropython serial console
   assign wifi_rxd = ftdi_txd;
   assign ftdi_rxd = wifi_txd;

   // wifi aliasing for shared pinns
   wire              wifi_gpio26 = gp[11];
   wire              wifi_gpio25 = gn[11];

   // in simon's st7789 the wires are crossed physically in the
   // cable so that the labels on the PCB are still correct
   assign oled_clk  = sd_clk;
   assign oled_mosi = sd_cmd;
   assign oled_dc   = wifi_gpio16;
   assign oled_csn  = wifi_gpio17;
   assign oled_resn = wifi_gpio25;

   // CLK is really the shift clock
   wire  matrix_clk = gp[27];
   // CE is really the output latch enable
   wire  matrix_latch = gp[26];
   // MOSI is the DS/shift data
   wire  matrix_mosi = gp[25];

   assign led[0] = matrix_clk;
   assign led[1] = matrix_latch;
   assign led[2] = matrix_mosi;
   assign led[7:3] = 0;

   wire  clk_100mhz;
   wire  locked;

   pll pll_0 ( clk_25mhz,
               clk_100mhz,
               locked );

   matrix matrix_0 ( .clk(clk_100mhz),
                     .reset(btn[3]),
                     .refresh_speed({btn[1], btn[2]}),
                     .matrix_clk,
                     .matrix_latch,
                     .matrix_mosi
                    );


endmodule
