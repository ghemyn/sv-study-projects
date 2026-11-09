`ifndef DECODER_SV
`define DECODER_SV
`include "defines.sv"

// @/docs/ISA.md
typedef enum logic [CPU_OP_WIDTH-1:0] {
    CPU_MOVRR   = 4'b0000,
    CPU_MOVRM   = 4'b0001,
    CPU_MOVMR   = 4'b0010,
    CPU_MOVIR   = 4'b0011,
    CPU_PUSH    = 4'b0100,
    CPU_POP     = 4'b0101,
    CPU_PUSHINC = 4'b0110
} mov_op_t;

// @/docs/ISA.md
typedef enum logic [CPU_OP_WIDTH-1:0] {
    CPU_ADD = 4'b0000,
    CPU_SUB = 4'b0001,
    CPU_AND = 4'b0010,
    CPU_OR  = 4'b0011,
    CPU_NOT = 4'b0100,
    CPU_XOR = 4'b0101,
    CPU_CMP = 4'b0110,
    CPU_SHL = 4'b0111,
    CPU_SHR = 4'b1000,
    CPU_ASHL = 4'b1001,
    CPU_ASHR = 4'b1010
} alu_op_t;

// @/docs/ISA.md
typedef enum logic [CPU_OP_WIDTH-1:0] {
    CPU_JMP  = 4'b0000,
    CPU_JE   = 4'b0001,
    CPU_JNE  = 4'b0010,
    CPU_JL   = 4'b0011,
    CPU_JLE  = 4'b0100,
    CPU_JG   = 4'b0101,
    CPU_JGE  = 4'b0110,
    CPU_HALT = 4'b0111,
    CPU_JUL  = 4'b1000, // jump if unsigned less
    CPU_JULE = 4'b1001, // jump if unsigned less or equal
    CPU_JUG  = 4'b1010, // jump if unsigned greater
    CPU_JUGE = 4'b1011  // jump if unsigned greater or equal
} jmp_op_t;

// @/docs/ISA.md
typedef enum logic [CPU_MODE_WIDTH-1:0] {
    CPU_MOV_MODE  = 2'b00,
    CPU_ALU_MODE  = 2'b01,
    CPU_JMP_MODE = 2'b10
} instruction_mode_t;

// The opcode can be read as one of the specific opcode type or as raw bits
// @/docs/ISA.md
typedef union packed {
    mov_op_t mov_op;
    alu_op_t alu_op;
    jmp_op_t jmp_op;
    logic [CPU_OP_WIDTH-1:0] bits;
} cpu_opcode_t;

// Entire instruction descriptor
// @/docs/ISA.md
typedef struct packed {
    instruction_mode_t mode; // instruction mode the opcode belongs to
    cpu_opcode_t opcode;     // opcode union (can be read as mov_op, alu_op, jmp_op, or raw bits)
    logic [2:0] size;        // number of parts in the instruction [1, 4]

    // TODO: Consider renaming the operands from a,b,c to src1,src2,dst
    logic [BIT_DEPTH - 1 : 0] operand_a;
    logic [BIT_DEPTH - 1 : 0] operand_b;
    logic [BIT_DEPTH - 1 : 0] operand_c;
} instruction_t;

// @/docs/ISA.md
module DECODER(
    input logic rst_n,
    input logic clk,
    input logic [3:0][BIT_DEPTH - 1 : 0] in, // read 3 bytes ahead for variable-length instructions
    
    output instruction_t instruction
);
    // assume we're always at the start of an instruction, so we read the first part (OP) first
    always_comb begin
        instruction = '0; // default to zero, override in the case statements
        instruction.mode = instruction_mode_t'(in[0][7:8-CPU_MODE_WIDTH]);
        instruction.opcode.bits = in[0][CPU_OP_WIDTH-1:0];

        unique case (instruction.mode)
            CPU_MOV_MODE: begin
                unique case (instruction.opcode.mov_op)
                    CPU_MOVRR,
                    CPU_MOVRM,
                    CPU_MOVMR,
                    CPU_MOVIR: begin
                        instruction.operand_a = in[1]; // src
                        instruction.operand_b = in[2]; // dst
                        instruction.operand_c = in[2]; // dst
                        instruction.size = 3;
                    end
                    CPU_PUSH: begin
                        instruction.operand_a = in[1]; // src
                        instruction.size = 2;
                    end
                    CPU_PUSHINC: begin
                        instruction.operand_a = in[1]; // src
                        instruction.operand_b = in[2]; // inc value
                        instruction.size = 3;
                    end
                    CPU_POP: begin
                        instruction.operand_c = in[1]; // dst
                        instruction.size = 2;
                    end
                    default: begin
                        // synthesis translate_off
                        $error("Unknown mov opcode: %b", instruction.opcode.mov_op);
                        // synthesis translate_on
                    end
                endcase
            end
            CPU_ALU_MODE: begin
                unique case (instruction.opcode.alu_op)
                    CPU_NOT: begin
                        instruction.operand_a = in[1]; // src
                        instruction.operand_c = in[2]; // dest
                        instruction.size = 3;
                    end
                    CPU_CMP: begin
                        instruction.operand_a = in[1]; // src1
                        instruction.operand_b = in[2]; // src2
                        instruction.size = 3;
                    end
                    CPU_ADD, CPU_SUB,
                    CPU_AND, CPU_OR, CPU_XOR, 
                    CPU_SHL, CPU_SHR, CPU_ASHL, CPU_ASHR: begin
                        instruction.operand_a = in[1]; // src1
                        instruction.operand_b = in[2]; // src2
                        instruction.operand_c = in[3]; // dest
                        instruction.size = 4;
                    end
                    default: begin
                        // synthesis translate_off
                        $error("Unknown alu opcode: %b", instruction.opcode.alu_op);
                        // synthesis translate_on
                    end
                endcase
            end
            CPU_JMP_MODE: begin
                unique case (instruction.opcode.jmp_op)
                    CPU_JMP, 
                    CPU_JE, CPU_JNE, CPU_JL, CPU_JLE, CPU_JG, CPU_JGE,
                    CPU_JUL, CPU_JULE, CPU_JUG, CPU_JUGE: begin
                        instruction.operand_a = in[1]; // dst address
                        instruction.size = 2; 
                    end
                    CPU_HALT: begin
                        instruction.size = 0; // no operands - jump indefinitely
                    end
                    default: begin
                        // synthesis translate_off
                        $error("Unknown jmp opcode: %b", instruction.opcode.jmp_op);
                        // synthesis translate_on
                    end
                endcase
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b, in: %h", instruction.mode, {in[0], in[1], in[2], in[3]});
                // synthesis translate_on
            end
        endcase
    end

endmodule

`endif
