module dmem(

    // input
    input wire clk,
    input wire reset_n,
    input wire we,
    input wire [31:0] a, 
    input wire [31:0] wd,

    // output
    output wire [31:0] rd,
    output wire led

);

    reg [31:0] RAM[63:0];

    reg temp_led;
    assign led = temp_led;

    // read
    assign rd = RAM[a[31:2]]; // word aligned  

    // write
    always @(posedge clk)
    begin

        if (reset_n == 1'b0)
        begin
            //temp_led = 1'b0;
            temp_led = ~temp_led;
        end
        else
        begin
            temp_led = ~temp_led;
        end

        if (we)
        begin
            RAM[a[31:2]] <= wd;
        end

    end

endmodule