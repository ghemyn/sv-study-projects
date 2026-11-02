`ifndef ALU_SV
`define ALU_SV
`include "defines.sv"
`include "decoder.sv"

module CPU_ALU (
    input  logic [BIT_DEPTH-1:0] a,
    input  logic [BIT_DEPTH-1:0] b,
    input  logic [CPU_OP_WIDTH-1:0] op, // 3 bit opcode
    output logic [BIT_DEPTH-1:0] result
);
    always_comb begin
        case (op)
            CPU_ADD: result = a + b;  // ADD
            CPU_SUB: result = a - b;  // SUB
            CPU_AND: result = a & b; // AND
            CPU_OR: result = a | b; // OR
            CPU_NOT: result = ~a; // NOT 
            CPU_XOR: result = a ^ b; // XOR
            default: result = 8'hFF; // default to all 1s for unknown opcodes   
        endcase
    end
endmodule

`endif
