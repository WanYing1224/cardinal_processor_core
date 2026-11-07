# Cardinal 64-Bit Variable-Width SIMD Vector Processor Core

[![Simulation](https://img.shields.io/badge/NC--Sim-Passing-brightgreen.svg)]() [![Synthesis](https://img.shields.io/badge/Synopsys%20DC-GSCL45nm-blue.svg)]() [![Equivalence](https://img.shields.io/badge/Cadence%20LEC-Equivalent-success.svg)]()

A synthesizable, 4-stage in-order pipelined 64-bit SIMD vector processor core designed in Verilog HDL for high-throughput data processing and integration with a 4×4 On-Chip Mesh Interconnect.

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Instruction Set & SIMD Subword Partitioning](#instruction-set--simd-subword-partitioning)
- [Design Hierarchy & Submodules](#design-hierarchy--submodules)
- [Directory Layout](#directory-layout)
- [Verification & Test Framework](#verification--test-framework)
- [Synthesis & Physical Performance](#synthesis--physical-performance)
- [Getting Started & Simulation Guide](#getting-started--simulation-guide)

---

## Architecture Overview

The **Cardinal Processor Core (`cardinal_cpu`)** processes 64-bit vector registers across four software-selectable subword slice granularities. Instructions are fixed 32-bit words aligned to 4-byte boundaries, adhering strictly to **Big-Endian** bit and byte indexing:
- **Instructions:** Indexed as `[0:31]`, where bit `0` is MSB and bit `31` is LSB.
- **Data Words:** Indexed as `[0:63]`, where bit `0` is MSB and bit `63` is LSB.
- **Subword Packing:** Vector slices are ordered starting with slice 0 occupying the MSB positions.

---

## Pipeline Architecture

The processor implements a compact, high-efficiency 4-stage pipeline that eliminates dedicated execution-memory delay slot hazards by unifying compute and memory operations into a single stage:

<p align="center">
  <img src="Pipline Architecture Schematic.jpg" alt="Pipline Architecture Schematic" width="1000"/>
  <br/>
  <em>Figure 1: Pipline Architecture Schematic</em>
</p>

### Key Microarchitectural Features
1. **Early Branch Resolution (ID Stage):** Evaluates `VBEZ` / `VBNEZ` zero conditions directly in the decode stage. Branches resolve in 1 cycle, asserting `flush_if_id` to eliminate delay slot penalty cycles and squash speculative execution.
2. **Centralized RAW Interlocking:** The hazard detection unit continuously monitors destination registers in `EX` and `WB` against current source specifiers (`rA`, `rB`, and `rD` when utilized as a store source or branch comparator). Hazards trigger `stall_pc`, `stall_if_id`, and inject a hardware `bubble_id_ex` (`32'hF000_0000`).
3. **Byte-Level Register File Masking:** Each of the 32 64-bit registers contains 8 independent byte lanes gated by `wrByteEn[0:7]`, derived dynamically from the instruction's `PPP` participation field. Register $R_0$ is hardwired to logic 0.

---

## Instruction Set & SIMD Subword Partitioning

### SIMD Granularities (`ww` field: bits `[11:12]`)
* **Byte (`.b` / `2'b00`):** Eight parallel 8-bit slices (`[0:7]`, `[8:15]`, ..., `[56:63]`)
* **Half-word (`.h` / `2'b01`):** Four parallel 16-bit slices (`[0:15]`, `[16:31]`, `[32:47]`, `[48:63]`)
* **Word (`.w` / `2'b10`):** Two parallel 32-bit slices (`[0:31]`, `[32:63]`)
* **Double-word (`.d` / `2'b11`):** One full 64-bit slice (`[0:63]`)

### Subfield Participation (`PPP` field: bits `[21:23]`)
Controls which subfields participate in register writeback (`wrByteEn[0:7]`):
* `3'b000`: All subwords participate (`8'b1111_1111`)
* `3'b001`: Upper 32 bits participate (`8'b1111_0000`)
* `3'b010`: Lower 32 bits participate (`8'b0000_1111`)
* `3'b011`: Even subwords participate
* `3'b100`: Odd subwords participate

### Supported Instruction Classes
* **Memory & Branch:** `VLD`, `VSD`, `VBEZ`, `VBNEZ`, `VNOP`
* **Bitwise Logic & Data Movement:** `VAND`, `VOR`, `VXOR`, `VNOT`, `VMOV`
* **Arithmetic & Multipliers:** `VADD`, `VSUB`, `VMULEU` (Even Unsigned Multiply), `VMULOU` (Odd Unsigned Multiply), `VSQEU` (Even Square), `VSQOU` (Odd Square)
* **Shifts & Rotates:** `VSLL` (Logical Left), `VSRL` (Logical Right), `VSRA` (Arithmetic Right), `VRTTH` (Swap Halves)
* **Special Function Unit (SFU):** `VDIV` (Unsigned Division), `VMOD` (Remainder/Modulo), `VSQRT` (Square Root Extraction)

---

## Design Hierarchy & Submodules

```text
cardinal_cpu.v                  # Top-level core integration & pipeline registers
├── control_decoder.v           # Combinational opcode/sub-opcode decoder & PPP generator
├── register_file.v             # 32x64-bit dual-read / single-write RF with byte enables
├── hazard_unit.v               # RAW stall interlock & branch flush generation
├── alu.v                       # Single-cycle SIMD arithmetic, shift, and logic array
└── sfu.v                       # Multi-slice non-restoring divider, modulo, and square root unit
```

---

## Directory Layout

```text
.
├── design/                     # Synthesizable RTL source files
│   ├── alu.v
│   ├── cardinal_cpu.v
│   ├── control_decoder.v
│   ├── hazard_unit.v
│   ├── register_file.v
│   └── sfu.v
├── include/                    # Simulation models & standard cell libraries
│   ├── dmem.v                  # 256x64-bit synchronous data memory
│   ├── imem.v                  # 256x32-bit asynchronous instruction memory
│   └── gscl45nm.v              # 45nm standard cell simulation library
├── netlist/                    # Gate-level netlists & timing constraints
│   ├── cardinal_cpu.syn.v      # Post-synthesis structural Verilog netlist
│   └── cardinal_cpu.sdc        # Synopsys Design Constraints file
├── report/                     # EDA verification, timing, and area reports
│   ├── cardinal_cpu.check_design
│   ├── cardinal_cpu.area
│   ├── cardinal_cpu.timing
│   ├── cardinal_cpu.power
│   └── cardinal_cpu.lec
├── scripts/                    # Assembler, Python emulators, and EDA runscripts
│   ├── assemble.py             # Two-pass Cardinal ISA assembler
│   ├── gen_expected.py         # Baseline golden model reference emulator
│   ├── gen_expected_hazard.py  # Hazard test golden model reference emulator
│   ├── syn_cardinal_cpu.tcl    # Synopsys Design Compiler synthesis script
│   └── lec_cardinal_cpu.do     # Cadence Conformal LEC formal verification script
├── tb/                         # Self-checking unit and core testbenches
│   ├── tb_cardinal_cpu.v       # Top-level simulation and regression testbench
│   ├── tb_alu.v
│   ├── tb_control_decoder.v
│   ├── tb_hazard_unit.v
│   ├── tb_register_file.v
│   └── tb_sfu.v
├── tests/                      # Assembly programs, memory images, and dumps
│   ├── test_math.asm           # SFU, SIMD width, and multiplier test program
│   ├── test_hazard.asm         # Interlock, delay slot, and branch squash test program
│   ├── imem.fill / dmem.fill   # Baseline test vectors
│   └── expected_dmem*.dump     # Golden memory verification snapshots
├── cds.lib                 
├── hdl.var               
├── imem.fill                   # MUST BE IN ROOT FOR "make test"
├── dmem.fill                   # MUST BE IN ROOT FOR "make test"
├── expected_dmem.dump          # MUST BE IN ROOT FOR  "make test"
├── makefile                    # Build, simulation, and regression targets
└── README.md
```

---

## Verification & Test Framework

Verification is performed using a two-pass assembler and Python-based golden reference simulators:
1. **Two-Pass Assembler (`scripts/assemble.py`):** Resolves symbolic forward/backward labels and converts assembly mnemonics into machine code hex images (`imem.fill`).
2. **Golden Reference Modeling (`scripts/gen_expected*.py`):** Emulates exact Big-Endian byte masking, DesignWare integer truncations, and memory writes to create golden reference memory dumps (`expected_dmem.dump`).
3. **Core Test Suites:**
   * **Baseline Suite:** Validates linear ALU instructions, loads/stores, and unhindered throughput.
   * **Math & SFU Suite (`test_math.asm`):** Targets all 11 required operations (`VMULEU`, `VMULOU`, `VSQEU`, `VSQOU`, `VSLL`, `VSRL`, `VSRA`, `VRTTH`, `VDIV`, `VMOD`, `VSQRT`) across all four slice widths with zero-division corner cases.
   * **Hazard Suite (`test_hazard.asm`):** Stresses 1-cycle EX collisions, 2-cycle WB collisions, `rD` store dependencies, and speculative store suppression on taken branches.

---

## Synthesis & Physical Performance

Synthesized targeting the **GSCL45nm** (45nm standard cell CMOS library, nominal $1.1\,\text{V}$) using **Synopsys Design Compiler**:

| Metric | Result | Description / Notes |
| :--- | :--- | :--- |
| **Total Standard Cell Area** | **$732{,}907.21\,\mu\text{m}^2$** | Comprising 282,715 cells ($607{,}264.80\,\mu\text{m}^2$ in `u_sfu`) |
| **Sequential Storage** | **2,424 DFFs** | 1,984 in Register File ($R_0$ constant 0) + 440 in pipeline registers |
| **Critical Path Delay** | **$13.81\,\text{ns}$** | Launch: `id_ex_rB_data_reg` $\rightarrow$ SFU ripple divider $\rightarrow$ Capture: `ex_wb_calc_result_reg` |
| **Clock Setup Slack** | **$0.00\,\text{ns}$ (MET)** | Target $T_{\text{clk}} = 14.00\,\text{ns}$ ($F_{\max} = 71.43\,\text{MHz}$) |
| **Total Core Power** | **$6.1118\,\text{mW}$** | Dynamic: $3.5424\,\text{mW}$ ($51.8\%$ clock network) + Static Leakage: $2.5694\,\text{mW}$ |
| **Formal Equivalence** | **PASSED (0 Mismatches)** | Cadence Conformal LEC: 130 POs & 2,360 DFF state points verified equivalent |

---

## Getting Started & Simulation Guide

### Prerequisites
* **Cadence NC-Sim / Xcelium** (`ncverilog` / `xrun`)
* **Synopsys Design Compiler** (for synthesis runs)
* **Cadence Conformal LEC** (for formal equivalence verification)
* **Python 3.x**

### Running Core Regressions

```bash
# 1. Run the default baseline simulation suite
make test

# 2. Run the comprehensive Math, Multiplier, and SFU verification suite
make test IMEM=tests/imem_math.fill DMEM=tests/dmem_math.fill EXPECTED=tests/expected_dmem_math.dump

# 3. Run the Pipeline Hazard & Speculative Branch Squash test suite
make test IMEM=tests/imem_hazard.fill DMEM=tests/dmem_hazard.fill EXPECTED=tests/expected_dmem_hazard.dump

# 4. Clean simulation run artifacts and temporary dumps
make clean
```

### Running Unit Testbenches
Individual submodules can be compiled and verified independently:
```bash
ncverilog +access+rwc tb/tb_alu.v design/alu.v                           # Verifies Vector ALU arithmetic and shift modes
ncverilog +access+rwc tb/tb_sfu.v design/sfu.v                           # Verifies non-restoring divider and square-root modules
ncverilog +access+rwc tb/tb_register_file.v design/register_file.v       # Verifies dual-port access and 8-lane byte write masks
ncverilog +access+rwc tb/tb_hazard_unit.v design/hazard_unit.v           # Verifies stall and bubble injection timing
ncverilog +access+rwc tb/tb_control_decoder.v design/control_decoder.v   # Exhaustively checks all 64 instruction opcodes
```

### Running Behavioral RTL Simulation
To verify the whole design.
```bash
ncverilog +gui +access+rwc tb/tb_cardinal_cpu.v design/control_decoder.v design/register_file.v design/hazard_unit.v design/alu.v design/sfu.v design/cardinal_cpu.v +IMEM=imem.fill +DMEM=dmem.fill +EXPECTED=expected_dmem.dump
```

### Running Gate-Level Simulations
To verify the synthesized netlist with annotated standard cell models:
```bash
ncverilog +gui +access+rwc tb/tb_cardinal_cpu.v include/gscl45nm.v netlist/cardinal_cpu.syn.v +IMEM=imem.fill +DMEM=dmem.fill +EXPECTED=expected_dmem.dump
```
*(Configured with `CYCLE_TIME = 20 ns` to satisfy the $13.81\,\text{ns}$ combinational SFU delay path).*

---

## Authors & Acknowledgments

**Course**: *EE577B - VLSI System Design, University of Southern California (USC)* 
**Author**: [Kevelyn Lin](https://github.com/WanYing1224), [Yuxiang Luo](https://github.com/lllyxxxx)
