module datapath(
    input wire clk, 
    input wire reset_n,
    input wire [1:0] ResultSrc,
    input wire PCSrc, ALUSrc,
    input wire RegWrite,
    input wire [1:0] ImmSrc,
    input wire [2:0] ALUControl,
    output wire Zero,
    output wire [31:0] PC,
    input wire [31:0] Instr,
    output wire [31:0] ALUResult, WriteData,
    input wire [31:0] ReadData
);

    wire [31:0] PCNext;
    wire [31:0] PCPlus4; 
    //reg [31:0] PCPlus4;
    wire [31:0] PCTarget;
    wire [31:0] ImmExt;
    wire [31:0] SrcA, SrcB;
    wire [31:0] Result;

    // next PC logic (clk, reset, input, output)
    flopr #(32) pcreg(clk, reset_n, PCNext, PC);

    adder pcadd4(PC, 32'd4, PCPlus4);
    //always @(posedge clk)
    //begin
    //    PCPlus4 <= PC + 32'd4;
    //end
    adder pcaddbranch(PC, ImmExt, PCTarget);
    mux2 #(32) pcmux(PCPlus4, PCTarget, PCSrc, PCNext);

    // register file logic
    regfile rf(clk, RegWrite, Instr[19:15], Instr[24:20], Instr[11:7], Result, SrcA, WriteData);
    extend ext(Instr[31:7], ImmSrc, ImmExt);

    // ALU logic
    mux2 #(32) srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
    alu alu(SrcA, SrcB, ALUControl, ALUResult, Zero);
    mux3 #(32) resultmux(ALUResult, ReadData, PCPlus4, ResultSrc, Result);

endmodule