================================================================================
 RV32IM SINGLE-CYCLE MCU - FINAL PROJECT 2026
 Advanced CPU Architecture and Hardware Accelerators Lab 361-1-4693, BGU
 Submission: 206458333_318676061
================================================================================

 This file describes the content of every folder and subfolder in this
 submission, as required by clause 10 (Table 1) of the project definition.

 CONTENTS
   1. Submission tree at a glance
   2. DUT/     - synthesizable design sources
   3. TB/      - testbench
   4. SIM/     - ModelSim simulation script
   5. DOC/     - documentation
   6. Quartus/ - Quartus and hardware files
   7. How to reproduce the ModelSim simulation
   8. How to reproduce the Quartus compilation
   9. Conventions and things worth knowing


================================================================================
 1. SUBMISSION TREE AT A GLANCE
================================================================================

 206458333_318676061/
 |
 +-- DUT/
 |   +-- RV32IMscMCU/        32 synthesizable VHDL files (the design itself)
 |
 +-- TB/
 |   +-- RV32IMscMCU/        tb_mcu_top.vhd - the design testbench
 |
 +-- SIM/
 |   +-- RV32IMscMCU/        run_mcu_top.do - ModelSim compile + run script
 |
 +-- DOC/
 |   +-- Readme.txt          this file
 |   +-- Final_report.pdf    the full report (clause 9)
 |
 +-- Quartus/
     +-- RV32IMscMCU/        Signal-Tap file, SDC file and SOF file

 The RV32IMpipelinedMCU subfolders listed in Table 1 belong to the pipelined
 bonus task, which is not part of this submission, so they are not present.


================================================================================
 2. DUT/RV32IMscMCU  -  SYNTHESIZABLE DESIGN SOURCES
================================================================================

 Only design files - no testbench, no simulation script. All 32 files below
 compile without errors in ModelSim (VHDL-2008) and in Quartus.

 --- 2.1 Packages ------------------------------------------------------------

 cond_compilation_package.vhd
     The eight conditional-compilation parameters of the project: G_MODELSIM
     (1 = ModelSim, 0 = Quartus/FPGA), G_WORD_GRANULARITY, the ITCM/DTCM
     address width and word count (M9K / M4K variants), G_PC_WIDTH, G_MA_WIDTH
     and the three PLL divide/multiply ratios. Changing the memory
     configuration of the whole design is done here and only here.

 const_package.vhd
     Constants of the instruction set: opcodes, funct3/funct7 encodings, ALU
     operation codes and the immediate zero/one extension vectors used by
     IDECODE, EXECUTE and CONTROL.

 gpio_pkg.vhd
     The Table 5 memory map as named constants (PORT_LEDR 0x2000,
     PORT_HEX0..PORT_HEX5, PORT_SW 0x2010, PORT_PB 0x2014). It documents the
     address map in one place; the decoders themselves compare the address
     bits directly, which costs no logic.

 aux_package.vhd
     The central component-declaration registry of the project. Every entity
     in the design is declared here once, so a structural file only needs
     "use work.aux_package.all" instead of repeating component declarations.

 --- 2.2 Generic building blocks ---------------------------------------------

 BidirPin.vhd
     Bidirectional pin/bus driver. Used as the "Bi-directional Data BUS" block
     of Figure 1: it drives the shared byte bus during a CPU write and reads
     it back on every cycle.

 tristate_byte.vhd
     8-bit tri-state driver. Every peripheral read port uses one to place its
     byte on the shared Data bus when its chip select and MemRead are active.

 d_latch_byte.vhd
     8-bit transparent D-latch, the GPO register of Figure 5. It is
     transparent only while En = '1' AND clk = '0'; the low phase of SMCLK is
     the safe write window, after the single-cycle combinational chain has
     settled.

 hex7seg_decoder.vhd
     Converts the low nibble of a latched byte into an active-low 7-segment
     pattern for one HEX display.

 --- 2.3 CPU core ------------------------------------------------------------

 IFETCH.VHD
     Program counter, PC+4 adder, next-PC decision mux (reset / hold / jalr /
     branch-taken or jal / PC+4) and the ITCM, an altsyncram ROM initialized
     from a benchmark ITCM.hex file.

 IDECODE.VHD
     Instruction field extraction, the 32x32 register file, sign extension of
     all five immediate formats and the write-back mux (ALU / memory /
     multiplier / accelerator result).

 EXECUTE.VHD
     The ALU and the branch-address generation unit: all RV32I arithmetic,
     logic, shift and comparison operations, and the branch-taken decision.

 CONTROL.VHD
     Main control unit. Decodes the opcode into the datapath control signals
     and also implements the interrupt protocol side of the CPU: the PC hold,
     the INTA acknowledge cycle, the vector fetch and the GIE set/clear rules.

 DMEMORY.VHD
     The DTCM, an altsyncram single-port RAM initialized from a benchmark
     DTCM.hex file and clocked on NOT MCLK so that the address register is
     loaded with the write clock.

 MUL.vhd
     16-bit multiplier built from four 8-bit partial products, the RV32IM
     multiply extension.

 sync.vhd
     Two-flip-flop operand synchronizer (Figure 10b) that carries the two
     divider operands from the MCLK domain into the faster DIVCLK domain.

 divider_accelerator.vhd
     Unsigned restoring divider (Figure 9). DIVRST loads both operands in
     parallel and one quotient bit is produced on every enabled DIVCLK edge.

 RV32I_CORE.vhd
     Structural top of the CPU: IFETCH, IDECODE, EXECUTE, CONTROL, DMEMORY,
     MUL, sync and divider_accelerator, plus the divider handshake state
     machine, the MCLK cycle counter and the GIE / INTA / INTR interface to
     the interrupt controller.

 --- 2.4 Address decoders ----------------------------------------------------

 addr_decoder_gpio.vhd
     Chip selects for PORT_LEDR, PORT_HEX0/1, PORT_HEX2/3, PORT_HEX4/5 and
     PORT_SW.

 addr_decoder_basic_timer.vhd
     Chip selects for BTCTL1, BTCTL2, BTCMPR0, BTCMPR1 and BTCAPR.

 addr_decoder_interrupt.vhd
     Chip selects for IE (0x202C), IFG (0x202D) and TYPE (0x202E).

 --- 2.5 Peripherals ---------------------------------------------------------

 gpio_peripherals.vhd
     The GPIO block of Figure 5: the LEDR and HEX0..HEX5 D-latches, their
     7-segment encoders, the tri-state read-back drivers and the SW input
     port, all sharing one byte-wide Data bus.

 pushbutton_peripheral.vhd
     The KEY1..KEY3 input peripheral. It samples the buttons in the SMCLK
     domain, exposes their level as the read-only PORT_PB register (0x2014)
     and produces a one-cycle active-high press event per key for the
     interrupt controller.

 bit_Timer.vhd
     The N-bit up counter at the heart of the Basic Timer.

 OUTPUT_UNIT.vhd
     The output compare / PWM unit: the EQU0 and EQU1 comparators against
     BTCL0 and BTCL1 and the PWM output flip-flop, in both BTOUTMD modes.

 basic_timer.vhd
     The Basic Timer itself: the BTCTL1, BTCTL2, BTCMPR0, BTCMPR1 and BTCAPR
     registers, the BTSSEL clock-source divider, BTHOLD and BTCLR, the
     capture unit with its two-flip-flop crossing back into SMCLK, and the
     BTINT source selection that drives BTIFG.

 basic_timer_top.vhd
     Structural wrapper that joins basic_timer to its address decoder and
     qualifies the four writable registers with MemWrite.

 interrupt_controller.vhd
     The IE, IFG and TYPE registers, the event capture of BTIFG and the three
     key requests, the priority encoder (Basic Timer 0x10, KEY1 0x14,
     KEY2 0x18, KEY3 0x1C) and the INTR output.

 interrupt_controller_top.vhd
     Structural wrapper: the controller, its address decoder, and the bus
     interface that drives IE/IFG/TYPE on the Data bus for software reads and
     drives TYPE during the active-low INTA acknowledge, where no address is
     placed on the Address bus.

 --- 2.6 Clock tree and tops -------------------------------------------------

 PLL.vhd
     Altera altpll megafunction wrapper with configurable divide/multiply
     ratios. It is instantiated only when G_MODELSIM = 0, i.e. in Quartus.

 clock_tree.vhd
     The Clock Tree of Figure 1: three PLLs producing MCLK for the CPU, SMCLK
     for the peripherals and ACCELCLK (DIVCLK) for the divider accelerator,
     plus the combined locked indication.

 mcu_top.vhd
     The MCU: the RV32I core, the BUS Interface Logic (the ALU address tap,
     the bidirectional Data bus and the peripheral read-return path) and all
     peripherals - GPIO, pushbuttons, Basic Timer and interrupt controller.
     This is the entity the testbench instantiates.

 mcu_system.vhd
     The board-level top entity: the Clock Tree plus mcu_top, with the DE10
     pin names (CLOCK_50, KEY0..KEY3, SW, LEDR, HEX0..HEX5, PWM, CAPIN1/2).
     KEY0 is inverted into the active-high system reset, which is also held
     while the PLLs have not locked. This is the top entity for Quartus.


================================================================================
 3. TB/RV32IMscMCU  -  TESTBENCH
================================================================================

 tb_mcu_top.vhd
     The design testbench. It instantiates mcu_top and plays the role of the
     Clock Tree, because clock_tree only builds its PLLs when G_MODELSIM = 0
     and therefore has no outputs in simulation. It generates MCLK and SMCLK
     at 25 MHz, synchronous and in the same phase as d_latch_byte requires,
     and DIVCLK at 125 MHz, holds reset for five MCLK cycles and then lets
     the program in the ITCM run. KEY1..KEY3, SW, CAPIN1 and CAPIN2 start
     idle and can be driven from the ModelSim Objects/Wave window, or from
     the stimulus process, to exercise the peripherals and the interrupts.


================================================================================
 4. SIM/RV32IMscMCU  -  MODELSIM SIMULATION SCRIPT
================================================================================

 run_mcu_top.do
     The ModelSim script that builds and runs the simulation: it creates a
     fresh work library, compiles the packages, the core, the shared bus and
     GPIO, the Basic Timer and the interrupt system, then the testbench, all
     with vcom -2008; elaborates work.tb_mcu_top against the altera_mf
     library; opens a waveform grouped into CLOCKS AND RESET, CPU,
     PERIPHERAL BUS, INTERRUPTS and BOARD INPUTS AND OUTPUTS; and runs the
     simulation for 100 us.

     The design sources are read from ../../DUT/RV32IMscMCU and the
     testbench from ../../TB/RV32IMscMCU, through the DUTDIR and TBDIR
     variables at the top of the script, so it runs straight out of
     this folder without copying any file.

     See clause 7 below for how to run it.


================================================================================
 5. DOC  -  DOCUMENTATION
================================================================================

 Readme.txt
     This file: the description of every folder and subfolder of the
     submission.

 Final_report.pdf
     The full project report required by clause 9: the top-level block
     diagram, the RTL Viewer results, the three PPA tables (area,
     performance, power) with their Quartus screenshots, a short description
     of each HDL source file, the waveform analysis of benchmark applications
     test1 to test4, and the conclusions.


================================================================================
 6. Quartus/RV32IMscMCU  -  QUARTUS AND HARDWARE FILES
================================================================================

 test.sdc
     The Synopsys Design Constraints file. It creates the 20 ns (50 MHz)
     board clock on the CLOCK_50 port and then calls derive_pll_clocks and
     derive_clock_uncertainty so that TimeQuest also knows the three PLL
     output clocks of the Clock Tree.

 stp1.stp
     The Signal-Tap II logic analyzer file used for the on-board (ISMCE)
     verification: the instance, the sampling clock and the captured signal
     set used to record the MCU behaviour on the real FPGA.

 LAB_5_PIP.sof
     The SRAM Object File produced by the Quartus compilation, i.e. the
     bitstream downloaded to the DE10 board.

 No intermediate Quartus files (db, incremental_db, output_files, qsf, qpf)
 are included, as required by Table 1.


================================================================================
 7. HOW TO REPRODUCE THE MODELSIM SIMULATION
================================================================================

 The design uses sized bit-string literals (const_package) and "elsif
 generate" (IFETCH, RV32I_CORE), so VHDL-2008 is mandatory: every vcom call
 must carry -2008. It also uses altsyncram, so the altera_mf library must be
 available (it is precompiled in ModelSim - Intel FPGA Edition).

   1. Start ModelSim and set SIM/RV32IMscMCU as the working directory.
   2. At the ModelSim prompt:   do run_mcu_top.do
   3. The script reads the design from ../../DUT/RV32IMscMCU and the
      testbench from ../../TB/RV32IMscMCU, compiles everything into a
      fresh work library, opens the waveform and runs 100 us. Nothing
      has to be copied between the folders.

 Which benchmark program runs is decided by the init_file attribute of the
 two altsyncram instances - IFETCH.VHD for the ITCM and DMEMORY.VHD for the
 DTCM. Both hold an absolute path to a "bin/M9K-intel" folder of one
 benchmark application. To run a different test, point both paths at the
 ITCM.hex and DTCM.hex of that test and recompile those two files. A missing
 or mistyped path makes vsim stop with a fatal error at time 0.


================================================================================
 8. HOW TO REPRODUCE THE QUARTUS COMPILATION
================================================================================

   1. Create a Quartus project for the DE10 device and add all 32 VHDL files
      from DUT/RV32IMscMCU. Set the VHDL input version to VHDL 2008.
   2. Set mcu_system as the top-level entity.
   3. Set G_MODELSIM = 0 in cond_compilation_package.vhd so that clock_tree
      and RV32I_CORE instantiate the PLLs instead of taking the clocks
      directly from their input ports.
   4. Add test.sdc to the project as the timing constraint file.
   5. Compile, then program the board with the resulting SOF file, and open
      stp1.stp for the Signal-Tap capture.


================================================================================
 9. CONVENTIONS AND THINGS WORTH KNOWING
================================================================================

 * G_MODELSIM selects the whole build target. With G_MODELSIM = 1 the clocks
   arrive directly on the input ports, which is what the testbench drives;
   with G_MODELSIM = 0 the PLLs of the Clock Tree generate them.

 * SMCLK must be synchronous with MCLK and in phase with it. The GPIO output
   registers are transparent D-latches that open only while SMCLK is low, and
   that low phase is what guarantees the address and data have settled after
   the single-cycle combinational chain.

 * The peripheral Data bus is one shared byte-wide bidirectional bus. Every
   peripheral drives it through a tri-state and releases it to 'Z' otherwise,
   so at most one driver is ever active. BTCAPR is the exception: it is a
   32-bit word register and is returned to the CPU on a dedicated 32-bit path
   in mcu_top rather than through the byte bus.

 * Interrupt signal polarity: INTR and the key requests are active high, INTA
   is active low. During INTA the controller drives TYPE onto the Data bus
   without an address, which is why TYPE has priority over the address-decoded
   read paths in interrupt_controller_top.

 * Interrupt vectors: RESET/NMI type 0x00, Basic Timer type 0x10 (highest
   maskable priority), KEY1 type 0x14, KEY2 type 0x18, KEY3 type 0x1C
   (lowest). Bits 7:6 and 1:0 of IE and IFG are reserved and always read 0.

 * All peripheral addresses are byte addresses inside the 14-bit data address
   space; the I/O region starts at 0x2000.

================================================================================
 End of Readme.txt
================================================================================
