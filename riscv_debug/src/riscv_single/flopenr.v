// flip flop with enable and reset
module flopenr #(parameter WIDTH = 8) (
    input wire clk,
    input wire reset_n,
    input wire en,
    input wire [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q);

    always @(posedge clk, negedge reset_n)
        if (!reset_n)
            q <= 0;
        else if (en)
            q <= d;

endmodule