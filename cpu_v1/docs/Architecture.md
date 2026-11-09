*Not final ...*

# Module Hierarchy

```
CPU
├── ROM
├── Decoder
├── Control unit
├── Register file
├── ALU
└── RAM
```

# Control flow

1. Read the instruction
2. Control unit decides about:
    - what needs to be done
    - what will be the data source 
    - what will be the data destination
    - how to tweak cache/pc regs 
    - which control flags/signals to set
3. Sequentially execute the instruction keeping the control flags/signals in mind:
    - read the needed data from detemined sources
    - output the results to the desired destination (reg / ram / flag_reg) 

```
instruction
    |
    v
control unit ───────> control signals
    |                         |
    v                         v
register file ───> datapath/execute ───> RAM
    ^                         |
    └──── sequential commit ──┘

```