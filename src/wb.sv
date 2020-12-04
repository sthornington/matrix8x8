// attempt at a reusable wishbone interface
// I don't think this works at all on yosys?  everything gets implicitly declared...
interface wb
  #(
    parameter WB_DATA_WIDTH = 32,
    parameter WB_ADDR_WIDTH = 8,
    parameter WB_SEL_WIDTH = WB_DATA_WIDTH/8
    );

   // bus cycle
   logic                     wb_cyc;
   // strobe/valid
   logic                     wb_stb;
   // write-enable
   logic                     wb_we;
   // address
   logic [WB_ADDR_WIDTH-1:0] wb_addr;
   // byte-select
   logic [WB_SEL_WIDTH-1:0]  wb_sel;
   // write data
   logic [WB_DATA_WIDTH-1:0] wb_wdata;

   // strobe acknowledge
   logic                     wb_ack;
   // stall
   logic                     wb_stall;
   // read data
   logic [WB_DATA_WIDTH-1:0] wb_rdata;


   modport master (
                   output wb_cyc,
                   output wb_stb,
                   output wb_we,
                   output wb_addr,
                   output wb_sel,
                   output wb_wdata,
                   input  wb_ack,
                   input  wb_stall,
                   input  wb_rdata
                   );

   modport slave (
                  input  wb_cyc,
                  input  wb_stb,
                  input  wb_we,
                  input  wb_addr,
                  input  wb_sel,
                  input  wb_wdata,
                  output wb_ack,
                  output wb_stall,
                  output wb_rdata
                   );
endinterface
