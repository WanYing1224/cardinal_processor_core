#!/usr/bin/env python3
"""
Golden Reference Model Generator for Cardinal Test Suites
Formats expected_dmem.dump to match tb_cardinal_cpu expectations.
"""
import math

def u64(val):
    return val & 0xFFFFFFFFFFFFFFFF

def run_math_suite():
    # Initialize 128 words with 'x' representation (None)
    mem = [None] * 128
    
    # Input vectors
    mem[0] = 0x0123456789ABCDEF
    mem[1] = 0x80FF7F01FF018000
    mem[2] = 0x0004000400040004
    mem[3] = 0x0000000000000000

    r1 = mem[0]
    r2 = mem[1]
    r3 = mem[2]

    # VDIV.b.a r4, r1, r2 (8 parallel 8-bit unsigned divisions)
    r4 = 0
    for i in range(8):
        shift = (7 - i) * 8
        a_b = (r1 >> shift) & 0xFF
        b_b = (r2 >> shift) & 0xFF
        q = (a_b // b_b) if b_b != 0 else 0x00
        r4 |= (q & 0xFF) << shift

    # VMOD.h.a r5, r1, r2 (4 parallel 16-bit modulos)
    r5 = 0
    for i in range(4):
        shift = (3 - i) * 16
        a_h = (r1 >> shift) & 0xFFFF
        b_h = (r2 >> shift) & 0xFFFF
        rem = (a_h % b_h) if b_h != 0 else a_h
        r5 |= (rem & 0xFFFF) << shift

    # VSQRT.w.a r6, r1 (2 parallel 32-bit square roots)
    r6 = 0
    for i in range(2):
        shift = (1 - i) * 32
        a_w = (r1 >> shift) & 0xFFFFFFFF
        root = int(math.isqrt(a_w))
        r6 |= (root & 0xFFFFFFFF) << shift

    # VSQRT.d.a r7, r1 (1 64-bit square root)
    r7 = int(math.isqrt(r1))

    # VMULEU.h.a r8, r1, r2 (Even elements 0, 2: 16b -> 32b)
    h0_a = (r1 >> 48) & 0xFFFF
    h0_b = (r2 >> 48) & 0xFFFF
    h2_a = (r1 >> 16) & 0xFFFF
    h2_b = (r2 >> 16) & 0xFFFF
    r8 = (((h0_a * h0_b) & 0xFFFFFFFF) << 32) | ((h2_a * h2_b) & 0xFFFFFFFF)

    # VMULOU.h.a r9, r1, r2 (Odd elements 1, 3: 16b -> 32b)
    h1_a = (r1 >> 32) & 0xFFFF
    h1_b = (r2 >> 32) & 0xFFFF
    h3_a = r1 & 0xFFFF
    h3_b = r2 & 0xFFFF
    r9 = (((h1_a * h1_b) & 0xFFFFFFFF) << 32) | ((h3_a * h3_b) & 0xFFFFFFFF)

    # VSQEU.w.a r10, r1 (Even element 0: 32b -> 64b)
    w0_a = (r1 >> 32) & 0xFFFFFFFF
    r10 = u64(w0_a * w0_a)

    # VSQOU.w.a r11, r1 (Odd element 1: 32b -> 64b)
    w1_a = r1 & 0xFFFFFFFF
    r11 = u64(w1_a * w1_a)

    # Shifts (WW=16b, shift count = 4)
    r12 = 0
    for i in range(4):
        shift = (3 - i) * 16
        val = (r1 >> shift) & 0xFFFF
        shamt = ((r3 >> shift) & 0xFFFF) % 16
        r12 |= ((val << shamt) & 0xFFFF) << shift

    r13 = 0
    for i in range(4):
        shift = (3 - i) * 16
        val = (r1 >> shift) & 0xFFFF
        shamt = ((r3 >> shift) & 0xFFFF) % 16
        r13 |= (val >> shamt) << shift

    r14 = 0
    for i in range(4):
        shift = (3 - i) * 16
        val = (r1 >> shift) & 0xFFFF
        shamt = ((r3 >> shift) & 0xFFFF) % 16
        s_val = val if val < 0x8000 else val - 0x10000
        res = (s_val >> shamt) & 0xFFFF
        r14 |= res << shift

    # VRTTH.b.a (Swap nibbles in each 8-bit byte)
    r15 = 0
    for i in range(8):
        shift = (7 - i) * 8
        byte_val = (r1 >> shift) & 0xFF
        swapped = ((byte_val & 0x0F) << 4) | ((byte_val & 0xF0) >> 4)
        r15 |= swapped << shift

    # VRTTH.h.a (Swap bytes in each 16-bit halfword)
    r16 = 0
    for i in range(4):
        shift = (3 - i) * 16
        h_val = (r1 >> shift) & 0xFFFF
        swapped = ((h_val & 0x00FF) << 8) | ((h_val & 0xFF00) >> 8)
        r16 |= swapped << shift

    # Store calculated results at memory locations 16 through 28
    mem[16] = r4
    mem[17] = r5
    mem[18] = r6
    mem[19] = r7
    mem[20] = r8
    mem[21] = r9
    mem[22] = r10
    mem[23] = r11
    mem[24] = r12
    mem[25] = r13
    mem[26] = r14
    mem[27] = r15
    mem[28] = r16

    with open("tests/expected_dmem_math.dump", "w") as f:
        for idx, val in enumerate(mem):
            if val is None:
                f.write(f"Memory location #{idx:11d} : xxxxxxxxxxxxxxxx \n")
            else:
                f.write(f"Memory location #{idx:11d} : {val:016x} \n")
    print("Generated tests/expected_dmem_math.dump in tb_cardinal_cpu format.")

if __name__ == "__main__":
    run_math_suite()
