module riscvsingle(

    input wire clk, 
    input wire reset_n,
    output wire [31:0] PC,
    input wire [31:0] Instr,
    output wire MemWrite,
    output wire [31:0] ALUResult, 
    output wire [31:0] WriteData,
    input wire [31:0] ReadData,
    output wire [2:0] ALUControl,
    output wire led

);

    wire ALUSrc, RegWrite, Jump, Zero;
    wire [1:0] ResultSrc, ImmSrc;
    //wire [2:0] ALUControl;
    wire PCSrc;

    controller c(
        Instr[6:0], 
        Instr[14:12], 
        Instr[30], 
        Zero, 
        ResultSrc, 
        MemWrite, 
        PCSrc, 
        ALUSrc, 
        RegWrite, 
        Jump, 
        ImmSrc, 
        ALUControl
    );

    datapath dp(
        clk, 
        reset_n, 
        ResultSrc, 
        PCSrc, 
        ALUSrc, 
        RegWrite, 
        ImmSrc, 
        ALUControl, 
        Zero, 
        PC, 
        Instr, 
        ALUResult, 
        WriteData,
        ReadData
    );

    //
    // DEBUG: blink a LED
    //

    reg led_reg;
    assign led = led_reg;

    always @(posedge clk)
    begin
        led_reg = ~led_reg;
    end

endmodule