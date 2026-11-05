`ifndef DECODER_SV
`define DECODER_SV
`include "defines.sv"

//////// ISA
//
//// COMPOSITION:
// MODE [7:6] | OPCODE [5:3] | EMPTY [2:0] + (optional) OPERAND_A [7:0] + (optional) OPERAND_B [7:0] + (optional) OPERAND_C [7:0]
//
//// SET:
/// moving: from src to dst
// MOVRR src (register) dst (register)
// MOVRM src (register) dst (memory)
// MOVMR src (memory) dst (register)
// MOVIR imm8 (immediate) dst (register)
/// math: (a, b, dest are registers)
// ADD a b dest
// SUB a b dest
// AND a b dest
// OR a b dest
// NOT a dest
// XOR a b dest
// CMP a b
/// jumping: set PC to dst (address)
// JMP dst
// JZ dst
// JNZ dst
// JL dst
// JLE dst
// JG dst
// JGE dst
// HALT

typedef enum logic [CPU_OP_WIDTH-1:0] {
    CPU_MOVRR = 4'b0000,
    CPU_MOVRM = 4'b0001,
    CPU_MOVMR = 4'b0010,
    CPU_MOVIR = 4'b0011
} mov_op_t;

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

typedef enum logic [CPU_MODE_WIDTH-1:0] {
    CPU_MOV_MODE  = 2'b00,
    CPU_ALU_MODE  = 2'b01,
    CPU_JMP_MODE = 2'b10
} instruction_mode_t;

// Biggest possible instruction consists of 4 parts: OP, A, B, C
module DECODER(
    input logic rst_n,
    input logic clk,
    input logic [3:0][BIT_DEPTH - 1 : 0] in, // read 3 bytes ahead for variable-length instructions
    output instruction_mode_t mode,
    output logic [CPU_OP_WIDTH-1:0] opcode,
    output logic [2:0] instruction_size, // number of parts in the instruction [1, 4]
    output logic [BIT_DEPTH - 1 : 0] operand_a,
    output logic [BIT_DEPTH - 1 : 0] operand_b,
    output logic [BIT_DEPTH - 1 : 0] operand_c
);

    // assume we're always at the start of an instruction, and we will read the first part (OP) first
    always_comb begin
        mode = instruction_mode_t'(in[0][7:8-CPU_MODE_WIDTH]);
        opcode = in[0][CPU_OP_WIDTH-1:0];

        case (mode)
            CPU_MOV_MODE: begin
                operand_a = in[1]; // src
                operand_b = 0;
                operand_c = in[2]; // dst
                instruction_size = 3;
            end
            CPU_ALU_MODE: begin
                case (opcode)
                    CPU_NOT: begin
                        operand_a = in[1]; // src
                        operand_b = 0; // not used
                        operand_c = in[2]; // dest
                        instruction_size = 3;
                    end
                    CPU_CMP: begin
                        operand_a = in[1]; // src1
                        operand_b = in[2]; // src2
                        operand_c = 0; // not used
                        instruction_size = 3;
                    end
                    default: begin
                        operand_a = in[1]; // src1
                        operand_b = in[2]; // src2
                        operand_c = in[3]; // dest
                        instruction_size = 4;
                    end
                endcase
            end
            CPU_JMP_MODE: begin
                operand_a = in[1]; // dst address
                operand_b = 0; // not used
                operand_c = 0; // not used

                if (opcode == CPU_HALT) begin
                    instruction_size = 0; // no operands
                end else begin
                    instruction_size = 2; // one operand (address)
                end
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b, in: %h", mode, {in[0], in[1], in[2], in[3]});
                // synthesis translate_on
                operand_a = {BIT_DEPTH{1'b1}}; // invalid
                operand_b = {BIT_DEPTH{1'b1}}; // invalid
                operand_c = {BIT_DEPTH{1'b1}}; // invalid
                instruction_size = 0; // halt
            end
        endcase
    end

endmodule

`endif
