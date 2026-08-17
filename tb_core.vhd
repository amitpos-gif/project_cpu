--============================================================================
-- Testbench for RV32I_CORE (single-cycle RV32IM + divider accelerator)
--
-- Test program (ITCM_tb.mif):
--   PC 0x00 : addi x2,x0,100
--   PC 0x04 : addi x3,x0,7
--   PC 0x08 : divu x4,x2,x3     -> x4 must be 14
--   PC 0x0C : remu x5,x2,x3     -> x5 must be  2
--   PC 0x10 : mul  x6,x2,x3     -> x6 must be 700
--   PC 0x14 : addi x7,x0,42     -> x7 must be 42   (flow-integrity marker)
--   PC 0x18 : addi x8,x0,99     -> x8 must be 99   (flow-integrity marker)
--
-- HOW TO RUN
--   The ITCM/DTCM init_file paths inside IFETCH.VHD and DMEMORY.VHD must point
--   at ITCM_tb.mif / DTCM_tb.mif (shipped next to this file), otherwise vsim
--   aborts with "Failed to open VHDL file ... .hex".
--
--   vlib work
--   vcom -2008 cond_compilation_package.vhd const_package.vhd aux_package.vhd
--   vcom -2008 IFETCH.VHD IDECODE.VHD CONTROL.VHD EXECUTE.VHD DMEMORY.VHD
--   vcom -2008 MUL.vhd PLL.vhd sync.vhd divider_accelerator.vhd RV32I_CORE.vhd
--   vcom -2008 tb_core.vhd
--   vsim -c -L altera_mf -voptargs=+acc tb_core -do "run -all; quit -f"
--
-- CLOCK RATIO
--   The divider needs 32 DIVCLK iterations plus CDC latency. DIVCLK_HALF and
--   MCLK_HALF are generics so the ratio can be swept:
--       vsim ... tb_core -gMCLK_HALF=40ns -gDIVCLK_HALF=5ns    (ratio 8)
--   The testbench reports the ratio it is running at and checks the results,
--   so a sweep shows exactly which ratios the core is correct at.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.all;

ENTITY tb_core IS
	GENERIC(
		MCLK_HALF		: TIME		:= 500 ns;		-- CPU clock half period
		DIVCLK_HALF	: TIME		:= 5 ns;			-- divider clock half period
		RUN_CYCLES	: INTEGER	:= 24;				-- MCLK cycles to run
		VERBOSE			: BOOLEAN	:= TRUE				-- per-cycle trace
	);
END tb_core;

ARCHITECTURE test OF tb_core IS
	SIGNAL clk, divclk, rst	: STD_LOGIC := '0';
	SIGNAL pc								: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL instruction			: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL RegWrite					: STD_LOGIC;
	SIGNAL MemWrite, Branch	: STD_LOGIC;
	SIGNAL brTaken					: STD_LOGIC;
	SIGNAL rd1, rd2					: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL wdata, alu_res		: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL dtcm_addr				: STD_LOGIC_VECTOR(10 DOWNTO 0);
	SIGNAL dtcm_wr, dtcm_rd	: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL mclk_cnt					: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL done							: BOOLEAN := FALSE;

	CONSTANT INSTR_DIVU	: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"02315233";
	CONSTANT INSTR_REMU	: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"023172B3";
	CONSTANT INSTR_MUL	: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"02310333";
	CONSTANT INSTR_X7		: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"02A00393";
	CONSTANT INSTR_X8		: STD_LOGIC_VECTOR(31 DOWNTO 0) := x"06300413";

	FUNCTION hex8(v : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN STRING IS
		CONSTANT tbl : STRING := "0123456789ABCDEF";
		VARIABLE r   : STRING(1 TO 8);
		VARIABLE n   : INTEGER;
	BEGIN
		FOR i IN 0 TO 7 LOOP
			n := 0;
			FOR b IN 0 TO 3 LOOP
				IF v(i*4 + b) = '1' THEN n := n + 2**b; END IF;
			END LOOP;
			r(8-i) := tbl(n+1);
		END LOOP;
		RETURN r;
	END FUNCTION;

	FUNCTION udec(v : STD_LOGIC_VECTOR(31 DOWNTO 0)) RETURN INTEGER IS
	BEGIN
		-- test values are small; mask bit31 so CONV_INTEGER cannot overflow
		RETURN CONV_INTEGER('0' & v(30 DOWNTO 0));
	END FUNCTION;

BEGIN

	DUT: RV32I_CORE
	GENERIC MAP(MODELSIM => 1)			-- bypass the PLL so mclk = clk_i
	PORT MAP(
		rst_i => rst, clk_i => clk, divclk_i => divclk,
		pc_o => pc, instruction_o => instruction,
		RegWrite_ctrl_o => RegWrite, MemWrite_ctrl_o => MemWrite,
		Branch_ctrl_o => Branch,
		read_data1_o => rd1, read_data2_o => rd2, write_data_o => wdata,
		alu_res_o => alu_res, brTaken_o => brTaken,
		dtcm_addr_o => dtcm_addr, dtcm_data_wr_o => dtcm_wr,
		dtcm_data_rd_o => dtcm_rd,
		mclk_cnt_o => mclk_cnt
	);

	MCLKGEN: PROCESS
	BEGIN
		WHILE NOT done LOOP
			clk <= '0'; WAIT FOR MCLK_HALF;
			clk <= '1'; WAIT FOR MCLK_HALF;
		END LOOP;
		WAIT;
	END PROCESS;

	DIVCLKGEN: PROCESS
	BEGIN
		WHILE NOT done LOOP
			divclk <= '0'; WAIT FOR DIVCLK_HALF;
			divclk <= '1'; WAIT FOR DIVCLK_HALF;
		END LOOP;
		WAIT;
	END PROCESS;

	STIM: PROCESS
		-- VARIABLES, not signals: they update immediately, so the checks below
		-- see the counts from this same simulation cycle.
		VARIABLE ratio_v		: INTEGER;
		VARIABLE got_divu_v	: INTEGER := -1;
		VARIABLE got_remu_v	: INTEGER := -1;
		VARIABLE got_mul_v	: INTEGER := -1;
		VARIABLE got_x7_v		: INTEGER := -1;
		VARIABLE got_x8_v		: INTEGER := -1;
		VARIABLE divu_hold_v: INTEGER := 0;
		VARIABLE errors_v		: INTEGER := 0;
	BEGIN
		ratio_v := MCLK_HALF / DIVCLK_HALF;
		REPORT "DIVCLK/MCLK ratio = " & INTEGER'IMAGE(ratio_v)
		     & "  (divider needs 32 iterations + CDC latency)" SEVERITY NOTE;

		rst <= '1';
		WAIT FOR 4 * MCLK_HALF;
		rst <= '0';

		FOR c IN 0 TO RUN_CYCLES-1 LOOP
			-- Sample exactly AT the rising edge. In VHDL the values read here are
			-- the pre-edge values, which is precisely what the Register File
			-- latches. Sampling any earlier lets the divider advance a few more
			-- DIVCLK iterations and reports a value the RF never saw.
			WAIT UNTIL rising_edge(clk);

			IF VERBOSE THEN
				REPORT "c" & INTEGER'IMAGE(c)
				     & " pc="       & INTEGER'IMAGE(CONV_INTEGER('0' & pc))
				     & " instr=0x"  & hex8(instruction)
				     & " RegWrite=" & STD_LOGIC'IMAGE(RegWrite)(2)
				     & " wdata="    & INTEGER'IMAGE(udec(wdata))
				SEVERITY NOTE;
			END IF;

			-- capture what each instruction of interest retires with
			IF instruction = INSTR_DIVU THEN
				IF got_divu_v = -1 THEN got_divu_v := udec(wdata); END IF;
				divu_hold_v := divu_hold_v + 1;
			ELSIF instruction = INSTR_REMU AND got_remu_v = -1 THEN
				got_remu_v := udec(wdata);
			ELSIF instruction = INSTR_MUL AND got_mul_v = -1 THEN
				got_mul_v := udec(wdata);
			ELSIF instruction = INSTR_X7 AND got_x7_v = -1 THEN
				got_x7_v := udec(wdata);
			ELSIF instruction = INSTR_X8 AND got_x8_v = -1 THEN
				got_x8_v := udec(wdata);
			END IF;
		END LOOP;

		-------------------------------------------------------------------------
		-- results
		-------------------------------------------------------------------------
		REPORT "---------------- RESULTS ----------------" SEVERITY NOTE;

		IF got_divu_v /= 14 THEN
			REPORT "FAIL divu x4,x2,x3 (100/7): retired with "
			     & INTEGER'IMAGE(got_divu_v) & ", expected 14" SEVERITY WARNING;
			errors_v := errors_v + 1;
		ELSE
			REPORT "pass divu x4,x2,x3 = 14" SEVERITY NOTE;
		END IF;

		IF got_remu_v /= 2 THEN
			REPORT "FAIL remu x5,x2,x3 (100 mod 7): retired with "
			     & INTEGER'IMAGE(got_remu_v) & ", expected 2" SEVERITY WARNING;
			errors_v := errors_v + 1;
		ELSE
			REPORT "pass remu x5,x2,x3 = 2" SEVERITY NOTE;
		END IF;

		IF got_mul_v /= 700 THEN
			REPORT "FAIL mul x6,x2,x3 (100*7): retired with "
			     & INTEGER'IMAGE(got_mul_v) & ", expected 700" SEVERITY WARNING;
			errors_v := errors_v + 1;
		ELSE
			REPORT "pass mul x6,x2,x3 = 700" SEVERITY NOTE;
		END IF;

		-- flow integrity: the instructions AFTER the divides must still run once
		IF got_x7_v /= 42 OR got_x8_v /= 99 THEN
			REPORT "FAIL program flow corrupted after the divides: x7="
			     & INTEGER'IMAGE(got_x7_v) & " (want 42) x8="
			     & INTEGER'IMAGE(got_x8_v) & " (want 99)" SEVERITY WARNING;
			errors_v := errors_v + 1;
		ELSE
			REPORT "pass program flow intact (x7=42, x8=99)" SEVERITY NOTE;
		END IF;

		REPORT "divu occupied " & INTEGER'IMAGE(divu_hold_v)
		     & " MCLK cycle(s) (1 = no stall; >1 = PChold engaged)" SEVERITY NOTE;

		IF errors_v = 0 THEN
			REPORT "=== CORE TEST PASSED at ratio "
			     & INTEGER'IMAGE(ratio_v) & " ===" SEVERITY NOTE;
		ELSE
			REPORT "=== CORE TEST FAILED at ratio " & INTEGER'IMAGE(ratio_v)
			     & ": " & INTEGER'IMAGE(errors_v) & " error(s) ===" SEVERITY WARNING;
		END IF;

		done <= TRUE;
		WAIT;
	END PROCESS;

END test;
