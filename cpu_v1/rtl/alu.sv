`ifndef ALU_SV
`define ALU_SV
`include "defines.sv"
`include "decoder.sv"

typedef struct packed {
    logic eq; // equal
    logic sl; // signed less
    logic sg; // signed greater
    logic ul; // unsigned less
    logic ug; // unsigned greater
} cmp_flags_t;

module CPU_ALU (
    input  logic [BIT_DEPTH-1:0] a,
    input  logic [BIT_DEPTH-1:0] b,
    input  alu_op_t op,
    output logic [BIT_DEPTH-1:0] result,
    output cmp_flags_t flags 
);
    always_comb begin
        flags.eq = (a == b); // equal
        flags.sl = ($signed(a) < $signed(b)); // signed less
        flags.sg = ($signed(a) > $signed(b)); // signed greater
        flags.ul = (a < b); // unsigned less
        flags.ug = (a > b); // unsigned greater

        unique case (op)
            CPU_ADD: result = a + b;             
            CPU_SUB: result = a - b;             
            CPU_AND: result = a & b;             
            CPU_OR: result = a | b;              
            CPU_NOT: result = ~a;                
            CPU_XOR: result = a ^ b;             
            CPU_CMP: result = 0;                 // CMP (does not write)
            CPU_SHL: result = a << b;            
            CPU_SHR: result = a >> b;            
            CPU_ASHL: result = $signed(a) <<< b; 
            CPU_ASHR: result = $signed(a) >>> b; 
            default: begin
                // synthesis translate_off
                $error("Unknown ALU opcode: %b", op);   
                // synthesis translate_on

                result = {BIT_DEPTH{1'b1}}; // default to all 1s
            end
        endcase
    end
endmodule

`endif
