`ifndef ALU_SV
`define ALU_SV
`include "defines.sv"
`include "decoder.sv"

module CPU_ALU (
    input  logic [BIT_DEPTH-1:0] a,
    input  logic [BIT_DEPTH-1:0] b,
    input  logic [CPU_OP_WIDTH-1:0] op, // 3 bit opcode
    output logic [BIT_DEPTH-1:0] result,
    output logic [BIT_DEPTH-1:0] flags 
    // E (0), SL (signed less)(1), SG (signed greater)(2), 
    // UL (unsigned less)(3), UG (unsigned greater)(4)
);
    always_comb begin
        flags[0] = (a == b); // E
        flags[1] = ($signed(a) < $signed(b)); // SL
        flags[2] = ($signed(a) > $signed(b)); // SG
        flags[3] = (a < b); // UL
        flags[4] = (a > b); // UGs
        flags[BIT_DEPTH-1:5] = 0; // unused bits

        case (op)
            CPU_ADD: result = a + b;  // ADD
            CPU_SUB: result = a - b;  // SUB
            CPU_AND: result = a & b; // AND
            CPU_OR: result = a | b; // OR
            CPU_NOT: result = ~a; // NOT 
            CPU_XOR: result = a ^ b; // XOR
            CPU_CMP: result = flags; // CMP
            CPU_SHL: result = a << b; // SHL
            CPU_SHR: result = a >> b; // SHR
            CPU_ASHL: result = $signed(a) <<< b; // ASHL
            CPU_ASHR: result = $signed(a) >>> b; // ASHR
            default: result = 8'hFF; // default to all 1s for unknown opcodes   
        endcase
    end
endmodule

`endif
