`default_nettype none

module debounce(input logic  clk,
                input logic  i_btn,
                output logic o_btn);
    localparam WIDTH = 18;
    // 0x03ffff is ~1/4 of a second
    localparam MAX = {WIDTH{1'b1}};
    reg [WIDTH-1:0] counter=0;
    wire clk_en;

    always_ff @(posedge clk) begin
        counter <= counter + 1;
    end

    assign clk_en = counter == MAX;

    reg        q0;
    reg        q1;
    reg        q2;

    always_ff @(posedge clk) begin
        if (clk_en == 1'b1) begin
            q0 <= i_btn;
            q1 <= q0;
            q2 <= q1;
        end
        o_btn <= q1 && ~q2;
    end
endmodule // debounce
