`ifndef RAM_SV
`define RAM_SV

`include "defines.sv"

module CPU_RAM #(
    parameter SIZE = 64
) (
    input logic clk, 
    input logic rst_n,
    input logic we, // write-enable, 0 = read, 1 = write
    input logic [BIT_DEPTH-1 : 0] addr,
    input logic [BIT_DEPTH-1 : 0] wval,
    output logic [BIT_DEPTH-1 : 0] rval
);
    localparam int ADDR_WIDTH = $clog2(SIZE);

    logic [BIT_DEPTH-1 : 0] mem [SIZE - 1 : 0]; // SIZE bytes

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // synthesis translate_off
            mem <= '{default: 0}; // not a good practice for production, but for simulation it's fine
            // synthesis translate_on
        end else begin
            if (we) begin
                mem[addr[ADDR_WIDTH-1:0]] <= wval;
            end
        end
    end

    assign rval = mem[addr[ADDR_WIDTH-1:0]];
endmodule

`endif
