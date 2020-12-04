`default_nettype none

// a region of BRAM exposed with a wishbone slave, done by hand to learn how to write
// a verilog peripheral into a litex SoC
module bram
  #(
    BUS_WIDTH=32,                 // the data width of the wishbone bus
    REG_COUNT=8,                  // # of addressable registers of BUS_WIDTH width
    ADDR_WIDTH=$clog2(REG_COUNT)  // # of addr bits necessary to address REG_COUNT
    )
   (
    input wire                  clk, // clock
    input wire                  reset, // reset (active high)
    input wire                  i_wb_cyc, // bus cycle
    input wire                  i_wb_stb, // strobe/valid
    input wire                  i_wb_we, // write-enable
    input wire [ADDR_WIDTH-1:0] i_wb_addr, // address
    input wire [BUS_WIDTH-1:0]  i_wb_data, // write data
    output wire                 o_wb_ack, // strobe acknowledge
    output wire                 o_wb_stall, // stall
    output wire [BUS_WIDTH-1:0] o_wb_data   // write data
    );

    // initial memory is nibble-wide 0bxRGB
    // the matrix is 8x8, so each row is four bytes, which is conveniently a
    // 32-bit bus width.
    reg [BUS_WIDTH-1:0] memory [REG_COUNT-1:0];

   // handling the main read/write operations.
   always_ff @(posedge clk) begin
      o_wb_ack <= 1'b0;
      if (i_wb_stb && !o_wb_stall) begin
         // do them alternately here to save the second BRAM port for the matrix
         if (i_wb_we) begin
            memory[i_wb_addr] <= i_wb_data;
            o_wb_data <= i_wb_data;
         end
         else
           o_wb_data <= memory[i_wb_addr];
         o_wb_ack <= 1'b1;
      end
      if (reset) begin
         for (i=0;i<REG_COUNT;i++) memory[i] <= 0;
//         memory <= '{default:BUS_WIDTH'd0};
         o_wb_data <= BUS_WIDTH'd0;
         o_wb_ack <= 1'b0;
      end
   end

   // this peripheral cannot stall
   always_comb
     o_wb_stall = 1'b1;

endmodule
