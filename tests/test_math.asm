// =========================================================================
// EE577B Phase 2: Math, SFU, Shift & Width Coverage Test Suite
// =========================================================================

// 1. Initialize Operands from Data Memory
VLD     r1, 0x0000              // Load test vector 1 from DMEM[0]
VLD     r2, 0x0001              // Load test vector 2 from DMEM[1]
VLD     r3, 0x0002              // Load shift amount vector from DMEM[2]
VNOP
VNOP
VNOP

// 2. SFU Operations across WW modes
VDIV.b.a  r4, r1, r2            // 8 parallel 8-bit divisions
VMOD.h.a  r5, r1, r2            // 4 parallel 16-bit modulos
VSQRT.w.a r6, r1                // 2 parallel 32-bit square roots
VSQRT.d.a r7, r1                // 1 64-bit square root
VNOP
VNOP

// 3. Multiplications & Squaring
VMULEU.h.a r8,  r1, r2          // Even unsigned multiply (16b -> 32b)
VMULOU.h.a r9,  r1, r2          // Odd unsigned multiply  (16b -> 32b)
VSQEU.w.a  r10, r1              // Even square (32b -> 64b)
VSQOU.w.a  r11, r1              // Odd square  (32b -> 64b)
VNOP
VNOP

// 4. Shifts and Half-Rotate
VSLL.h.a   r12, r1, r3          // Logical shift left
VSRL.h.a   r13, r1, r3          // Logical shift right
VSRA.h.a   r14, r1, r3          // Arithmetic shift right
VRTTH.b.a  r15, r1              // Swap nibbles within 8-bit bytes
VRTTH.h.a  r16, r1              // Swap bytes within 16-bit halfwords
VNOP
VNOP
VNOP

// 5. Store Computation Results to DMEM
VSD     r4,  0x0010
VSD     r5,  0x0011
VSD     r6,  0x0012
VSD     r7,  0x0013
VSD     r8,  0x0014
VSD     r9,  0x0015
VSD     r10, 0x0016
VSD     r11, 0x0017
VSD     r12, 0x0018
VSD     r13, 0x0019
VSD     r14, 0x001A
VSD     r15, 0x001B
VSD     r16, 0x001C

VNOP
VNOP
VNOP
END
