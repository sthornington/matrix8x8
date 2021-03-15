`default_nettype none

module move_master
  #(
    parameter WB_DATA_WIDTH = 32,
    parameter REG_COUNT = 8,
    parameter WB_ADDR_WIDTH = $clog2(REG_COUNT),
    parameter WB_SEL_WIDTH = WB_DATA_WIDTH / 8
    )
    (
     input logic                      clk,
     input logic                      reset, // active high

     input logic                      i_change, // change the picture

     output logic                     o_pic_num, // what picture are we on
     output logic [3:0]               o_dbg,

     output logic                     o_wb_cyc,
     output logic                     o_wb_stb,
     output logic                     o_wb_we,
     output logic [WB_ADDR_WIDTH-1:0] o_wb_addr,
     output logic [WB_SEL_WIDTH-1:0]  o_wb_sel,
     output logic [WB_DATA_WIDTH-1:0] o_wb_wdata,

     input logic                      i_wb_ack,
     input logic                      i_wb_stall,
     input logic [WB_DATA_WIDTH-1:0]  i_wb_rdata
     );

    // what was i_change before
    reg                               r_change;

    always_ff @(posedge clk)
      r_change <= i_change;

    // which picture are we showing
    reg                               r_pic = 1'b0;
    reg                               r_loading = 0;
    reg [3:0]                         r_load_num = 0;

    always_ff @(posedge clk) begin
        if (beat && r_row == 7)
            r_loading <= 0;

        if (i_change && !r_change) begin
            r_pic <= r_pic + 1;
            r_loading <= 1; // trigger a load
            r_load_num <= r_load_num + 1;
        end
        if (reset) begin
            r_pic <= 0;
            r_loading <= 0;
        end
    end

    assign o_pic_num = r_pic;
    assign o_dbg = {r_loading, r_row};

    always_comb begin
        if (!reset) begin
            o_wb_cyc = r_loading;
            o_wb_stb = r_loading;
            o_wb_we = r_loading;
        end else
        begin
            o_wb_cyc = 1'b0;
            o_wb_stb = 1'b0;
            o_wb_we = 1'b0;
        end
    end

    // beat is a single completed transaction.
    // TODO: must we wait for ACK here?
    reg                               beat = 0;
    always_comb
      beat = o_wb_cyc && o_wb_stb && !i_wb_stall;

    // init to -1 so we load up 0
    reg [WB_ADDR_WIDTH-1:0]           r_row = 0;
    logic [WB_ADDR_WIDTH-1:0]         next_row;

    // keep the address and data lines always populated with the data
    // and just roll the counter on beat
    always_comb begin
        o_wb_addr = r_row;

        // assign the correct data, don't worry about tearing
        case (r_pic)
          1'b0:
            case (r_row)
              0: o_wb_wdata = 32'h00666600;
              1: o_wb_wdata = 32'h06000060;
              2: o_wb_wdata = 32'h60500506;
              3: o_wb_wdata = 32'h60000006;
              4: o_wb_wdata = 32'h60033006;
              5: o_wb_wdata = 32'h60300306;
              6: o_wb_wdata = 32'h06000060;
              7: o_wb_wdata = 32'h00666600;
            endcase
          1'b1:
            case (r_row)
              0: o_wb_wdata = 32'h05500550;
              1: o_wb_wdata = 32'h54455445;
              2: o_wb_wdata = 32'h54444445;
              3: o_wb_wdata = 32'h54444445;
              4: o_wb_wdata = 32'h54444445;
              5: o_wb_wdata = 32'h05444450;
              6: o_wb_wdata = 32'h00544500;
              7: o_wb_wdata = 32'h00055000;
            endcase
        endcase
    end

    // state machine for bus master
    // TODO: ignore acks for now!
    always_ff @(posedge clk) begin
        if (beat) begin
            r_row <= r_row + 1;
        end
        if (reset)
          r_row <= 0;
    end

    assign o_wb_sel = ~0;

endmodule
