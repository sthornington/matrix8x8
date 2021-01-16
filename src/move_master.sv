`default_nettype none

module matrix
  #(
    parameter WB_DATA_WIDTH = 32,
    parameter REG_COUNT = 8,
    parameter WB_ADDR_WIDTH = $clog2(REG_COUNT),
    parameter WB_SEL_WIDTH = WB_DATA_WIDTH / 8
    )
   (
    input logic                      clk,
    input logic                      reset,

    output logic                      o_wb_cyc,
    output logic                      o_wb_stb,
    output logic                      o_wb_we,
    output logic [WB_ADDR_WIDTH-1:0]  o_wb_addr,
    output logic [WB_SEL_WIDTH-1:0]   o_wb_sel,
    output logic [WB_DATA_WIDTH-1:0]  o_wb_wdata,

    input logic                     i_wb_ack,
    input logic                     i_wb_stall,
    input logic [WB_DATA_WIDTH-1:0] i_wb_rdata
    );

   // we are going to count through all the different row
   // possibilities (including the ignored fourth bit of each
   // xRGB combo) for each row
   localparam COUNTER_WIDTH = WB_DATA_WIDTH + WB_ADDR_WIDTH;

   reg [COUNTER_WIDTH-1:0]          counter;

   reg                              beat;
   initial beat = 0;

   always_comb
     beat = o_wb_cyc && o_wb_stb && !i_wb_stall;

   reg                              acked;
   initial acked = 0;

   always_comb
     acked = o_wb_cyc && o_wb_ack;

   always_ff @(posedge clk)
     // TODO:
