import sys
from enum import Enum

class MOVOp(Enum):
    MOVRR = 0b000
    MOVRM = 0b001
    MOVMR = 0b010
    MOVMM = 0b011
    MOVIR = 0b100

class ALUOp(Enum):
    ADD = 0b000
    SUB = 0b001
    AND = 0b010
    OR  = 0b011
    NOT = 0b100
    XOR = 0b101

class CMPOp(Enum):
    CMP = 0b000

class JMPOp(Enum):
    JMP  = 0b000
    JZ   = 0b001
    JNZ  = 0b010
    JL   = 0b011
    JLE  = 0b100
    JG   = 0b101
    JGE  = 0b110
    HALT = 0b111

class IMode(Enum):
    MOV  = 0b00
    ALU  = 0b01
    CMP  = 0b10
    JUMP = 0b11

IMOD_DICT = {
    IMode.MOV: MOVOp,
    IMode.ALU: ALUOp,
    IMode.CMP: CMPOp,
    IMode.JUMP: JMPOp
}

OPCODE_DICT = {
    op.name.lower(): (mode.value << 6) | (op.value << 3) | 0b000
    for [mode, enum_class] in IMOD_DICT.items()
    for op in enum_class
}

REG_COUNT = 8

REG_DICT = {
    **{f"r{i}": i for i in range(REG_COUNT)},
    "rr": REG_COUNT, # result register
}

def verify_line(parts: list[str]) -> bool:
    if parts[0] not in OPCODE_DICT:
        print(f"err, unknown opcode: {parts[0]}")
        return False
    
    # check if operand_a is a register
    if parts[0] in ['movrr', 'movrm']:
        if parts[1] not in REG_DICT:
            print(f"err, unknown register: {parts[1]}")
            return False
    
    # check if operand_b is a register
    if parts[0] in ['movmr', 'movmr', 'movir']:
        if parts[2] not in REG_DICT:
            print(f"err, unknown register: {parts[2]}")
            return False
    return True

if len(sys.argv) < 3:
    print("Usage: py assembler.py <src_file> <output_file>")
    sys.exit(1)

src_file, output_file = sys.argv[1:3]

output_data = []

with open(src_file, "r") as f:
    lines = f.readlines()

    for line in lines:
        # remove the comment
        semicolon_pos = line.find(';')
        line = line[:semicolon_pos].strip()

        # verify the correctness of the line
        parts = line.split()
        if len(parts) == 0:
            continue
        elif len(parts) > 4:
            print("err, len(parts)>4")
            exit(1)
            continue

        if not verify_line(parts):
            exit(1)
            continue

        for part in parts:
            if part in REG_DICT:
                output_data.append(REG_DICT[part])
            elif part in OPCODE_DICT:
                output_data.append(OPCODE_DICT[part])
            elif part.startswith("0x"):
                output_data.append(int(part[2:], 16))
            elif part.startswith("0b"):
                output_data.append(int(part[2:], 2))
            elif part.isdigit():
                output_data.append(int(part))
            else:
                print(f"err, unknown part: {part}")
                exit(1)

        #print(parts)

with open(output_file, "w") as f:
    for data in output_data:
        f.write(f"{data:08b}\n")

print(f"[ASM] Assembly completed. Output written to {output_file}")