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
   wire              clk = clk_25mhz;
   assign wifi_gpio0 = 1'b1;;
   assign wifi_en    = btn[0];

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

   assign led[4:0] = {oled_csn,oled_dc,oled_resn,oled_mosi,oled_clk};
   assign led[6:5] = 0;
   assign led[7] = wifi_en;

endmodule
