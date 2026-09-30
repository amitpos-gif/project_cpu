# RISC-V RV32IM CPU Core & MCU — Structural VHDL

A fully functional five-stage pipelined RISC-V RV32IM processor designed from scratch in structural VHDL, taken through simulation, FPGA synthesis and on-hardware validation. The project is split into two parts: the pipelined CPU core, and a full MCU built on top of it.

---

## Projects

### 1. Pipelined RISC-V RV32IM CPU Core (`risc v cpu - project/`)

A five-stage pipelined implementation of the RISC-V RV32IM ISA (integer base + hardware multiply), built in structural VHDL from a single-cycle baseline.

**Pipeline stages:** IF → ID → EX → MEM → WB

**Key features:**
- Full data forwarding unit (EX/MEM and MEM/WB forwarding paths)
- Combinational hazard detection and stall unit
- Branch resolution with pipeline flush
- Hardware multiplier using the FPGA's embedded 8-bit multipliers (M extension)
- Structural HDL throughout — no behavioral shortcuts

**Verification & Validation:**
- Simulated in ModelSim against a RARS golden reference model
- IPC and functional correctness checked across a suite of test programs
- Mismatches analysed and debugged in simulation
- Synthesised and validated on an Intel FPGA with Signal-Tap on-hardware debug
- PPA (Power, Performance, Area) characterised and compared against the single-cycle baseline in Quartus

---

### 2. RV32IM-based MCU (`mcu - project/`)

An extension of the pipelined core into a full microcontroller unit.

**Added peripherals and features:**
- On-chip instruction and data memory
- Memory-mapped GPIO and I/O interface
- Vectored interrupt controller
- Hardware multicycle division accelerator with clock-domain-crossing synchronisation

---

## Tools & Flow

| Tool | Purpose |
|------|---------|
| Intel Quartus | Synthesis, FPGA implementation, PPA analysis |
| ModelSim | RTL simulation and functional verification |
| Signal-Tap | On-hardware debug and signal probing |
| RARS | RISC-V golden reference model for verification |

**HDL:** Structural VHDL  
**Target FPGA:** Intel (Altera) FPGA  
**ISA:** RISC-V RV32IM

---

## Repository Structure

```
project_cpu/
├── risc v cpu - project/    # Five-stage pipelined RV32IM CPU core
│   ├── src/                 # VHDL source files (datapath, control, pipeline registers)
│   └── sim/                 # Simulation testbenches and scripts
└── mcu - project/           # Full MCU built on the pipelined core
    ├── src/                 # MCU peripherals and top-level integration
    └── sim/                 # MCU simulation files
```

---

## Background

Designed as part of the Advanced CPU Architecture course at Ben-Gurion University of the Negev, Hardware and VLSI & Semiconductor Devices tracks.
