`default_nettype none

// a region of BRAM exposed with a wishbone slave, done by hand to learn how to write
// a verilog peripheral into a litex SoC
module bram
  #(
    REG_COUNT=8                  // # of addressable registers of BUS_WIDTH width
    )
   (
    input logic clk,   // clock
    input logic reset, // reset (active high)
    wb.slave wb_slave
    );
   localparam DATA_WIDTH = wb_slave.WB_DATA_WIDTH;

   reg [DATA_WIDTH-1:0] memory [REG_COUNT-1:0];

   if (REG_COUNT > 2**wb_slave.WB_ADDR_WIDTH)
     $error("addr bus too narrow to address memory");

   initial
     for (i=0;i<REG_COUNT;i++) memory[i] <= 0;

   // handling the main read/write operations.
   always_ff @(posedge clk) begin
      wb_slave.wb_ack <= 1'b0;
      if (wb_slave.wb_stb && !wb_slave.wb_stall) begin
         // do them alternately here to save the second BRAM port for the matrix
         if (wb_slave.wb_we) begin
            // handle the byte-select here
            for (i=0; i < wb_slave.WB_SEL_WIDTH; i++)
               if (wb_slave.wb_sel[i])
                 memory[wb_slave.wb_addr][(i*8)+7:i*8] <= wb_slave.wb_wdata[(i*8)+7:i*8];
         end
         else
           wb_slave.wb_rdata <= memory[i_wb_addr];

         wb_slave.wb_ack <= 1'b1;
      end
      if (reset) begin
         for (i=0;i<REG_COUNT;i++) memory[i] <= 0;

         wb_slave.wb_rdata <= BUS_WIDTH'd0;
         wb_slave.wb_ack <= 1'b0;
      end
   end

   // this peripheral cannot stall
   always_comb
     wb_slave.wb_stall = 1'b1;

endmodule
