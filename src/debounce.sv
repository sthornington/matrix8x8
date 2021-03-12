`default_nettype none

module debounce(input logic  clk,
                input logic  i_btn,
                output logic o_btn);
    wire clk_en;

    reg [26:0] counter=0;

    always_ff @(posedge clk)
      counter <= (counter >= 249999) ? 0 : counter+1;

    assign clk_en = (counter == 249999) ? 1'b1 : 1'b0;

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
