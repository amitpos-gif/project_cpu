
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.all;                 -- rv32i_core_pipline COMPONENT lives here
USE work.cond_compilation_package.all;    -- G_* configuration constants

ENTITY PIPLINE_USER_INTERFACE IS
	generic(
		WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
		MODELSIM 					: integer 	:= G_MODELSIM;
		DATA_BUS_WIDTH 		: integer 	:= 32;
		ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
		DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
		PC_WIDTH 					: integer 	:= G_PC_WIDTH;
		MA_WIDTH 					: integer 	:= G_MA_WIDTH;
		DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
		CLK_CNT_WIDTH 		: integer 	:= 16
	);
	PORT(
		--------------------------------------------------------------------
		-- Physical board pins (names MUST match the .qsf)
		--------------------------------------------------------------------
		CLOCK_50 : IN  STD_LOGIC;                       -- 50 MHz oscillator
		KEY      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);    -- push-buttons, ACTIVE-LOW
		SW       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0)     -- slide switches
		-- No output pins: all Figure-8 taps are observed via SignalTap.
	);
END PIPLINE_USER_INTERFACE;


ARCHITECTURE structure OF PIPLINE_USER_INTERFACE IS

	--------------------------------------------------------------------
	-- Board-pin adaptation
	--------------------------------------------------------------------
	SIGNAL rst_w     : STD_LOGIC;                       -- active-high core reset
	SIGNAL bpaddr_w  : STD_LOGIC_VECTOR(7 DOWNTO 0);    -- 8-bit breakpoint addr

	--------------------------------------------------------------------
	-- Figure-8 tap signals (internal observation nodes for SignalTap).
	-- Widths use the generics (DATA_BUS_WIDTH / PC_WIDTH) directly.
	--------------------------------------------------------------------
	SIGNAL clkcnt_w         : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL ifpc_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ifinstruction_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL idpc_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL idinstruction_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL expc_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL exinstruction_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mempc_w          : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL meminstruction_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wbpc_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL wbinstruction_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL strigger_w       : STD_LOGIC;
	SIGNAL fhcnt_w          : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL stcnt_w          : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

	--========================================================================
	-- Board-pin adaptation logic
	--========================================================================
	rst_w    <= NOT KEY(0);          -- active-low button -> active-high reset
	bpaddr_w <= SW(7 DOWNTO 0);      -- Figure 8: SW[7]-SW[0] -> BPADDR_i

	--========================================================================
	-- The logical core (Figure-8 entity). Generics passed through explicitly.
	--========================================================================
	CORE : rv32i_core_pipline
		generic map(
			WORD_GRANULARITY => WORD_GRANULARITY,
			MODELSIM         => MODELSIM,
			DATA_BUS_WIDTH   => DATA_BUS_WIDTH,
			ITCM_ADDR_WIDTH  => ITCM_ADDR_WIDTH,
			DTCM_ADDR_WIDTH  => DTCM_ADDR_WIDTH,
			PC_WIDTH         => PC_WIDTH,
			MA_WIDTH         => MA_WIDTH,
			DATA_WORDS_NUM   => DATA_WORDS_NUM,
			CLK_CNT_WIDTH    => CLK_CNT_WIDTH
		)
		PORT MAP (
			-- inputs
			clk_i            => CLOCK_50,
			rst_i            => rst_w,
			BPADDR_i         => bpaddr_w,
			-- outputs (landed on internal nodes for SignalTap observation)
			CLKCNT_o         => clkcnt_w,
			IFpc_o           => ifpc_w,
			IFinstruction_o  => ifinstruction_w,
			IDpc_o           => idpc_w,
			IDinstruction_o  => idinstruction_w,
			EXpc_o           => expc_w,
			EXinstruction_o  => exinstruction_w,
			MEMpc_o          => mempc_w,
			MEMinstruction_o => meminstruction_w,
			WBpc_o           => wbpc_w,
			WBinstruction_o  => wbinstruction_w,
			STRIGGER_o       => strigger_w,
			FHCNT_o          => fhcnt_w,
			STCNT_o          => stcnt_w
		);

END structure;
