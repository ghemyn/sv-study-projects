`include "defines.sv"

module RAM #(
    parameter SIZE = 128
) (
    input logic [BIT_DEPTH-1 : 0] addr,
    output logic [BIT_DEPTH-1 : 0] rval
);
    logic [BIT_DEPTH-1 : 0] mem [SIZE - 1 : 0]; // SIZE bytes

    assign rval = mem[addr];
endmodule
