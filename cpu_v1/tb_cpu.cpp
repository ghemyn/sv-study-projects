#include <iostream>
#include <cassert>
#include <memory>
#include <cinttypes>
#include "Vcpu.h"
#include "verilated.h"
#include "verilated_vcd_c.h" // For waveform dumps

consteval uint64_t get_clk_period_ps(double clk_hz) {
    return static_cast<uint64_t>(10e12 / clk_hz);
}

consteval uint64_t get_max_step_count(double realtime_sec, double clk_hz) {
    return static_cast<uint64_t>(realtime_sec * clk_hz);
}

constexpr double CLK_HZ = 20.0 * 10e5; // MHz
constexpr double SIMULATION_REALTIME_SEC = 0.050; // seconds

constexpr uint64_t CLK_PERIOD_PS = get_clk_period_ps(CLK_HZ);
constexpr uint64_t MAX_STEP_COUNT = get_max_step_count(SIMULATION_REALTIME_SEC, CLK_HZ);

int main(int argc, char** argv) {
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);

    auto top = std::make_unique<Vcpu>(contextp.get());
    auto tfp = std::make_unique<VerilatedVcdC>();
    
    top->trace(tfp.get(), 99);
    tfp->open("dump.vcd");

    auto tick =[&]() {
        top->clk = 1;
        top->eval();    
        
        tfp->dump(contextp->time());
        
        contextp->timeInc(CLK_PERIOD_PS / 2);

        top->clk = 0;
        top->eval();  
        
        tfp->dump(contextp->time());
        
        contextp->timeInc(CLK_PERIOD_PS / 2);
    };

    top->clk = 0;
    top->rst_n = 0; // Assert reset
    
    // Reset synchronously
    for(uint32_t i = 0; i < 4; ++i) {
        tick();
    }
    
    top->rst_n = 1; // Deassert reset

    for(uint64_t i = 0; i < MAX_STEP_COUNT; ++i) {
        tick();
    }
    
    tfp->dump(contextp->time());

    tfp->close();
    return 0;
}