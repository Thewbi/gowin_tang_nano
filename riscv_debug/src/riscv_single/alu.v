module alu #(
    parameter WIDTH = 32
) 
(
    // input
    input wire [WIDTH-1:0] a_in,
    input wire [WIDTH-1:0] b_in,
    input wire [2:0] ALUControl,

    // output
    output reg [WIDTH-1:0] 	ALUResult,
    output reg Z // zero

);

    // compute the result
    always @(*)
    begin
        ALUResult = 1'b0;
        case (ALUControl)

            // add (see alu_decoder.sv)
            3'b000: 
                ALUResult = a_in + b_in;

            // sub
            3'b001: 
                ALUResult = a_in + (~b_in + 1'b1);

            // and, andi
            3'b010: 
                ALUResult = a_in & b_in;

            // or, ori
            3'b011: 
                ALUResult = a_in | b_in;

            // slt, slti
            // SLTI (set less than immediate) places the value 1 in register rd if
            // register rs1 is less than the signextended immediate when both are treated
            // as signed numbers, else 0 is written to rd.
            3'b101: 
                ALUResult = a_in < b_in ? 1 : 0;

            default: 
                ALUResult = 1'b0;

        endcase

        Z = ALUResult == 0;
    
    end

endmodule