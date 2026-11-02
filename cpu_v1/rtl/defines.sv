`ifndef DEFINES_SV_H
`define DEFINES_SV_H

parameter BIT_DEPTH = 8;
parameter CPU_OP_WIDTH = 4;
parameter CPU_MODE_WIDTH = 2;
// CPU_MODE_WIDTH + CPU_OP_WIDTH must be <= BIT_DEPTH
parameter REG_COUNT = 8;

parameter ROM_SIZE = 256;
parameter RAM_SIZE = 64;

`define DEFINES_SV_H
`endif
