# CPU instruction set architecture

## Brief

The current implementation uses:

- 16-bit registers and ALU values (`BIT_DEPTH = 16`)
- 16 registers (`REG_COUNT = 16`)
- variable-length instructions - from 1 up to 4 bytes per instruction
- down-growing hardware stack

The assembler splits instructions into individual bytes and writes one byte per line of the `.bin` file. The ROM loads each line into one
memory entry.

## Registers

Register operands are encoded as one byte. Values `0` through `15` select the
corresponding register.

| Name | Number | Purpose |
| --- | ---: | --- |
| `r0` ... `r13` | `0` ... `13` | General-purpose registers |
| `rpc` | `14` | Program counter |
| `rsp` | `15` | Stack pointer |
| `rr` | `16` | Virtual result register; writes update the CPU `result` output |

`rr` is not a physical register and must not be used as a source register.

After reset, `rpc` is zero and `rsp` is initialized to `STACK_BYTES - 1`.

## Instruction encoding

Each instruction begins with one opcode byte:

```text
[7;6] |[5;4]| [3; 0]
+-----+-----+-------+
| MODE| --- | OPCODE|
+-----+-----+-------+
```

- `MODE[7:6]` selects the instruction mode (group) - read about modes in the **Instruction modes** section
- Bits `[5:4]` are unused
- `OPCODE[3:0]` selects the operation within the group.
- Following bytes (between 0 and 3 bytes) contain operands

The instruction pointer advances by the encoded instruction size unless the
instruction writes a new value to `rpc`. The instruction sizes include
the opcode byte, e.g. the size of `add r0 r1 r0` (opcode + 3 operands) is equal to 4

### Instruction modes

| Mode | Bits | Group |
| --- | --- | --- |
| `MOV` | `00` | Data movement and stack operations |
| `ALU` | `01` | Arithmetic, logic, comparison, and shifts |
| `JUMP` | `10` | Conditional and unconditional control flow |
| `11` | — | Invalid/reserved |

## MOV instructions

All MOV instructions use mode `0b00`.

| Opcode | Mnemonic | Size | Operands | Description |
| --- | --- | ---: | --- | --- |
| `0000` | `MOVRR src dst` | 3 | registers | Copy `src` to `dst` |
| `0001` | `MOVRM src addr` | 3 | register, register | Store register `src` to RAM at the address held in `addr` |
| `0010` | `MOVMR addr dst` | 3 | register, register | Load RAM at the address held in `addr` into `dst` |
| `0011` | `MOVIR imm dst` | 3 | immediate, register | Load `imm` into `dst` |
| `0100` | `PUSH src` | 2 | register | Store `src` at the stack and decrement `rsp` |
| `0101` | `POP dst` | 2 | register | Load the previous stack entry into `dst` and increment `rsp` |
| `0110` | `PUSHINC src inc` | 3 | register, immediate | Store `src + inc` at the stack and decrement `rsp` |

For `MOVRM`, the second operand is a register containing the RAM address. 

For
`MOVMR`, the first operand is a register containing the RAM address.

Writing to `rpc` with `MOVRR`, `MOVMR`, or `MOVIR` overwrites the Program Counter instead
of advancing to the next sequential instruction. 

Writing to `rr` updates the
top-level `result` output.

## ALU instructions

All ALU instructions use mode `0b01`. 

| Opcode | Mnemonic | Size | Operands | Result |
| --- | --- | ---: | --- | --- |
| `0000` | `ADD a b dst` | 4 | registers | `dst = a + b` |
| `0001` | `SUB a b dst` | 4 | registers | `dst = a - b` |
| `0010` | `AND a b dst` | 4 | registers | `dst = a & b` |
| `0011` | `OR a b dst` | 4 | registers | `dst = a \| b` |
| `0100` | `NOT src dst` | 3 | registers | `dst = ~src` |
| `0101` | `XOR a b dst` | 4 | registers | `dst = a ^ b` |
| `0110` | `CMP a b` | 3 | registers | Update flags; no register result is written |
| `0111` | `SHL a b dst` | 4 | registers | `dst = a << b` |
| `1000` | `SHR a b dst` | 4 | registers | `dst = a >> b` |
| `1001` | `ASHL a b dst` | 4 | registers | `dst = signed(a) <<< b` |
| `1010` | `ASHR a b dst` | 4 | registers | `dst = signed(a) >>> b` |

The ALU computes comparison flags from its
two input operands for every ALU instruction. The flags are retained for later
conditional jumps.

For all ALU operations except `CMP`, writing to `rr` updates the `result`
output.

Writing to `rpc` changes control flow - same as with the instructions from the MOV instruction mode

## Jump instructions

All jump instructions use mode `0b10`.

| Opcode | Mnemonic | Size | Condition |
| --- | --- | ---: | --- |
| `0000` | `JMP dst` | 2 | Always |
| `0001` | `JE dst` | 2 | Equal |
| `0010` | `JNE dst` | 2 | Not equal |
| `0011` | `JL dst` | 2 | Signed less |
| `0100` | `JLE dst` | 2 | Signed less or equal |
| `0101` | `JG dst` | 2 | Signed greater |
| `0110` | `JGE dst` | 2 | Signed greater or equal |
| `0111` | `HALT` | 0 | Never advances the program counter effectively halting the CPU |
| `1000` | `JUL dst` | 2 | Unsigned less |
| `1001` | `JULE dst` | 2 | Unsigned less or equal |
| `1010` | `JUG dst` | 2 | Unsigned greater |
| `1011` | `JUGE dst` | 2 | Unsigned greater or equal |

The `dst` operand is an immediate byte address. Conditional jumps use the
comparison flags saved by the most recent ALU operation.

*Note: if you want to jump to an address stored in a register, just overwrite the `rpc` register.**

## Assembler pseudo-operations


| Mnemonic | Size | Description |
| --- | ---: | --- |
| `CALL label` | 5 | Saves the next rpc value to stack and jumps to `label` |
| `RET` | 2 | Returns the control flow to the saved rpc value |

The assembler expands these into real instructions:

```text
mnemonic: CALL label
turns into: 
    PUSHINC rpc 5
    JMP label

mnemonic: RET
turns into:
    POP rpc
```

`CALL` uses an increment of `5` so that the pushed return address skips over
the expanded call sequence and its destination operand.

## Reserved encodings

- Unlisted opcodes within a valid mode are invalid.
- The decoder reports invalid instructions/modes in simulation
