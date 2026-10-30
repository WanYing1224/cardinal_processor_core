# EE577B Project Phase 2: Cardinal Processor Simulation Framework

This directory is the simulation framework described in item 2 of the Phase 2
handout. Implement the Cardinal processor in `design/`, verify it with your own
programs, and submit this directory.

## Contents

| Path | Description |
|---|---|
| `include/imem.v` | Instruction memory, 256 x 32, asynchronous read. Part of the testbench. Do not modify. |
| `include/dmem.v` | Data memory, 256 x 64, synchronous. Part of the testbench. Do not modify. |
| `tb/tb_cardinal_cpu.v` | Basic top-level testbench: runs one program, dumps data memory and, for `make test`, compares it with an expected dump. Do not change the `cardinal_cpu` instance. |
| `design/cardinal_cpu.v` | Top-level module template. The module name and port list are fixed. |
| `design/register_file.v` | Register file skeleton with a suggested interface. |
| `imem.fill`, `dmem.fill` | Basic sample program and its data (see "Sample program"). |
| `expected_dmem.dump` | Expected data memory dump for the sample program. |
| `makefile`, `cds.lib`, `hdl.var`, `scripts/`, `work/` | NC-Sim flow. |
| `setup_v1721.csh` | Course tool environment (NC-Sim, Design Compiler, DesignWare). |

## Environment

The flow uses Cadence NC-Sim (`ncvlog`, `ncelab`, `ncsim`). Load the course
environment before running `make`.

From the C shell:

```csh
source setup_v1721.csh
make sim
```

From bash:

```bash
csh -f -c 'source setup_v1721.csh; make sim'
```

The DesignWare simulation models come from `$SYNOPSYS_DC/dw/sim_ver`, which is
`/tools/synopsys/syn/Y-2026.03/dw/sim_ver` on the vlab servers.

## Make targets

| Command | Action |
|---|---|
| `make` or `make sim` | Compile, elaborate and run `imem.fill` and `dmem.fill`. Writes `dmem.dump`. |
| `make test` | `make sim`; the testbench also compares data memory with `expected_dmem.dump`, lists every location that differs and prints `TEST PASSED` or `TEST FAILED`. |
| `make simg` | Run in the SimVision GUI. |
| `make clean` | Remove all generated files. Run this before you create your tar file. |

To run another program, pass the files on the command line:

```bash
make test IMEM=tests/my_imem.fill DMEM=tests/my_dmem.fill EXPECTED=tests/my_expected.dump
```

Use relative paths. In the C shell, a `#` inside a path starts a comment.

## Fixed top-level interface

The grading testbench instantiates your processor by port name. Keep this
header exactly as it is in `design/cardinal_cpu.v`:

```verilog
module cardinal_cpu (
    input         clk,        // rising-edge clock
    input         reset,      // synchronous, active high
    input  [0:31] inst_in,    // instruction from the instruction memory
    input  [0:63] d_in,       // load data from the data memory
    output [0:31] pc_out,     // instruction memory address (byte address)
    output [0:31] addr_out,   // data memory address (64-bit word address)
    output        memEn,      // data memory enable (load or store)
    output        memWrEn,    // data memory write enable (store)
    output [0:63] d_out       // store data to the data memory
);
```

- Keep this header as provided. The module name and the port names
  (case-sensitive), directions and widths must match exactly. Do not add or
  remove ports.
- The testbench connects the processor by port name. If the header differs,
  the elaboration step (`ncelab`) stops with an error, for example
  `*E,CUVMUR` (module `cardinal_cpu` not found), `*E,CUVPOM` (port name not
  found), `*F,CUVMPW` (port width differs) or `*F,CUVWSP` (extra port). The
  handout penalizes such a design like code that does not compile.
- You may add any other modules and files in `design/`. Only `cardinal_cpu` has
  a fixed interface. The `design/register_file.v` interface is a suggestion.
- Do not define modules named `imem`, `dmem` or `tb_cardinal_cpu` in `design/`.

## Memory timing

Both memory models are in `include/`.

- **Instruction memory:** `inst_in = MEM[pc_out[22:29]]`. The read is
  asynchronous, and `pc_out` is a byte address (PC + 4 per instruction).
- **Data memory:** `memEn`, `memWrEn`, `addr_out[24:31]` and `d_out` are
  sampled at a rising clock edge.
  - A store (`memEn = memWrEn = 1`) is written at that edge.
  - For a load (`memEn = 1`, `memWrEn = 0`), the data appears on `d_in` after
    that edge, during the following cycle.
  - `d_in` is 0 in a cycle that follows an edge where `memEn` was 0.

## ISA clarifications

The ISA manual and the Phase 2 slides do not cover the two points below the
same way, or do not cover them at all. Your design is graded by these rules.

### PPP field: follow the Phase 2 slides

The ISA manual (Spring 2015) shows R-type bits [21:23] as `000`. The Phase 2
slides (slides 6, 9 and 13) define these bits as the PPP (participation)
field. Where the two documents differ, follow the slides.

PPP applies to every R-type instruction. It selects which bytes of rD are
written back; the other bytes of rD keep their old value. Byte 0 is the most
significant byte (big-endian labeling), and the selection is always by byte,
whatever the WW value.

| PPP | Mnemonic | Bytes of rD written |
|---|---|---|
| 000 | a | all bytes (0-7) |
| 001 | u | upper 32 bits (bytes 0-3) |
| 010 | d | lower 32 bits (bytes 4-7) |
| 011 | e | even bytes (0, 2, 4, 6) |
| 100 | o | odd bytes (1, 3, 5, 7) |
| 101, 110, 111 | - | reserved |

- In assembly, the PPP letter comes before the WW letter, for example
  `VADDah` or `VADDeb` (slide 15).
- PPP = 000 is the `000WW` encoding of the ISA manual, so every encoding in the
  manual behaves as the manual describes.
- The reserved values 101-111 do not appear in the grading programs.
- A partial write still makes rD a destination: an instruction that reads rD
  afterwards must see the merged value. Handle this in your hazard logic
  (slide 26).

### Division by zero

The ISA manual does not define VDIV or VMOD when a divisor is 0. The grading
programs expect the result of the DesignWare divider `DW_div` in unsigned mode
(`tc_mode = 0`). Division by zero appears in many grading programs, not only
in the division tests.

**Recommendation: implement VDIV and VMOD with `DW_div` (`tc_mode = 0`).** It
produces exactly the results below with no extra logic. If you write your own
divider, you must reproduce every rule below yourself.

#### The rule

The WW field splits rA and rB into subfields. Each subfield is handled on its
own:

| Divisor subfield rB_i | VDIV result | VMOD result |
|---|---|---|
| not 0 | rA_i / rB_i (unsigned integer division) | rA_i mod rB_i |
| 0 | all ones: `FF`, `FFFF`, `FFFFFFFF` or `FFFFFFFFFFFFFFFF` | rA_i, unchanged |

- **0 / 0:** follows the second row, so the quotient is all ones and the
  remainder is 0.
- **Mixed subfields:** only subfields whose divisor is 0 use the second row.
  The other subfields of the same instruction are divided normally.
- **WW decides what counts as 0.** With rB = `0000000300000000`, word 1 is 0
  at WW = w, but the double-word is not 0 at WW = d.
- **PPP** selects which bytes of the result reach rD, as for any other R-type
  instruction.

#### Example

rA = `80FF7F0100FF8001`, rB = `0000000300000000`:

| WW | Divisor subfields | VDIV | VMOD |
|---|---|---|---|
| b | `00 00 00 03 00 00 00 00` | `FFFFFF00FFFFFFFF` | `80FF7F0100FF8001` |
| h | `0000 0003 0000 0000` | `FFFF2A55FFFFFFFF` | `80FF000200FF8001` |
| w | `00000003 00000000` | `2AFFD500FFFFFFFF` | `0000000100FF8001` |
| d | `0000000300000000` | `000000002AFFD500` | `0000000100FF8001` |

At WW = b:
- byte 3 is `01 / 03`: quotient `00`, remainder `01`;
- byte 4 is `0 / 0`: quotient `FF`, remainder `00`;
- every other byte has a zero divisor.

#### Implementation notes

- **Parameters:** use `tc_mode = 0` (unsigned). `rem_mode` can be 0 or 1:
  for unsigned operands both give the same results, including division by
  zero.
- **Structure:** one way is to instantiate `DW_div` for each width (eight
  8-bit, four 16-bit, two 32-bit and one 64-bit divider) and select the result
  with WW.
- **Multi-cycle versions:** `DW_div_seq` and `DW_div_pipe` give the same
  values but take several cycles, so your pipeline must wait for them.
- **Unused output:** you can leave `divide_by_0` unconnected.
- **Avoid `/` and `%`:** do not use the Verilog operators for VDIV and VMOD.
  In simulation, a division by zero returns X, and every memory location that
  depends on it fails.
- **Warnings:** the `DW_div` simulation model prints
  `WARNING: ... Division by zero.` each time it divides by zero. This is
  expected and harmless.

## Sample program

`imem.fill` is a basic sanity check that uses only a few instructions. Every
instruction is at least three instructions after the one that writes its
source register (VNOPs fill the gaps), so the program also runs on a pipeline
without forwarding or stalls. It loads two operands from addresses 0 and 1 and
stores one result per instruction:

| Address | Result of |
|---|---|
| 2 | `VAND.d r3, r1, r2` |
| 3 | `VOR.d r4, r1, r2` |
| 4 | `VXOR.d r5, r1, r2` |
| 5 | `VNOT.d r6, r1` |
| 6 | `VMOV.d r7, r2` |
| 7, 8, 9, 10 | `VADD` with WW = b, h, w, d |
| 11, 12 | `VSUB` with WW = b, d |

Passing it shows that fetch, decode, the register file, a few ALU operations,
VLD and VSD work. It does not test the other instructions, the other operand
widths, data hazards or branches. Write your own programs for those
(handout item 4).

## Writing programs

- **`imem.fill`:** one 32-bit hexadecimal instruction per line, at most 256
  lines. Comment every instruction with its assembly mnemonic after `//`. The
  last instruction must be `00000000` (end of program). `F0000000` is VNOP.
- **`dmem.fill`:** one 64-bit hexadecimal word per line.
- **Branch targets** are byte addresses. For example, the instruction at line
  index 4 has address 16 (`0x0010`).

The testbench runs your program as follows:

1. Holds reset for 5 cycles.
2. Runs until the processor fetches `00000000`, or for at most 5000 cycles.
3. Waits 5 more cycles so the pipeline can drain.
4. Prints the cycle count.
5. Writes data memory locations 0-127 to `dmem.dump`.
6. For `make test` (`+EXPECTED=<file>`), compares data memory with the
   expected dump and lists every location that differs.

`CYCLE_TIME` at the top of the testbench sets the clock period (4 ns).

## Grading

The TAs grade your design with a separate testbench and a larger set of
programs. That testbench uses the same `cardinal_cpu` instance, memory models,
clock, 5-cycle reset, end-of-program rule (stop at the `00000000` fetch, then
5 drain cycles) and 5000-cycle limit as `tb/tb_cardinal_cpu.v`.

- The programs cover every instruction at every legal WW, VLD and VSD, VNOP
  and illegal instructions, register 0, VBEZ and VBNEZ (taken, not taken, and
  the flushed instruction after a taken branch), and data dependencies
  between nearby instructions.
- After each program, the testbench compares the data memory with the
  expected contents.
- The programs run back to back in one simulation, and the processor is reset
  before each one. Reset must clear all processor state: the PC, every
  pipeline register and the register file (handout item 3a).

Keep the testbench and the memory models unchanged.

## DesignWare components

The makefile compiles the DesignWare simulation models listed in
`DW_COMPONENTS` (`DW_div DW_sqrt DW02_mult DW01_addsub`). If you instantiate
another component, add it to that list.

For VDIV and VMOD, use `DW_div`. It gives the division-by-zero results that
the grading programs expect (see "Division by zero").

Alternatively, you can `` `include `` a model in your RTL with its full path,
for example:

```verilog
`include "/tools/synopsys/syn/Y-2026.03/dw/sim_ver/DW_div.v"
```

The old `/usr/local/synopsys/...` paths from earlier semesters do not exist on
the vlab servers.

## Submission

Follow the Phase 2 handout:

1. Run `make clean`.
2. Make sure this directory contains only the requested files: your design, the
   testbench, and the `.fill` programs with mnemonic comments. Do not include
   waveform or log files.