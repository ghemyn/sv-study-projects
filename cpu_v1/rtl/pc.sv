`include "reg.sv"
`include "defines.sv"

module PC(
    input logic clk,
    input logic rst_n,
    input logic we, // write-enable, 0 = hold, 1 = write (override)
    input logic [BIT_DEPTH - 1 : 0] in,
    input logic [2 : 0] inc_by,
    output logic [BIT_DEPTH - 1 : 0] out
);
    logic [BIT_DEPTH-1 : 0] inc_in;
    logic [BIT_DEPTH-1 : 0] inc_out;
    REG ireg ( .clk(clk), .rst_n(rst_n), .we(1'b1), .wval(inc_out), .rval(inc_in) );

    always_comb begin
        if (we) begin
            inc_out = in;
        end else begin
            inc_out = inc_in + { {(BIT_DEPTH - 3){1'b0}}, inc_by };
        end
        
        out = inc_in; 
    end

endmodule
