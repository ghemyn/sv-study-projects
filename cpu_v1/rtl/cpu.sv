`include "pc.sv"
`include "rom.sv"
`include "decoder.sv"
`include "alu.sv"
`include "comparator.sv"

`include "defines.sv"

module CPU(
    input logic clk,
    input logic rst_n,
    output logic [BIT_DEPTH - 1 : 0] result
);
    logic [BIT_DEPTH - 1 : 0] rom_read_addr;
    logic [BIT_DEPTH - 1 : 0] rom_read_data [3:0]; // read a full 32-bit word at a time (unaligned)

    instruction_mode_t instruction_mode;
    logic [CPU_OP_WIDTH-1:0] opcode;
    logic [2:0] instruction_size;
    logic [BIT_DEPTH - 1 : 0] operand_a;
    logic [BIT_DEPTH - 1 : 0] operand_b;
    logic [BIT_DEPTH - 1 : 0] operand_c;

    logic [BIT_DEPTH - 1 : 0] alu_result;
    logic [BIT_DEPTH - 1 : 0] comp_result;

    logic pc_we; // write-enable for the program counter
    logic cmp_zero;
    logic cmp_equal;
    logic cmp_less;
    logic cmp_greater;
    logic [BIT_DEPTH - 1 : 0] cmp_flags_reg; // register to hold comparison result
    logic [BIT_DEPTH - 1 : 0] regs [REG_COUNT-1 : 0];
    logic [BIT_DEPTH - 1 : 0] bus_wr_val;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val1;
    logic [BIT_DEPTH - 1 : 0] bus_rd_val2;

    localparam int REG_IDX_WIDTH = $clog2(REG_COUNT);

    PC pc( .clk(clk), .rst_n(rst_n), .we(pc_we), .in(bus_wr_val), .inc_by(instruction_size), .out(rom_read_addr) );
    
    ROM rom( .addr(rom_read_addr), .rval(rom_read_data) );

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
    
    // RAM ram( .addr(rom_read_addr), .rval() );

    ALU alu ( .a(bus_rd_val1), .b(bus_rd_val2), .op(opcode), .result(alu_result) );
    COMP comp( .a(bus_rd_val1), .b(bus_rd_val2), .op(opcode), .result(comp_result) );

    always_comb begin
        case (instruction_mode)
            MOV_MODE: begin
                case (opcode)
                    MOVRR: begin
                        bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]]; // write the value of operand_a to the destination register
                    end
                    MOVRM: begin
                        bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]];
                    end
                    MOVMR: begin
                        $warning("MOVMR is not implemented yet. Returning placeholder value.");
                        bus_rd_val1 = 8'h67; // placeholder value for memory-to-memory move
                    end
                    MOVMM: begin
                        $warning("MOVMM is not implemented yet. Returning placeholder value.");
                        bus_rd_val1 = 8'h67; // placeholder value for memory-to-memory move
                    end
                    MOVIR: begin
                        bus_rd_val1 = operand_a; // immediate value is in operand_a
                    end
                    default: begin
                        $error("Unknown MOV opcode: %b", opcode);
                        bus_rd_val1 = 8'hFF; // invalid
                    end
                endcase

                bus_rd_val2 = 0; // not used
            end
            ALU_MODE: begin
                bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]];
                bus_rd_val2 = regs[operand_b[REG_IDX_WIDTH-1:0]];
            end 
            CMP_MODE: begin 
                bus_rd_val1 = regs[operand_a[REG_IDX_WIDTH-1:0]];
                bus_rd_val2 = regs[operand_b[REG_IDX_WIDTH-1:0]];
            end
            JMP_MODE: begin
                bus_rd_val1 = operand_a; // jmp to the address in operand_a
                bus_rd_val2 = 0; // unused
            end
            default: begin
                $error("Unknown instruction mode: %b", instruction_mode);
                bus_rd_val1 = 0;
                bus_rd_val2 = 0;
            end
        endcase
    end

    // Split from the always_comb block above to avoid combinational loop issue
    // A single block cannot read and write using logic that could technically create a combinational loop
    always_comb begin
        case (instruction_mode)
            MOV_MODE: bus_wr_val = bus_rd_val1;
            ALU_MODE: bus_wr_val = alu_result;
            CMP_MODE: bus_wr_val = comp_result;
            JMP_MODE: bus_wr_val = bus_rd_val1;
            default:  bus_wr_val = 8'hFF; // invalid
        endcase
    end

    always_comb begin
        cmp_zero = (cmp_flags_reg[0]);
        cmp_equal = (cmp_flags_reg[1]);
        cmp_less = (cmp_flags_reg[2]);
        cmp_greater = (cmp_flags_reg[3]);

        case (instruction_mode)
            MOV_MODE: pc_we = 1'b0; // MOV instructions always increment PC
            ALU_MODE: pc_we = 1'b0; // ALU instructions always increment PC
            CMP_MODE: pc_we = 1'b0; // CMP instructions always increment PC
            JMP_MODE: begin
                case (opcode)
                    JMP: pc_we = 1'b1; // always jump
                    JZ: pc_we = cmp_zero;
                    JNZ: pc_we = ~cmp_zero;
                    JL: pc_we = cmp_less;
                    JLE: pc_we = cmp_less | cmp_equal;
                    JG: pc_we = cmp_greater;
                    JGE: pc_we = cmp_greater | cmp_equal;
                    HALT: pc_we = 1'b0; // HALT increments PC by 0 - therefore halting the CPU
                    default: begin
                        $error("Unknown JUMP opcode: %b", opcode);
                        pc_we = 1'b0; // unknown instruction mode, do not overwrite PC
                    end
                endcase
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
                MOV_MODE: begin
                    case (opcode)
                        MOVRR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the value of operand_a to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the value of operand_a to the destination register
                            end
                        end
                        MOVRM: begin
                            // Not implemented: would read from register and write to memory
                            $warning("MOVRM is not implemented yet. No action taken.");
                        end
                        MOVMR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= 8'h67; // write the value of operand_a to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= 8'h67; // write the value of operand_a to the destination register
                            end
                        end
                        MOVMM: begin
                            $warning("MOVMM is not implemented yet. No action taken.");
                            // Not implemented: would read from memory and write to memory
                        end
                        MOVIR: begin
                            if (operand_c == REG_COUNT) begin // virtual result register is a special case
                                result <= bus_wr_val; // write the immediate value (operand_b) to the result output
                            end else begin
                                regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the immediate value (operand_b) to the destination register (operand_c)
                            end
                        end
                        default: begin
                            $error("Unknown MOV opcode: %b", opcode);
                        end
                    endcase
                end
                ALU_MODE: begin
                    if (operand_c == REG_COUNT) begin // virtual result register is a special case
                        result <= bus_wr_val; // write the result of the ALU operation to the result output
                    end else begin
                        regs[operand_c[REG_IDX_WIDTH-1:0]] <= bus_wr_val; // write the result of the ALU operation to the destination register
                    end
                end
                CMP_MODE: begin
                    cmp_flags_reg <= bus_wr_val; // store the comparison result in the cmp_flags_reg
                end
                JMP_MODE: begin
                    // jump does not write to any register, just changes PC. 
                    // logic implemented in the PC itself
                end
                default: begin
                    $error("Unknown instruction mode: %b", instruction_mode);
                end 
            endcase
        end
    end

endmodule
