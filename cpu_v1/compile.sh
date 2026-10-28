verilator --cc --exe --build -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM --trace -I./rtl ./rtl/cpu.sv ./tb_cpu.cpp -o sim_cpu
