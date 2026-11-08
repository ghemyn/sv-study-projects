# ==============================================================================
# Makefile for Sipeed Tang Nano 20K (Gowin GW2AR-18C / GW2AR-LV18QN88C8/I7)
# Toolchain: oss-cad-suite (Yosys, nextpnr-gowin, apycula/gowin_pack, openFPGALoader)
# ==============================================================================

# Project configuration
PROJECT   ?= top
TOP       ?= CPU
BUILD_DIR ?= build
SRC_DIR   ?= rtl
SRCS      ?= $(wildcard $(SRC_DIR)/*.v $(SRC_DIR)/*.sv)
CST       ?= $(SRC_DIR)/tangnano20k.cst

# Verilator simulation configuration
SIM_TOP    ?= $(TOP)
SIM_SRCS   ?= $(SRC_DIR)/cpu.sv
SIM_DIR    ?= $(BUILD_DIR)/sim
SIM_PREFIX ?= cpu
SIM_BINARY ?= sim_cpu
PROGRAM    ?=
PYTHON     ?= python

# FPGA Device Specifications for Tang Nano 20K
FAMILY    ?= GW2A-18C
DEVICE    ?= GW2AR-LV18QN88C8/I7
BOARD     ?= tangnano20k

# Tools (Ensure oss-cad-suite environment is sourced or tools are in PATH)
YOSYS          ?= yosys
NEXTPNR_GOWIN  ?= nextpnr-himbaechel
GOWIN_PACK     ?= gowin_pack
OPENFPGALOADER ?= openFPGALoader

# Intermediate and output files
SYNTH_JSON     := $(BUILD_DIR)/$(PROJECT)_synth.json
PNR_JSON       := $(BUILD_DIR)/$(PROJECT)_pnr.json
BITSTREAM      := $(BUILD_DIR)/$(PROJECT).fs

.PHONY: all synth pnr bitstream prog sram flash clean compile simulate help

# Default target
all: bitstream

# Step 1: Synthesis
synth: $(SYNTH_JSON)

$(SYNTH_JSON): $(SRCS) | $(BUILD_DIR)
	@echo "==> [1/3] Synthesizing with Yosys..."
	$(YOSYS) -p \
		"read_verilog -sv $(SRCS); \
		synth_gowin -top $(TOP); \
		stat -top $(TOP); \
		write_json $@"

# Step 2: Place and Route
pnr: $(PNR_JSON)

$(PNR_JSON): $(SYNTH_JSON) $(CST)
	@echo "==> [2/3] Running Place & Route with nextpnr-himbaechel..."
	$(NEXTPNR_GOWIN) \
		--json $(SYNTH_JSON) \
		--write $@ \
		--device $(DEVICE) \
		--vopt family=$(FAMILY) \
		--vopt cst=$(CST)

# Step 3: Bitstream Generation
bitstream: $(BITSTREAM)

$(BITSTREAM): $(PNR_JSON)
	@echo "==> [3/3] Packing bitstream with gowin_pack..."
	$(GOWIN_PACK) -d $(FAMILY) -o $@ $<
	@echo "==> Bitstream created: $@"

# SRAM Programming (volatile, fast for debugging)
prog: sram
sram: $(BITSTREAM)
	@echo "==> Programming Tang Nano 20K SRAM..."
	$(OPENFPGALOADER) -b $(BOARD) $(BITSTREAM)

# Flash Programming (non-volatile, persistent after reboot)
flash: $(BITSTREAM)
	@echo "==> Flashing Tang Nano 20K onboard Flash..."
	$(OPENFPGALOADER) -b $(BOARD) -f $(BITSTREAM)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

compile: $(SIM_DIR)
	@echo "==> Compiling SystemVerilog and C++ sources for Verilator simulation..."
	verilator -Wall --cc --exe --build --timescale 1ns/1ps \
		-Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		--trace -I./$(SRC_DIR) --top-module $(SIM_TOP) --prefix V$(SIM_PREFIX) \
		$(SIM_SRCS) ./tb_cpu.cpp -Mdir $(SIM_DIR) -o $(SIM_BINARY) -DSIMULATION=1

simulate: compile
	@if [ -z "$(PROGRAM)" ]; then \
		echo "Usage: make simulate PROGRAM=<firmware_src_file>"; \
		exit 1; \
	fi
	@if [ ! -f "./code/$(PROGRAM).s" ]; then \
		echo "Error: Source file './code/$(PROGRAM).s' not found."; \
		exit 1; \
	fi
	@echo "==> Assembling ./code/$(PROGRAM).s..."
	$(PYTHON) ./code/assembler.py "./code/$(PROGRAM).s" "./code/$(PROGRAM).bin"
	@if [ ! -f "./code/$(PROGRAM).bin" ]; then \
		echo "Error: Failed to create the binary file. Please check the assembler output."; \
		exit 1; \
	fi
	@echo "==> Running simulation with Verilator..."
	./$(SIM_DIR)/$(SIM_BINARY) "+firmware=./code/$(PROGRAM).bin" && surfer dump.vcd

$(SIM_DIR):
	mkdir -p $@

help:
	@echo "Tang Nano 20K Makefile targets:"
	@echo "  make              - Build complete bitstream ($(BITSTREAM))"
	@echo "  make synth        - Run Yosys synthesis"
	@echo "  make pnr          - Run nextpnr place & route"
	@echo "  make bitstream    - Package bitstream"
	@echo "  make sram (prog)  - Download bitstream to SRAM (volatile)"
	@echo "  make flash        - Program bitstream to Flash (persistent)"
	@echo "  make clean        - Remove build directory"
	@echo "  make compile      - Compile SystemVerilog+cpp sources for Verilator simulation"
	@echo "  make simulate PROGRAM=name - Assemble and run a firmware simulation"
