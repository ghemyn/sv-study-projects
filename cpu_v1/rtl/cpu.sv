`timescale 1ns / 1ps

`include "rom.sv"
`include "ram.sv"
`include "decoder.sv"
`include "alu.sv"

`include "defines.sv"

/// TODO: improve readability and modularity
// - currently it is a monolithic design => refactor into smaller modules
// - use interfaces
// - think about bus usage
// - use enums and structures
// - try to minimize repetition of logic and code
// - add tests and verification

module CPU(
    input logic clk,
    input logic rst_n,
    output logic [BIT_DEPTH - 1 : 0] result
);
    logic [BIT_DEPTH - 1 : 0] rom_read_addr;
    logic [3:0][BIT_DEPTH - 1 : 0] rom_read_data; // read a full 32-bit word at a time (unaligned)

    logic ram_we; // write-enable for the RAM
    logic [BIT_DEPTH - 1 : 0] ram_rw_addr;
    logic [BIT_DEPTH - 1 : 0] ram_read_data;

    instruction_t instruction;

    logic [BIT_DEPTH - 1 : 0] alu_result;
    cmp_flags_t alu_flags;
    cmp_flags_t cmp_flags_reg;

    logic [BIT_DEPTH-1 : 0] next_pc; // next value of the PC
    logic pc_we; // write-enable for the program counter
    logic [BIT_DEPTH - 1 : 0] bus_wr_val;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val1;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val2;

    // regs[0:REG_COUNT-2] are general purpose registers
    // regs[REG_COUNT-2] is the program counter
    // regs[REG_COUNT-1] is the stack pointer
    logic [BIT_DEPTH - 1 : 0] regs [REG_COUNT-1 : 0];

    localparam int REG_IDX_WIDTH = $clog2(REG_COUNT);

    CPU_ROM #(
        .SIZE(ROM_SIZE),
        .FIRMWARE_FILE("code/bubble_sort.bin")
    ) rom ( .addr(rom_read_addr), .rval(rom_read_data) );

    CPU_RAM #(
        .SIZE(RAM_SIZE)
    ) ram( .clk(clk), .rst_n(rst_n), .we(ram_we), .addr(ram_rw_addr), .wval(bus_wr_val), .rval(ram_read_data) );

    DECODER decoder( 
        .rst_n(rst_n),
        .clk(clk),
        .in(rom_read_data), 

        .instruction(instruction)
    );
    
    CPU_ALU alu ( 
        .a(bus_rd_val1), .b(bus_rd_val2), 
        .op(instruction.opcode.alu_op), 
        .result(alu_result), .flags(alu_flags) 
    );

    // Determining read source
    always_comb begin
        case (instruction.mode)
            CPU_MOV_MODE: begin
                case (mov_op_t'(instruction.opcode))
                    CPU_MOVRR: begin
                        bus_rd_val1 = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]]; // write the value of operand_a to the destination register
                    end
                    CPU_MOVRM: begin
                        bus_rd_val1 = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]];
                    end
                    CPU_MOVMR: begin
                        bus_rd_val1 = ram_read_data;
                    end
                    CPU_MOVIR: begin
                        bus_rd_val1 = instruction.operand_a; // immediate value is in operand_a
                    end
                    CPU_PUSH: begin
                        bus_rd_val1 = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]]; // value to push is in operand_a
                    end
                    CPU_POP: begin
                        bus_rd_val1 = ram_read_data; // value to pop is read from RAM
                    end
                    CPU_PUSHINC: begin
                        bus_rd_val1 = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]]; // value to push is in operand_a
                        // bus_rd_val2 = operand_b by default
                    end
                    default: begin
                        // synthesis translate_off
                        $error("Unknown MOV opcode: %b at PC: %h", instruction.opcode, rom_read_addr);
                        // synthesis translate_on
                        bus_rd_val1 = {BIT_DEPTH{1'b1}}; // invalid
                    end
                endcase

                bus_rd_val2 = instruction.operand_b; // used only for PUSHINC, otherwise ignored
            end
            CPU_ALU_MODE: begin
                bus_rd_val1 = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]];
                bus_rd_val2 = regs[instruction.operand_b[REG_IDX_WIDTH-1:0]];
            end 
            CPU_JMP_MODE: begin
                bus_rd_val1 = instruction.operand_a; // jmp to the address in operand_a
                bus_rd_val2 = 0; // unused
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b at PC: %h", instruction.mode, rom_read_addr);
                // synthesis translate_on
                bus_rd_val1 = 0;
                bus_rd_val2 = 0;
            end
        endcase
    end

    // Determining write source
    always_comb begin
        case (instruction.mode)
            CPU_MOV_MODE: begin
                if (mov_op_t'(instruction.opcode) == CPU_PUSHINC) begin
                    bus_wr_val = bus_rd_val1 + bus_rd_val2; // for PUSHINC, add the increment value
                end else begin
                    bus_wr_val = bus_rd_val1;
                end
            end
            CPU_ALU_MODE: bus_wr_val = alu_result;
            CPU_JMP_MODE: bus_wr_val = bus_rd_val1;
            default:  bus_wr_val = {BIT_DEPTH{1'b1}}; // invalid
        endcase
    end

    // Conditional PC write enable logic
    always_comb begin
        case (instruction.mode)
            CPU_MOV_MODE: pc_we = (instruction.operand_c == REG_COUNT-2) ? 1'b1 : 1'b0; // ovewrite PC only if the destination register is the PC
            CPU_ALU_MODE: pc_we = (instruction.operand_c == REG_COUNT-2) ? 1'b1 : 1'b0; // ovewrite PC only if the destination register is the PC
            CPU_JMP_MODE: begin
                case (jmp_op_t'(instruction.opcode))
                    CPU_JMP: pc_we = 1'b1; // always jump
                    CPU_JE: pc_we = cmp_flags_reg.eq;
                    CPU_JNE: pc_we = ~cmp_flags_reg.eq;
                    CPU_JL: pc_we = cmp_flags_reg.sl;
                    CPU_JLE: pc_we = cmp_flags_reg.sl | cmp_flags_reg.eq;
                    CPU_JG: pc_we = cmp_flags_reg.sg;
                    CPU_JGE: pc_we = cmp_flags_reg.sg | cmp_flags_reg.eq;
                    CPU_HALT: pc_we = 1'b0; // HALT increments PC by 0 - therefore halting the CPU
                    CPU_JUL: pc_we = cmp_flags_reg.ul;
                    CPU_JULE: pc_we = cmp_flags_reg.ul | cmp_flags_reg.eq;
                    CPU_JUG: pc_we = cmp_flags_reg.ug;
                    CPU_JUGE: pc_we = cmp_flags_reg.ug | cmp_flags_reg.eq;
                    default: begin
                        // synthesis translate_off
                        $error("Unknown JUMP opcode: %b at PC: %h", instruction.opcode, rom_read_addr);
                        // synthesis translate_on
                        pc_we = 1'b0; // unknown instruction mode, do not overwrite PC
                    end
                endcase
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b at PC: %h", instruction.mode, rom_read_addr);
                // synthesis translate_on
                pc_we = 1'b0; // unknown instruction mode, do not overwrite PC
            end
        endcase
    end

    // Ram write enable and address logic
    always_comb begin
        case (instruction.mode)
            CPU_MOV_MODE: begin
                case (mov_op_t'(instruction.opcode))
                    CPU_MOVRR: ram_rw_addr = 0; // not used
                    CPU_MOVRM: ram_rw_addr = regs[instruction.operand_c[REG_IDX_WIDTH-1:0]]; // write to RAM at address in [operand_c]
                    CPU_MOVMR: ram_rw_addr = regs[instruction.operand_a[REG_IDX_WIDTH-1:0]]; // read from RAM at address in [operand_a]
                    CPU_MOVIR: ram_rw_addr = 0; // not used
                    CPU_PUSH:  ram_rw_addr = regs[REG_COUNT-1]; // write to stack
                    CPU_POP:   ram_rw_addr = regs[REG_COUNT-1] + 1; // read from stack at (reg+1 -- previous value)
                    CPU_PUSHINC:  ram_rw_addr = regs[REG_COUNT-1]; // write to stack
                    default: begin
                        // synthesis translate_off
                        $error("Unknown MOV opcode: %b at PC: %d", instruction.opcode, rom_read_addr);
                        // synthesis translate_on
                        ram_rw_addr = 0; // default address to avoid latches
                    end
                endcase

                // write to RAM only for MOVRM, PUSH, and PUSHINC
                ram_we = (mov_op_t'(instruction.opcode) == CPU_MOVRM ||
                          mov_op_t'(instruction.opcode) == CPU_PUSH ||
                          mov_op_t'(instruction.opcode) == CPU_PUSHINC); 
            end
            CPU_ALU_MODE: begin
                ram_we = 1'b0; // ALU instructions do not write to RAM
                ram_rw_addr = 0; // default address to avoid latches
            end
            CPU_JMP_MODE: begin
                ram_we = 1'b0; // JMP instructions do not write to RAM
                ram_rw_addr = 0; // default address to avoid latches
            end
            default: begin
                ram_we = 1'b0; // unknown instruction mode, do not write to RAM
                ram_rw_addr = 0; // default address to avoid latches
            end
        endcase
    end
    
    assign rom_read_addr = regs[REG_COUNT-2]; // always read ROM at the current PC value
    
    // Register and result update logic
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            for (int i = 0; i < REG_COUNT-1; i++) begin
                regs[i] <= '0;
            end

            regs[REG_COUNT-1] <= STACK_BYTES - 1; // initialize stack pointer to the top of the STACK
            cmp_flags_reg <= '0;
            result <= '0;
        end else begin
            if (!pc_we) begin
                regs[REG_COUNT-2] <= regs[REG_COUNT-2] + { {(BIT_DEPTH - 3){1'b0}}, instruction.size };
            end

            case (instruction.mode)
                CPU_MOV_MODE: begin
                    case (mov_op_t'(instruction.opcode))
                        CPU_MOVRR: begin
                            if (instruction.operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[instruction.operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
                        end
                        CPU_MOVRM: begin
                            // MOVRM does not write to any register 
                            // data moves internally in the RAM module on clk posedge
                        end
                        CPU_MOVMR: begin
                            if (instruction.operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[instruction.operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
                        end
                        CPU_MOVIR: begin
                            if (instruction.operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the immediate value (operand_b) to the result output
                            end else begin
                                regs[instruction.operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the immediate value (operand_b) to the destination register (operand_c)
                            end
                        end
                        CPU_PUSH: begin
                            // PUSH does not write to any register 
                            // data moves internally in the RAM module on clk posedge
                            regs[REG_COUNT-1] <= regs[REG_COUNT-1] - 1; // decrement stack pointer
                        end
                        CPU_POP: begin
                            if (instruction.operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[instruction.operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
        
                            if (instruction.operand_c != REG_COUNT-1) begin 
                                regs[REG_COUNT-1] <= regs[REG_COUNT-1] + 1; // increment stack pointer
                            end
                        end
                        CPU_PUSHINC: begin
                            // same as CPU_PUSH
                            regs[REG_COUNT-1] <= regs[REG_COUNT-1] - 1;
                        end
                        default: begin
                            // synthesis translate_off
                            $error("Unknown MOV opcode: %b at PC: %h", instruction.opcode, rom_read_addr);
                            // synthesis translate_on
                        end
                    endcase
                end
                CPU_ALU_MODE: begin
                    // Do not write when the ALU instruction is CMP
                    if (alu_op_t'(instruction.opcode) != CPU_CMP) begin
                        if (instruction.operand_c == REG_COUNT) begin // virtual result register is a special case
                            result <= bus_wr_val; // write the result of the ALU operation to the result output
                        end else begin
                            regs[instruction.operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the result of the ALU operation to the destination register
                        end 
                    end 

                    cmp_flags_reg <= alu_flags; // store the comparison result in the cmp_flags_reg
                end
                CPU_JMP_MODE: begin
                    if (pc_we) begin
                        // if the jump is taken, we can update the PC register with the jump address
                        regs[REG_COUNT-2] <= bus_wr_val; 
                    end
                end
                default: begin
                    // synthesis translate_off
                    $error("Unknown instruction mode: %b at PC: %h", instruction.mode, rom_read_addr);
                    // synthesis translate_on
                end 
            endcase
        end
    end

endmodule
