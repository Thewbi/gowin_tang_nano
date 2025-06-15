module controller(

    // input
    input wire [6:0] op,
    input wire [2:0] funct3,
    input wire funct7b5,
    input wire Zero,

    // output
    output wire [1:0] ResultSrc,
    output wire MemWrite,
    output wire PCSrc, 
    output wire ALUSrc,
    output wire RegWrite, 
    output wire Jump,
    output wire [1:0] ImmSrc,
    output wire [2:0] ALUControl

);

    wire [1:0] ALUOp;
    wire Branch;

    maindec md(
        // input
        op, 
        ResultSrc, 
        MemWrite, 
        Branch, 
        ALUSrc, 
        RegWrite, 
        Jump, 
        ImmSrc,
        // output
        ALUOp
    );

    aludec ad(
        // input
        op[5], 
        funct3, 
        funct7b5, 
        ALUOp, 
        // output
        ALUControl
    );

    assign PCSrc = Branch & Zero | Jump;

endmodule