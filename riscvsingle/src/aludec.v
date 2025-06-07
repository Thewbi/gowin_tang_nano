// decodes ALU control signals from the instruction
module aludec(
    // input
    input   wire                opb5,
    input   wire    [2:0]       funct3,
    input   wire                funct7b5,
    input   wire    [1:0]       ALUOp,
    // output
    output  reg     [2:0]       ALUControl
);

    wire  RtypeSub;

    assign RtypeSub = funct7b5 & opb5; // TRUE for R–type subtract

    always @*
        case (ALUOp)
            2'b00: begin ALUControl = 3'b000; end // addition
            2'b01: begin ALUControl = 3'b001; end // subtraction
            default: begin
                case (funct3) // R–type or I–type ALU
                    3'b000: begin
                        if (RtypeSub)
                            ALUControl = 3'b001; // sub
                        else
                            ALUControl = 3'b000; // add, addi
                    end
                    3'b010: begin ALUControl = 3'b101; end // slt, slti
                    3'b110: begin ALUControl = 3'b011; end // or, ori
                    3'b111: begin ALUControl = 3'b010; end // and, andi
                    default: begin ALUControl = 3'bxxx; end // ???
                endcase
            end
        endcase

endmodule