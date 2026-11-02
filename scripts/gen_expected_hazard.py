#!/usr/bin/env python3
"""
Golden Model Generator for Hazard & Branch Verification Suite
"""

def generate_hazard_expected():
    mem = [None] * 128
    
    # Inputs
    mem[0] = 0x0000000000000004  # r1 = 4
    mem[1] = 0x0000000000000008
    mem[2] = 0x0000000000000002
    mem[3] = 0x0000000000000000  # r4 = 0

    # Back-to-Back RAW Arithmetic Dependency:
    # VADD.d.a r2, r1, r1 -> r2 = 4 + 4 = 8
    # VADD.d.a r3, r2, r1 -> r3 = 8 + 4 = 12 (0x0C)
    mem[0x20] = 0x000000000000000C  # Stored to location 32

    # Load-to-Branch & Branch Taken Flush:
    # VBEZ r4, target (condition met because r4 == 0). Branch is TAKEN.
    # Instruction at location 0x21 (VSD r1, 0x0021) is FLUSHED and MUST NOT EXECUTE.
    # mem[0x21] remains unwritten (None / 'xxxxxxxxxxxxxxxx')

    # Target: VADD.d.a r5, r1, r3 -> r5 = 4 + 12 = 16 (0x10)
    mem[0x22] = 0x0000000000000010  # Stored to location 34

    # Branch Not Taken Fall-Through:
    # VBNEZ r4, target (fails because r4 == 0). Falls through.
    # VADD.d.a r6, r5, r1 -> r6 = 16 + 4 = 20 (0x14)
    mem[0x23] = 0x0000000000000014  # Stored to location 35

    with open("tests/expected_dmem_hazard.dump", "w") as f:
        for idx, val in enumerate(mem):
            if val is None:
                f.write(f"Memory location #{idx:11d} : xxxxxxxxxxxxxxxx \n")
            else:
                f.write(f"Memory location #{idx:11d} : {val:016x} \n")
    print("Generated tests/expected_dmem_hazard.dump")

if __name__ == "__main__":
    generate_hazard_expected()
