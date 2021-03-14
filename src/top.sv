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
    wire             wifi_gpio26 = gp[11];
    wire             wifi_gpio25 = gn[11];

    // in simon's st7789 the wires are crossed physically in the
    // cable so that the labels on the PCB are still correct
    assign oled_clk  = sd_clk;
    assign oled_mosi = sd_cmd;
    assign oled_dc   = wifi_gpio16;
    assign oled_csn  = wifi_gpio17;
    assign oled_resn = wifi_gpio25;

    // CLK is really the shift clock
    wire             matrix_clk = gp[27];
    // CE is really the output latch enable
    wire             matrix_latch = gp[26];
    // MOSI is the DS/shift data
    wire             matrix_mosi = gp[25];

    assign led[0] = matrix_clk;
    assign led[1] = matrix_latch;
    assign led[2] = matrix_mosi;
//    assign led[7:4] = 0;

    wire             locked;

    wire [3:0]       clocks;
    ecp5pll
      #(
        .in_hz(25000000),
        .out0_hz( 75000000), .out0_deg(  0), .out0_tol_hz(0),
        .out1_hz( 75000000), .out1_deg(  0), .out1_tol_hz(0),
        .out2_hz( 75000000), .out2_deg(  0), .out2_tol_hz(0),
        .out3_hz( 75000000), .out3_deg(  0), .out3_tol_hz(0)
        )
    ecp5pll_inst
      (
       .clk_i(clk_25mhz),
       .clk_o(clocks)
       );

    // TODO: WHY WON"T THIS WORK AT 100MHZ?
    wire             clk;
    assign clk = clocks[3];

    // matrix is a wishbone slave, 4 bytes x 8 addresses. byte select supported.
    // [.RGB.RGB] [.RGB.RGB] [.RGB.RGB] [.RGB.RGB]
    // ...
    // ergo 32 bits data width and 3 bits addr width, 4 bits byte sel width
    wire             wb_cyc;
    wire             wb_stb;
    wire             wb_we;
    wire [2:0]       wb_addr;
    wire [3:0]       wb_sel;
    wire [31:0]      wb_wdata;

    wire             wb_ack;
    wire             wb_stall;
    wire [31:0]      wb_rdata;


    // BEGIN DEBOUNCE RESET
    wire             db_btn_reset_raw;
    wire             db_btn_reset;

    debounce debounce_btn0(.clk(clk),
                           .i_btn(~btn[0]),
                           .o_btn(db_btn_reset_raw));

    assign db_btn_reset = db_btn_reset_raw || ~btn[0];
    // END DEBOUNCE RESET


    matrix matrix_0
      (
       .clk(clk),
//       .reset(db_btn_reset),
       .reset(db_btn_reset),
       .i_refresh_speed({btn[1], btn[2]}),
       .o_matrix_clk(matrix_clk),
       .o_matrix_latch(matrix_latch),
       .o_matrix_mosi(matrix_mosi),
       .i_wb_cyc(wb_cyc),
       .i_wb_stb(wb_stb),
       .i_wb_we(wb_we),
       .i_wb_addr(wb_addr),
       .i_wb_sel(wb_sel),
       .i_wb_wdata(wb_wdata),
       .o_wb_ack(wb_ack),
       .o_wb_stall(wb_stall),
       .o_wb_rdata(wb_rdata)
       );

    wire             db_btn6;


    debounce debounce_btn6(.clk(clk),
                           .i_btn(btn[6]),
                           .o_btn(db_btn6));

    wire             mm_pic_num;

    wire [3:0]       mm_dbg;


    move_master move_master_0
      (
       .clk(clk),
       .reset(db_btn_reset),
       .i_change(db_btn6),
       .o_pic_num(mm_pic_num),
       .o_dbg(mm_dbg),
       .o_wb_cyc(wb_cyc),
       .o_wb_stb(wb_stb),
       .o_wb_we(wb_we),
       .o_wb_addr(wb_addr),
       .o_wb_sel(wb_sel),
       .o_wb_wdata(wb_wdata),
       .i_wb_ack(wb_ack),
       .i_wb_stall(wb_stall),
       .i_wb_rdata(wb_rdata)
       );

    assign led[3] = mm_pic_num;
    assign led[7:4] = mm_dbg;



endmodule
