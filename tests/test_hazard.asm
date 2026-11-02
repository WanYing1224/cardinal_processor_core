// =========================================================================
// EE577B Phase 2: Hazard Interlock, Load-Use Stall, & Branch Flush Suite
// =========================================================================

// PC = 0x00: Load r1 = 4
VLD     r1, 0x0000
// PC = 0x04: RAW Stall on r1. r2 = 4 + 4 = 8
VADD.d.a r2, r1, r1
// PC = 0x08: RAW Stall on r2. r3 = 8 + 4 = 12 (0x0C)
VADD.d.a r3, r2, r1
// PC = 0x0C: Store r3 (12) to DMEM[0x20] (location 32)
VSD     r3, 0x0020

// PC = 0x10: Load r4 = 0 from DMEM[3]
VLD     r4, 0x0003
VNOP
VNOP

// PC = 0x1C: Branch if r4 == 0. Taken! Target = PC 0x28 (byte address 40)
VBEZ    r4, 0x0028

// PC = 0x20: MUST BE FLUSHED (Target of flush)
// If flush fails, this writes 4 to DMEM[0x21] (location 33)
VSD     r1, 0x0021

// PC = 0x24: Dead instruction (in case of double bubble)
VNOP

// PC = 0x28: Branch Target arrives here!
// r5 = 4 + 12 = 16 (0x10)
VADD.d.a r5, r1, r3
// PC = 0x2C: Store 16 to DMEM[0x22] (location 34)
VSD     r5, 0x0022

// PC = 0x30: Branch Not Taken Check (r4 is 0, so VBNEZ fails)
VBNEZ   r4, 0x0050
// PC = 0x34: Fall-through succeeds! r6 = 16 + 4 = 20 (0x14)
VADD.d.a r6, r5, r1
// PC = 0x38: Store 20 to DMEM[0x23] (location 35)
VSD     r6, 0x0023

VNOP
VNOP
VNOP
END
