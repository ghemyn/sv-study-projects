`ifndef PC_SV
`define PC_SV

`include "defines.sv"

module PC(
    input logic clk,
    input logic rst_n,
    input logic we, // write-enable, 0 = hold, 1 = write (override)
    input logic [BIT_DEPTH - 1 : 0] in,
    input logic [2 : 0] inc_by,
    output logic [BIT_DEPTH - 1 : 0] out
);
    logic [BIT_DEPTH - 1 : 0] pc_reg; // register value
    logic [BIT_DEPTH-1 : 0] next_pc; // next value of the PC
    
    always_comb begin
        if (we) begin
            next_pc = in;
        end else begin
            next_pc = pc_reg + { {(BIT_DEPTH - 3){1'b0}}, inc_by };
        end
        
        out = pc_reg; 
    end

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            pc_reg <= '0;
        end else begin
            pc_reg <= next_pc;
        end
    end

endmodule

`endif
