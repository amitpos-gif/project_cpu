--============================================================================
-- RV32I_CORE divider test: the six required cases.
--
--   Normal DIVU              divu x4,x2,x3      100/7   -> 14
--   Normal REMU              remu x5,x2,x3      100%7   -> 2
--   Division by zero         divu x6,x2,x0      100/0   -> 0xFFFFFFFF
--                            remu x7,x2,x0      100%0   -> 100
--   Zero divided by a number divu x8,x0,x3        0/7   -> 0
--                            remu x9,x0,x3        0%7   -> 0
--   Division by one          divu x10,x2,x1     100/1   -> 100
--                            remu x11,x2,x1     100%1   -> 0
--   Consecutive divides      divu x12,x20,x21   255/16  -> 15
--                            remu x13,x20,x21   255%16  -> 15
--                            divu x14,x2,x3     100/7   -> 14
--                            remu x15,x20,x3    255%7   -> 3
--
-- All twelve divides are back-to-back in the program, so the consecutive case
-- is exercised continuously, not just by the four instructions labelled so.
--
-- Divide-by-zero expectations follow the RISC-V unsigned spec: divu returns
-- all ones, remu returns the dividend.
--
-- Each instruction is identified by its encoding and checked against the
-- expected value at its retire edge (the pre-edge value, which is exactly what
-- the Register File latches). The final Register File is also dumped by the
-- caller for independent confirmation.
--
-- HOW TO RUN
--   Point the init_file generics of IFETCH.VHD / DMEMORY.VHD at
--   ITCM_div.mif / DTCM_div.mif (shipped beside this file), then:
--
--   vsim -c -L altera_mf -voptargs=+acc tb_core_div_cases \
--        -do "run -all; quit -f"
--
--   DIVCLK_HALF / MCLK_HALF are generics: the divider needs 32 DIVCLK
--   iterations plus CDC latency, so the ratio decides whether a divide can
--   finish. Sweep it with -gMCLK_HALF=... -gDIVCLK_HALF=...
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.all;

ENTITY tb_core_div_cases IS
	GENERIC(
		MCLK_HALF		: TIME		:= 500 ns;
		DIVCLK_HALF	: TIME		:= 5 ns;
		RUN_CYCLES	: INTEGER	:= 40;
		VERBOSE			: BOOLEAN	:= FALSE
	);
END tb_core_div_cases;

ARCHITECTURE test OF tb_core_div_cases IS

	CONSTANT N_CASES : INTEGER := 12;
	TYPE enc_arr  IS ARRAY (0 TO N_CASES-1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
	TYPE name_arr IS ARRAY (0 TO N_CASES-1) OF STRING(1 TO 25);

	CONSTANT CASE_ENC : enc_arr := (
		x"02315233",
		x"023172B3",
		x"02015333",
		x"020173B3",
		x"02305433",
		x"023074B3",
		x"02115533",
		x"021175B3",
		x"035A5633",
		x"035A76B3",
		x"02315733",
		x"023A77B3"
	);
	CONSTANT CASE_EXP : enc_arr := (
		x"0000000E",
		x"00000002",
		x"FFFFFFFF",
		x"00000064",
		x"00000000",
		x"00000000",
		x"00000064",
		x"00000000",
		x"0000000F",
		x"0000000F",
		x"0000000E",
		x"00000003"
	);
	CONSTANT CASE_NAME : name_arr := (
		"Normal DIVU        100/7 ",
		"Normal REMU        100%7 ",
		"DIVU by zero       100/0 ",
		"REMU by zero       100%0 ",
		"Zero DIVU number     0/7 ",
		"Zero REMU number     0%7 ",
		"DIVU by one        100/1 ",
		"REMU by one        100%1 ",
		"Consecutive #1     255/16",
		"Consecutive #2     255%16",
		"Consecutive #3     100/7 ",
		"Consecutive #4     255%7 "
	);

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
		-- variables update immediately, so the summary sees this cycle's counts
		TYPE seen_arr IS ARRAY (0 TO N_CASES-1) OF BOOLEAN;
		TYPE got_arr  IS ARRAY (0 TO N_CASES-1) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
		VARIABLE seen_v		: seen_arr := (OTHERS => FALSE);
		VARIABLE got_v		: got_arr  := (OTHERS => (OTHERS => '0'));
		VARIABLE holds_v	: INTEGER  := 0;
		VARIABLE ratio_v	: INTEGER;
		VARIABLE errors_v	: INTEGER  := 0;
		VARIABLE missing_v: INTEGER  := 0;
	BEGIN
		ratio_v := MCLK_HALF / DIVCLK_HALF;
		REPORT "DIVCLK/MCLK ratio = " & INTEGER'IMAGE(ratio_v) SEVERITY NOTE;

		rst <= '1';
		WAIT FOR 4 * MCLK_HALF;
		rst <= '0';

		FOR c IN 0 TO RUN_CYCLES-1 LOOP
			-- Sample AT the edge: these are the pre-edge values, i.e. exactly
			-- what the Register File latches for the instruction in decode.
			WAIT UNTIL rising_edge(clk);

			IF VERBOSE THEN
				REPORT "c" & INTEGER'IMAGE(c)
				     & " pc="      & INTEGER'IMAGE(CONV_INTEGER('0' & pc))
				     & " instr=0x" & hex8(instruction)
				     & " RegWr="   & STD_LOGIC'IMAGE(RegWrite)(2)
				     & " wdata=0x" & hex8(wdata) SEVERITY NOTE;
			END IF;

			FOR k IN 0 TO N_CASES-1 LOOP
				IF instruction = CASE_ENC(k) THEN
					-- Qualify on RegWrite: when the divide is stalled the core holds
					-- the instruction in decode for many cycles with RegWrite forced
					-- low, and write_data is still mid-iteration garbage. Only the
					-- cycle that actually writes the Register File counts.
					IF RegWrite = '1' AND NOT seen_v(k) THEN
						seen_v(k) := TRUE;
						got_v(k)  := wdata;
					ELSIF RegWrite = '0' THEN
						-- divide held in decode, result not yet valid
						holds_v := holds_v + 1;
					END IF;
				END IF;
			END LOOP;
		END LOOP;

		-------------------------------------------------------------------------
		REPORT "------------------- RESULTS -------------------" SEVERITY NOTE;
		FOR k IN 0 TO N_CASES-1 LOOP
			IF NOT seen_v(k) THEN
				REPORT "NOT REACHED  " & CASE_NAME(k)
				     & "  (increase RUN_CYCLES)" SEVERITY WARNING;
				missing_v := missing_v + 1;
			ELSIF got_v(k) = CASE_EXP(k) THEN
				REPORT "pass  " & CASE_NAME(k) & "  = 0x" & hex8(got_v(k))
				SEVERITY NOTE;
			ELSE
				REPORT "FAIL  " & CASE_NAME(k)
				     & "  got 0x" & hex8(got_v(k))
				     & "  want 0x" & hex8(CASE_EXP(k)) SEVERITY WARNING;
				errors_v := errors_v + 1;
			END IF;
		END LOOP;

		REPORT "extra held divide cycles = " & INTEGER'IMAGE(holds_v)
		     & "  (0 => PChold never held a divide)" SEVERITY NOTE;

		IF errors_v = 0 AND missing_v = 0 THEN
			REPORT "=== ALL 12 DIVIDER CASES PASSED at ratio "
			     & INTEGER'IMAGE(ratio_v) & " ===" SEVERITY NOTE;
		ELSE
			REPORT "=== DIVIDER CASES FAILED at ratio " & INTEGER'IMAGE(ratio_v)
			     & ": " & INTEGER'IMAGE(errors_v) & " wrong, "
			     & INTEGER'IMAGE(missing_v) & " not reached ===" SEVERITY WARNING;
		END IF;

		done <= TRUE;
		WAIT;
	END PROCESS;

END test;
