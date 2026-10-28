`include "defines.sv"


module ROM #(
    parameter SIZE = 128
) (
    input logic [BIT_DEPTH-1 : 0] addr,
    output logic [BIT_DEPTH-1 : 0] rval [3 : 0] // read a full 32-bit word at a time (unaligned)
);
    localparam int ADDR_WIDTH = $clog2(SIZE);

    logic [BIT_DEPTH-1 : 0] mem [SIZE - 1 : 0]; // SIZE bytes

    initial begin
        string firmware_file;
        // Check if the user supplied the argument +firmware=path.bin
        if ($value$plusargs("firmware=%s", firmware_file)) begin
            $display("[ROM] Reading firmware file: %s", firmware_file);
            $readmemb(firmware_file, mem);
        end else begin
            $fatal(1, "[ROM] ERROR: No firmware file specified! Use +firmware=path/to/firmware.bin");
            mem = '{default: 0};
        end
    end

    always_comb begin
        logic [ADDR_WIDTH-1 : 0] addr_index;
        
        addr_index = addr[ADDR_WIDTH-1 : 0];

        rval[0] = mem[addr_index];
        rval[1] = mem[addr_index + 1];
        rval[2] = mem[addr_index + 2];
        rval[3] = mem[addr_index + 3];
    end
endmodule
