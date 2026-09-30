# Lab 5 — RV32IM Pipelined Processor (Course 361-1-4693, BGU)

This project converts the supplied **single-cycle RV32IM** core into a fully **pipelined 5-stage architecture** (IF · ID · EX · MEM · WB) written in **structural VHDL**. It supports the user-level RV32I instruction set plus the `MUL` extension, and targets the **DE10-Standard** board (Cyclone V `5CSXFC6D6F31C6`). The design adds hazard hardware (forwarding, load/MUL-use stalling, branch flush), a **2-stage pipelined multiplier**, an on-chip PLL for the core clock, and a SignalTap-oriented debug instrumentation layer. The authoritative datapath is the figure `rv32ipipeline.png`.

---

## Top Level

### `RV32I_CORE_PIPLINE.vhd`
Structural top of the pipeline core. Instantiates all five stages, the four pipeline registers, the three hazard units, the multiplier stages, and the PLL. Also contains two non-datapath blocks: a **debug shadow pipeline** that mirrors the instruction word and PC through EX/MEM/WB for observation (so the real registers needn't be widened), and the **instrumentation counters** (`CLKCNT`, `STCNT`, `FHCNT`) plus the SignalTap trigger (`STRIGGER`). Hazard enables are derived here: a stall freezes PC + IF/ID and bubbles ID/EX, while a flush squashes IF/ID, ID/EX and EX/MEM — with flush taking priority over stall.

### `PIPLINE_USER_INTERFACE.vhd`
Board-level wrapper for the DE10-Standard. Maps physical pins (`KEY` for reset/enable, `SW[7:0]` for the breakpoint address `BPADDR`) onto the core, applying reset polarity inversion. Internal taps are observed via SignalTap rather than driven to output pins.

---

## Pipeline Stages

### `IFETCH.VHD`  *(Stage 1 — IF)*
Fetches the instruction at the current PC from the ITCM and computes `PC+4`. Selects the next PC among `PC+4`, the branch/jump target, and the JALR target. **Branches and jumps are resolved at stage 4 (MEM)**, so the redirect inputs (`addr_gen`, `br_or_jump_taken`, `Jalr_ctrl`, `alu_res`) come from the *registered* EX/MEM outputs. PC advance is gated by the stall enable.

### `IDECODE.vhd`  *(Stage 2 — ID)*
Decodes the instruction, reads the register file, and generates the sign-extended immediate. The register-file **write port is driven by the retiring (MEM/WB) instruction** — write-back data, `rd`, `RegWrite`, `RegDst` and `PC+4` all arrive from MEM/WB, so the JAL/JALR link-address MUX inside this stage acts on the correct instruction.

### `EXECUTE.VHD`  *(Stage 3 — EX)*
Performs the ALU operation and computes the branch/jump target address (`adder_gen`). Contains the **operand-forwarding MUXes** for both ALU inputs (driven by `Forward_Ain`/`Forward_Bin` from the forwarding unit). The forwarded rs2 value is also captured for store data, with the ALUSrc MUX applied *after* forwarding on the B path so store addresses aren't corrupted. Launches **MUL stage 1** (the partial products) when `MULOp` is set.

### `DMEMORY.VHD`  *(Stage 4 — MEM)*
Data memory (DTCM, RAM). Reads/writes the word-addressed memory; the byte address from the ALU result is sliced (`>>2`) down to the DTCM word index. Store data is the forwarded rs2. Operates in parallel with **MUL stage 2** in this stage.

### `WB_MUX.vhd`  *(Stage 5 — WB)*
Write-back select. Chooses the value written to the register file among the **ALU result**, the **DTCM load data**, and the **MUL result** (the JAL/JALR PC+4 link is inserted on the IDECODE side). Controlled by `WBSrc`/`MemtoReg`.

---

## Pipeline Registers

Each register latches on the (PLL-derived) clock. `IF_ID` and `ID_EX` honor stall (hold/bubble) and flush; `EX_MEM` honors flush; all reset to a NOP-equivalent state.

| File | Boundary | Key payload carried |
|---|---|---|
| `IF_ID_REG.vhd` | IF → ID | `pc`, `pc_plus4`, `instruction` (+ `ena`/`flush`) |
| `ID_EX_REG.vhd` | ID → EX | `pc`, `pc_plus4`, `read_data1/2`, `imm32`, `rs1/rs2/rd`, full control bundle (`ALUOp`, `ALUSrc`, `UpperImm`, `MULOp`, `Branch`, `Jal`, `Jalr`, `MemRead/Write`, `RegWrite`, `MemtoReg`, `RegDst`, `WBSrc`) |
| `ex_mem_reg.vhd` | EX → MEM | `pc_plus4`, `read_data1/2`, `imm32`, `rs1/rs2/rd`, `Alu_Res`, `Adder_gen`, MUL stage-1 partials `p0..p3`, `MULOp`, `br_or_jump_taken`, `Jalr_ctrl`, and MEM/WB control |
| `MEM_WB_REG.vhd` | MEM → WB | `pc_plus4`, `alu_res`, `mem_data`, `mul_res`, `rd`, `RegWrite`, `MemtoReg`, `RegDst`, `WBSrc` |

---

## Hazard Hardware

### `forwarding_unit.vhd`
Compares the ID/EX source registers (`rs1`, `rs2`) against the destination registers in **EX/MEM** and **MEM/WB** (gated by their `RegWrite`), emitting 2-bit `Forward_Ain`/`Forward_Bin` selects to bypass operands into EXECUTE. Resolves EX-hazards (one ahead) and MEM-hazards (two ahead) without stalling.

### `STALL_UNIT.vhd`
Detects the **load-use** and **MUL-use** interlocks: if the instruction in EX is a load (`MemRead`) or a multiply (`MULOp`) and its `rd` matches an `rs1`/`rs2` of the instruction in IF/ID, it asserts `Stall` for one cycle (freeze PC + IF/ID, bubble ID/EX) — the case forwarding alone cannot cover.

### `FLUSH_UNIT.vhd`
Generates the squash signal when a branch/jump (or JALR) is **taken**, reading the *registered* EX/MEM redirect bits (resolution at stage 4). The flush kills the wrong-path instructions sitting in IF/ID, ID/EX and EX/MEM.

---

## Multiplier (2-stage)

### `MUL_STAGE1.VHD`
Runs in **EX**. Produces the four 16-bit partial products (`p0..p3`) from the operands; these are carried through EX/MEM.

### `MUL_STAGE2.VHD`
Runs in **MEM**. Combines the partial products into the final 32-bit result, preserving the full-width intermediate carry. The result feeds the WB MUX.

---

## Clocking & Memory

### `PLL.vhd`
Altera ALTPLL megafunction. On the FPGA it converts the **50 MHz** board clock to the **75 MHz** core clock (×3 ÷2). In ModelSim the PLL is bypassed (`mclk = clk_i`) via the `MODELSIM` generate guard.

### Memory (ITCM / DTCM)
Word-addressed on-chip memories initialized from Intel-HEX files. Instruction memory lives inside `IFETCH`; data memory is `DMEMORY.VHD`.

---

## Support Packages

| File | Role |
|---|---|
| `aux_package.vhd` | Component declarations for all entities (structural binding). |
| `const_package.vhd` | Global constants / widths (`G_PC_WIDTH`, `G_ADDRWIDTH`, `G_DATA_WORDSNUM`, …). |
| `cond_compilation_package.vhd` | Conditional-compilation switches (e.g. `G_MODELSIM`, `G_WORD_GRANULARITY`). |
| `CONTROL.VHD` | Main control decoder: maps opcode/funct of the IF/ID instruction to the full control bundle. |

---

## Debug & Instrumentation

The core exposes per-stage **PC** and **instruction** taps (`IFpc`/`IFinstruction` … `WBpc`/`WBinstruction`), free-running `CLKCNT`, stall counter `STCNT`, flush counter `FHCNT`, and a `STRIGGER` pulse when the IF-stage PC (word index) equals `BPADDR`. The EX/MEM/WB instruction and PC taps are produced by an observation-only **shadow pipeline** that mirrors the bubble/hold behavior of the real registers.

---

## Toolchain

- **Quartus Prime** — synthesis, place-and-route, pin assignment, programming.
- **ModelSim Intel FPGA Edition** — RTL/gate simulation.
- **TimeQuest** — static timing analysis (PLL-derived clock constrained via `derive_pll_clocks`).
- **SignalTap** — in-system observation of the stage taps and counters.

---

## Hardware Test Case

Tested on the **DE10-Standard** FPGA board: `KEY` buttons drive reset/enable, `SW[7:0]` set the breakpoint address (`BPADDR`), and SignalTap captures the pipeline state when the IF-stage PC reaches the breakpoint.

---

By: yuval elron and amit postelnik
