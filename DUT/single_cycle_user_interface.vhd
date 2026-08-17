--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- USER_INTERFICE module - Top-level FPGA entity
-- Exposes board-level pins (SW[0] reset, 50MHz clock) and instantiates the
-- RV32I_CORE single-cycle RISC-V core underneath (see Figure 4)
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE work.cond_compilation_package.all;
USE work.aux_package.all;


ENTITY single_cycle_user_interface IS
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
		--Inputs (board-level pins, see Figure 4)
		SW_0_i						: IN	STD_LOGIC;				-- SW[0]  -> rst_i
		clk_50MHz_i				: IN	STD_LOGIC;				-- 50MHz  -> clk_i

		--Outputs (forwarded Signal-Tap auxiliary pins from RV32I_CORE)
		pc_o							: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		RegWrite_ctrl_o		: OUT	STD_LOGIC;
		MemWrite_ctrl_o		: OUT	STD_LOGIC;
		Branch_ctrl_o			: OUT	STD_LOGIC;

		read_data1_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		write_data_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		alu_res_o					: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		brTaken_o					: OUT	STD_LOGIC;

		dtcm_addr_o				: OUT	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		mclk_cnt_o				: OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0)
	);
END single_cycle_user_interface;


ARCHITECTURE structure OF single_cycle_user_interface IS

BEGIN
	--=======================================
	-- RV32I_CORE instantiation
	-- SW_0_i drives rst_i, clk_50MHz_i drives clk_i (PLL/MCLK handled inside the core)
	--=======================================
	CORE: RV32I_CORE
	generic map(
		WORD_GRANULARITY	=> WORD_GRANULARITY,
		MODELSIM					=> MODELSIM,
		DATA_BUS_WIDTH		=> DATA_BUS_WIDTH,
		ITCM_ADDR_WIDTH		=> ITCM_ADDR_WIDTH,
		DTCM_ADDR_WIDTH		=> DTCM_ADDR_WIDTH,
		PC_WIDTH					=> PC_WIDTH,
		MA_WIDTH					=> MA_WIDTH,
		DATA_WORDS_NUM		=> DATA_WORDS_NUM,
		CLK_CNT_WIDTH			=> CLK_CNT_WIDTH
	)
	PORT MAP(
		--Inputs
		rst_i							=> SW_0_i,
		clk_i							=> clk_50MHz_i,

		--Outputs
		pc_o							=> pc_o,
		instruction_o			=> instruction_o,

		RegWrite_ctrl_o		=> RegWrite_ctrl_o,
		MemWrite_ctrl_o		=> MemWrite_ctrl_o,
		Branch_ctrl_o			=> Branch_ctrl_o,

		read_data1_o			=> read_data1_o,
		read_data2_o			=> read_data2_o,
		write_data_o			=> write_data_o,

		alu_res_o					=> alu_res_o,
		brTaken_o					=> brTaken_o,

		dtcm_addr_o				=> dtcm_addr_o,
		dtcm_data_wr_o		=> dtcm_data_wr_o,
		dtcm_data_rd_o		=> dtcm_data_rd_o,

		mclk_cnt_o				=> mclk_cnt_o
	);

END structure;
