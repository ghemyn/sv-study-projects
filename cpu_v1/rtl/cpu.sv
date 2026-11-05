`include "pc.sv"
`include "rom.sv"
`include "ram.sv"
`include "decoder.sv"
`include "alu.sv"

`include "defines.sv"

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

    instruction_mode_t instruction_mode;
    logic [CPU_OP_WIDTH-1:0] opcode;
    logic [2:0] instruction_size;
    logic [BIT_DEPTH - 1 : 0] operand_a;
    logic [BIT_DEPTH - 1 : 0] operand_b;
    logic [BIT_DEPTH - 1 : 0] operand_c;

    logic [BIT_DEPTH - 1 : 0] alu_result;
    logic [BIT_DEPTH - 1 : 0] alu_flags;

    logic pc_we; // write-enable for the program counter
    logic cmp_eq, cmp_sl, cmp_sg, cmp_ul, cmp_ug;
    logic [BIT_DEPTH - 1 : 0] cmp_flags_reg; // register to hold comparison result
    logic [BIT_DEPTH - 1 : 0] regs [REG_COUNT-1 : 0];
    logic [BIT_DEPTH - 1 : 0] bus_wr_val;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val1;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val2;

    localparam int REG_IDX_WIDTH = $clog2(REG_COUNT);

    PC pc( .clk(clk), .rst_n(rst_n), .we(pc_we), .in(bus_wr_val), .inc_by(instruction_size), .out(rom_read_addr) );
    
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

        .mode(instruction_mode), 
        .opcode(opcode), 
        .instruction_size(instruction_size),
        .operand_a(operand_a), 
        .operand_b(operand_b), 
        .operand_c(operand_c) 
    );
    
    CPU_ALU alu ( .a(bus_rd_val1), .b(bus_rd_val2), .op(opcode), .result(alu_result), .flags(alu_flags) );

    always_comb begin
        case (instruction_mode)
            CPU_MOV_MODE: begin
                case (opcode)
                    CPU_MOVRR: begin
                        bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]]; // write the value of operand_a to the destination register
                    end
                    CPU_MOVRM: begin
                        bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]];
                    end
                    CPU_MOVMR: begin
                        bus_rd_val1 = ram_read_data;
                    end
                    CPU_MOVIR: begin
                        bus_rd_val1 = operand_a; // immediate value is in operand_a
                    end
                    default: begin
                        // synthesis translate_off
                        $error("Unknown MOV opcode: %b at PC: %h", opcode, rom_read_addr);
                        // synthesis translate_on
                        bus_rd_val1 = {BIT_DEPTH{1'b1}}; // invalid
                    end
                endcase

                bus_rd_val2 = 0; // not used
            end
            CPU_ALU_MODE: begin
                bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]];
                bus_rd_val2 = regs[operand_b[REG_IDX_WIDTH-1:0]];
            end 
            CPU_JMP_MODE: begin
                bus_rd_val1 = operand_a; // jmp to the address in operand_a
                bus_rd_val2 = 0; // unused
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b at PC: %h", instruction_mode, rom_read_addr);
                // synthesis translate_on
                bus_rd_val1 = 0;
                bus_rd_val2 = 0;
            end
        endcase
    end

    // Split from the always_comb block above to avoid combinational loop issue
    // A single block cannot read and write using logic that could technically create a combinational loop
    always_comb begin
        case (instruction_mode)
            CPU_MOV_MODE: bus_wr_val = bus_rd_val1;
            CPU_ALU_MODE: bus_wr_val = alu_result;
            CPU_JMP_MODE: bus_wr_val = bus_rd_val1;
            default:  bus_wr_val = {BIT_DEPTH{1'b1}}; // invalid
        endcase
    end

    always_comb begin
        cmp_eq = (cmp_flags_reg[0]);
        cmp_sl = (cmp_flags_reg[1]);
        cmp_sg = (cmp_flags_reg[2]);
        cmp_ul = (cmp_flags_reg[3]);
        cmp_ug = (cmp_flags_reg[4]);

        // cmp flags are set by the ALU at all times
        // E (0), SL (signed less)(1), SG (signed greater)(2), 
        // UL (unsigned less)(3), UG (unsigned greater)(4)

        case (instruction_mode)
            CPU_MOV_MODE: pc_we = 1'b0; // MOV instructions always increment PC
            CPU_ALU_MODE: pc_we = 1'b0; // ALU instructions always increment PC
            CPU_JMP_MODE: begin
                case (opcode)
                    CPU_JMP: pc_we = 1'b1; // always jump
                    CPU_JE: pc_we = cmp_eq;
                    CPU_JNE: pc_we = ~cmp_eq;
                    CPU_JL: pc_we = cmp_sl;
                    CPU_JLE: pc_we = cmp_sl | cmp_eq;
                    CPU_JG: pc_we = cmp_sg;
                    CPU_JGE: pc_we = cmp_sg | cmp_eq;
                    CPU_HALT: pc_we = 1'b0; // HALT increments PC by 0 - therefore halting the CPU
                    CPU_JUL: pc_we = cmp_ul;
                    CPU_JULE: pc_we = cmp_ul | cmp_eq;
                    CPU_JUG: pc_we = cmp_ug;
                    CPU_JUGE: pc_we = cmp_ug | cmp_eq;
                    default: begin
                        // synthesis translate_off
                        $error("Unknown JUMP opcode: %b at PC: %h", opcode, rom_read_addr);
                        // synthesis translate_on
                        pc_we = 1'b0; // unknown instruction mode, do not overwrite PC
                    end
                endcase
            end
            default: begin
                // synthesis translate_off
                $error("Unknown instruction mode: %b at PC: %h", instruction_mode, rom_read_addr);
                // synthesis translate_on
                pc_we = 1'b0; // unknown instruction mode, do not overwrite PC
            end
        endcase
    end

    always_comb begin
        case (instruction_mode)
            CPU_MOV_MODE: begin
                case (opcode)
                    CPU_MOVRR: ram_rw_addr = 0; // not used
                    CPU_MOVRM: ram_rw_addr = regs[operand_c[REG_IDX_WIDTH-1:0]]; // write to RAM at address in [operand_c]
                    CPU_MOVMR: ram_rw_addr = regs[operand_a[REG_IDX_WIDTH-1:0]]; // read from RAM at address in [operand_a]
                    CPU_MOVIR: ram_rw_addr = 0; // not used
                    default: begin
                        // synthesis translate_off
                        $error("Unknown MOV opcode: %b at PC: %d", opcode, rom_read_addr);
                        // synthesis translate_on
                        ram_rw_addr = 0; // default address to avoid latches
                    end
                endcase

                ram_we = (opcode == CPU_MOVRM); // write to RAM only for MOVRM
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
    
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            for (int i = 0; i < REG_COUNT; i++) begin
                regs[i] <= '0;
            end
            cmp_flags_reg <= '0;
            result <= '0;
        end else begin
            case (instruction_mode)
                CPU_MOV_MODE: begin
                    case (opcode)
                        CPU_MOVRR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
                        end
                        CPU_MOVRM: begin
                            // MOVRM does not write to any register 
                            // data moves internally in the RAM module on clk posedge
                        end
                        CPU_MOVMR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
                        end
                        CPU_MOVIR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the immediate value (operand_b) to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the immediate value (operand_b) to the destination register (operand_c)
                            end
                        end
                        default: begin
                            // synthesis translate_off
                            $error("Unknown MOV opcode: %b at PC: %h", opcode, rom_read_addr);
                            // synthesis translate_on
                        end
                    endcase
                end
                CPU_ALU_MODE: begin
                    if (opcode != CPU_CMP) begin
                        if (operand_c == REG_COUNT) begin // virtual result register is a special case
                            result <= bus_wr_val; // write the result of the ALU operation to the result output
                        end else begin
                            regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the result of the ALU operation to the destination register
                        end 
                    end 

                    cmp_flags_reg <= alu_flags; // store the comparison result in the cmp_flags_reg
                end
                CPU_JMP_MODE: begin
                    // jump does not write to any register, just changes PC. 
                    // logic implemented in the PC itself
                end
                default: begin
                    // synthesis translate_off
                    $error("Unknown instruction mode: %b at PC: %h", instruction_mode, rom_read_addr);
                    // synthesis translate_on
                end 
            endcase
        end
    end

endmodule
