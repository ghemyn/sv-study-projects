#include <iostream>
#include <cassert>
#include <memory>
#include <cinttypes>
#include "Vcpu.h"
#include "verilated.h"
#include "verilated_vcd_c.h" // For waveform dumps

constexpr uint32_t STEP_COUNT = 100;

void init_rom(const std::unique_ptr<Vcpu>& top) {
    //std::cout << top->rom.mem.size() << std::endl;
    // top->rom.mem[0] = 0x00000000; // NOP
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    auto top = std::make_unique<Vcpu>();
    auto tfp = std::make_unique<VerilatedVcdC>();

    top->trace(tfp.get(), 99);
    tfp->open("dump.vcd");

    uint64_t sim_time = 0;

    auto tick =[&]() {
        top->clk = 1;
        top->eval();    
        
        tfp->dump(sim_time);
        
        sim_time += 5;
        
        top->clk = 0;
        top->eval();  
        
        tfp->dump(sim_time);
        
        sim_time += 5;
    };

    top->clk = 0;
    top->rst_n = 0; // Assert reset
    
    // Reset synchronously
    for(uint32_t i = 0; i < 4; ++i) {
        tick();
    }
    
    top->rst_n = 1; // Deassert reset

    for(uint32_t i = 0; i < STEP_COUNT; ++i) {
        tick();
    }
    
    tfp->dump(sim_time);

    tfp->close();
    return 0;
}