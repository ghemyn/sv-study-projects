`ifndef REG_SV
`define REG_SV

`include "defines.sv"

module REG(
    input logic clk,
    input logic rst_n,
    input logic we, // write-enable, 0 = hold, 1 = write
    input logic [BIT_DEPTH-1 : 0] wval,
    output logic [BIT_DEPTH-1 : 0] rval 
);
    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            rval <= '0;
        end else begin
            if (we) begin
                rval <= wval;
            end
            //  No 'else' needed; flip-flops hold state automatically
        end
    end
endmodule

`endif
