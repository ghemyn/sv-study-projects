`include "defines.sv"

module ALU (
    input  logic [BIT_DEPTH-1:0] a,
    input  logic [BIT_DEPTH-1:0] b,
    input  logic [CPU_OP_WIDTH-1:0] op, // 3 bit opcode
    output logic [BIT_DEPTH-1:0] result
);
    always_comb begin
        case (op)
            ADD: result = a + b;  // ADD
            SUB: result = a - b;  // SUB
            AND: result = a & b; // AND
            OR: result = a | b; // OR
            NOT: result = ~a; // NOT 
            XOR: result = a ^ b; // XOR
            default: result = 8'hFF; // default to all 1s for unknown opcodes   
        endcase
    end
endmodule
