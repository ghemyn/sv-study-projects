`include "defines.sv"

// Result format:
// bit 0 - Z
// bit 1 - E
// bit 2 - L
// bit 3 - G

module COMP (
    input  logic [BIT_DEPTH-1:0] a,
    input  logic [BIT_DEPTH-1:0] b,
    input  logic [CPU_OP_WIDTH-1:0] op, // 3 bit opcode
    output logic [BIT_DEPTH-1:0] result
);
    logic zero, equal, less, greater;

    always_comb begin
        zero = (a == b);
        equal = (a == b);
        less = (a < b);
        greater = (a > b);

        result = { {BIT_DEPTH-4{1'b0}},greater, less, equal, zero};
    end
endmodule
