`ifndef DEFINES_SV_H
`define DEFINES_SV_H

parameter BIT_DEPTH = 16;
parameter CPU_OP_WIDTH = 4;
parameter CPU_MODE_WIDTH = 2;
// CPU_MODE_WIDTH + CPU_OP_WIDTH must be <= BIT_DEPTH

parameter REG_COUNT = 8;
// regs[REG_COUNT-1] - stack pointer

parameter STACK_BYTES = 32;
parameter GENERAL_PURPOSE_RAM_BYTES = 128;

parameter RAM_SIZE = GENERAL_PURPOSE_RAM_BYTES + STACK_BYTES;
parameter ROM_SIZE = 256;
 
// RAM_SIZE must be <= 2^BIT_DEPTH

`define DEFINES_SV_H
`endif
