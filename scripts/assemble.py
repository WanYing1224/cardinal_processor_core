#!/usr/bin/env python3
"""
Cardinal ISA Assembler for EE577B Phase 2
Encodes Cardinal assembly text into 32-bit hex words matching Big-Endian [0:31]
"""
import sys
import re

OPCODES = {
    "VAND":   (0x2A, 0x01), "VOR":    (0x2A, 0x02), "VXOR":   (0x2A, 0x03),
    "VNOT":   (0x2A, 0x04), "VMOV":   (0x2A, 0x05), "VADD":   (0x2A, 0x06),
    "VSUB":   (0x2A, 0x07), "VMULEU": (0x2A, 0x08), "VMULOU": (0x2A, 0x09),
    "VSLL":   (0x2A, 0x0A), "VSRL":   (0x2A, 0x0B), "VSRA":   (0x2A, 0x0C),
    "VRTTH":  (0x2A, 0x0D), "VDIV":   (0x2A, 0x0E), "VMOD":   (0x2A, 0x0F),
    "VSQEU":  (0x2A, 0x10), "VSQOU":  (0x2A, 0x11), "VSQRT":  (0x2A, 0x12),
    "VNOP":   (0x3C, 0x00), "VLD":    (0x20, None), "VSD":    (0x21, None),
    "VBEZ":   (0x22, None), "VBNEZ":  (0x23, None)
}

WW_MAP  = {"b": 0, "h": 1, "w": 2, "d": 3}
PPP_MAP = {"a": 0, "0": 1, "01": 2, "012": 3, "0123": 4}

def parse_reg(r_str):
    m = re.match(r"^[rR](\d+)$", r_str.strip())
    if not m:
        raise ValueError(f"Invalid register name: {r_str}")
    val = int(m.group(1))
    if not (0 <= val <= 31):
        raise ValueError(f"Register out of range (0-31): {r_str}")
    return val

def assemble_line(line):
    line = line.split("//")[0].split("#")[0].strip()
    if not line:
        return None

    tokens = [t.strip().rstrip(",") for t in line.replace(",", " ").split() if t.strip()]
    mnemonic = tokens[0].upper()

    if mnemonic in ("END", "HALT", "STOP"):
        return 0x00000000

    if mnemonic == "VNOP":
        return 0xF0000000

    parts = mnemonic.split(".")
    base = parts[0]
    ww  = WW_MAP.get(parts[1].lower(), 3)  if len(parts) > 1 else 3
    ppp = PPP_MAP.get(parts[2].lower(), 0) if len(parts) > 2 else 0

    if base not in OPCODES:
        raise ValueError(f"Unknown instruction: {base}")

    op, func = OPCODES[base]

    # Memory M-Type: [0:5] op, [6:10] rD, [11:15] rA (0), [16:31] imm
    if base in ("VLD", "VSD"):
        rd = parse_reg(tokens[1])
        imm_str = tokens[2]
        m = re.match(r"^(0x[0-9a-fA-F]+|\d+)(?:\([rR]0\))?$", imm_str)
        if not m:
            raise ValueError(f"Invalid memory offset syntax: {imm_str}")
        imm = int(m.group(1), 0) & 0xFFFF
        return ((op & 0x3F) << 26) | ((rd & 0x1F) << 21) | imm

    # Branch B-Type: [0:5] op, [6:10] rD, [11:15] 0, [16:31] imm
    if base in ("VBEZ", "VBNEZ"):
        rd = parse_reg(tokens[1])
        imm = int(tokens[2], 0) & 0xFFFF
        return ((op & 0x3F) << 26) | ((rd & 0x1F) << 21) | imm

    # Arithmetic / Logic R-Type:
    # [0:5] op (26..31)
    # [6:10] rD (21..25)
    # [11:15] rA (16..20)
    # [16:20] rB (11..15)
    # [21:23] ppp (8..10)
    # [24:25] ww (6..7)
    # [26:31] func (0..5)
    if func is not None:
        if base in ("VNOT", "VMOV", "VSQEU", "VSQOU", "VSQRT", "VRTTH"):
            rd = parse_reg(tokens[1])
            ra = parse_reg(tokens[2])
            rb = 0
        else:
            rd = parse_reg(tokens[1])
            ra = parse_reg(tokens[2])
            rb = parse_reg(tokens[3])

        word = ((op & 0x3F) << 26) | \
               ((rd & 0x1F) << 21) | \
               ((ra & 0x1F) << 16) | \
               ((rb & 0x1F) << 11) | \
               ((ppp & 0x07) << 8) | \
               ((ww & 0x03) << 6) | \
               (func & 0x3F)
        return word

    raise ValueError(f"Unhandled instruction format: {line}")

def assemble_file(in_path, out_path):
    with open(in_path, "r") as fin, open(out_path, "w") as fout:
        for raw_line in fin:
            code = assemble_line(raw_line)
            if code is not None:
                fout.write(f"{code:08X}\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 assemble.py <input.asm> <output.fill>")
        sys.exit(1)
    assemble_file(sys.argv[1], sys.argv[2])
    print(f"Successfully assembled {sys.argv[1]} -> {sys.argv[2]}")
