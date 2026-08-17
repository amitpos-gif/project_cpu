--============================================================================
-- RV32I_CORE running the test1 benchmark (test1/man_compiled).
--
--   for i in 0..7:
--     res1[i] = arr1[i] / arr2[i]     <- div  (SIGNED)
--     res2[i] = arr1[i] * arr2[i]     <- mul
--     res3[i] = arr1[i] % arr2[i]     <- rem  (SIGNED)
--
-- arr1 = 1,2,3,4,5,6,7,8   arr2 = 8,7,6,5,4,3,2,1
--
-- DTCM word layout (from test1/man_compiled/output/RARS/DTCM.h):
--   words  0..7  arr1
--   words  8..15 arr2
--   words 16..23 res1  expected 0,0,0,0,1,2,3,8
--   words 24..31 res2  expected 8,14,18,20,20,18,14,8
--   words 32..39 res3  expected 1,2,3,4,1,0,1,0
--
-- Rather than peek inside altsyncram, this testbench snoops every DTCM store
-- (MemWrite asserted at an MCLK edge) and rebuilds the memory image from the
-- address/data buses. That is independent of the memory model internals.
--
-- HOW TO RUN
--   Point IFETCH.VHD init_file at test1/man_compiled/bin/M9K-intel/ITCM.hex
--   and DMEMORY.VHD init_file at test1/man_compiled/bin/M9K-intel/DTCM.hex,
--   then:
--     vsim -c -L altera_mf -voptargs=+acc tb_test1 -do "run -all; quit -f"
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.all;

ENTITY tb_test1 IS
	GENERIC(
		MCLK_HALF		: TIME		:= 250 ns;
		DIVCLK_HALF	: TIME		:= 5 ns;		-- ratio 50
		RUN_CYCLES	: INTEGER	:= 600;
		VERBOSE			: BOOLEAN	:= FALSE
	);
END tb_test1;

ARCHITECTURE test OF tb_test1 IS

	CONSTANT SIZE : INTEGER := 8;
	TYPE int_arr IS ARRAY (0 TO SIZE-1) OF INTEGER;

	-- golden results, straight from the RARS reference DTCM dump
	CONSTANT EXP_RES1 : int_arr := (0, 0, 0, 0, 1, 2, 3, 8);				-- division
	CONSTANT EXP_RES2 : int_arr := (8, 14, 18, 20, 20, 18, 14, 8);	-- multiply
	CONSTANT EXP_RES3 : int_arr := (1, 2, 3, 4, 1, 0, 1, 0);				-- remainder

	CONSTANT RES1_BASE : INTEGER := 16;		-- DTCM word index
	CONSTANT RES2_BASE : INTEGER := 24;
	CONSTANT RES3_BASE : INTEGER := 32;

	SIGNAL clk, divclk, rst	: STD_LOGIC := '0';
	SIGNAL pc								: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL instruction			: STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL RegWrite, MemWrite, Branch, brTaken	: STD_LOGIC;
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
		TYPE mem_arr  IS ARRAY (0 TO 63) OF STD_LOGIC_VECTOR(31 DOWNTO 0);
		TYPE seen_arr IS ARRAY (0 TO 63) OF BOOLEAN;
		VARIABLE mem_v		: mem_arr  := (OTHERS => (OTHERS => '0'));
		VARIABLE seen_v		: seen_arr := (OTHERS => FALSE);
		VARIABLE stores_v	: INTEGER := 0;
		VARIABLE addr_v		: INTEGER;
		VARIABLE errors_v	: INTEGER := 0;
		VARIABLE ratio_v	: INTEGER;

		PROCEDURE check_arr(name : STRING; base : INTEGER; exp : int_arr;
		                    errors : INOUT INTEGER;
		                    mem : IN mem_arr; seen : IN seen_arr) IS
			VARIABLE bad_v : INTEGER := 0;
			VARIABLE line_v : STRING(1 TO 8);
		BEGIN
			FOR i IN 0 TO SIZE-1 LOOP
				IF NOT seen(base + i) THEN
					REPORT "  " & name & "[" & INTEGER'IMAGE(i) & "] NEVER WRITTEN"
					SEVERITY WARNING;
					bad_v := bad_v + 1;
				ELSIF CONV_INTEGER(SIGNED(mem(base + i))) /= exp(i) THEN
					REPORT "  " & name & "[" & INTEGER'IMAGE(i) & "] = 0x"
					     & hex8(mem(base + i)) & "  expected "
					     & INTEGER'IMAGE(exp(i)) SEVERITY WARNING;
					bad_v := bad_v + 1;
				END IF;
			END LOOP;
			IF bad_v = 0 THEN
				REPORT "pass  " & name & " all " & INTEGER'IMAGE(SIZE)
				     & " elements correct" SEVERITY NOTE;
			ELSE
				REPORT "FAIL  " & name & ": " & INTEGER'IMAGE(bad_v) & " of "
				     & INTEGER'IMAGE(SIZE) & " wrong" SEVERITY WARNING;
				errors := errors + 1;
			END IF;
		END PROCEDURE;
	BEGIN
		ratio_v := MCLK_HALF / DIVCLK_HALF;
		REPORT "test1 benchmark, DIVCLK/MCLK ratio = "
		     & INTEGER'IMAGE(ratio_v) SEVERITY NOTE;

		rst <= '1';
		WAIT FOR 4 * MCLK_HALF;
		rst <= '0';

		FOR c IN 0 TO RUN_CYCLES-1 LOOP
			-- sample AT the edge: pre-edge values are what the DTCM latches
			WAIT UNTIL rising_edge(clk);

			IF MemWrite = '1' THEN
				addr_v := CONV_INTEGER('0' & dtcm_addr);
				IF addr_v <= 63 THEN
					mem_v(addr_v)  := dtcm_wr;
					seen_v(addr_v) := TRUE;
				END IF;
				stores_v := stores_v + 1;
				IF VERBOSE THEN
					REPORT "store #" & INTEGER'IMAGE(stores_v)
					     & " word " & INTEGER'IMAGE(addr_v)
					     & " <= 0x" & hex8(dtcm_wr) SEVERITY NOTE;
				END IF;
			END IF;
		END LOOP;

		-------------------------------------------------------------------------
		REPORT "------------------- test1 RESULTS -------------------" SEVERITY NOTE;
		REPORT "DTCM stores observed = " & INTEGER'IMAGE(stores_v)
		     & "  (expect 24: 8 iterations x 3 arrays)" SEVERITY NOTE;

		check_arr("res1 = arr1/arr2 (div)", RES1_BASE, EXP_RES1, errors_v, mem_v, seen_v);
		check_arr("res2 = arr1*arr2 (mul)", RES2_BASE, EXP_RES2, errors_v, mem_v, seen_v);
		check_arr("res3 = arr1%arr2 (rem)", RES3_BASE, EXP_RES3, errors_v, mem_v, seen_v);

		IF errors_v = 0 THEN
			REPORT "=== test1 PASSED ===" SEVERITY NOTE;
		ELSE
			REPORT "=== test1 FAILED: " & INTEGER'IMAGE(errors_v)
			     & " of 3 arrays wrong ===" SEVERITY WARNING;
		END IF;

		done <= TRUE;
		WAIT;
	END PROCESS;

END test;
