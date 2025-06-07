module flopr #(parameter WIDTH = 8) (
    input wire clk,
    input wire reset_n,
    input wire [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
    );

    always @(posedge clk, negedge reset_n)
        if (!reset_n)
            q <= 0;
        else
            q <= d;

endmodule