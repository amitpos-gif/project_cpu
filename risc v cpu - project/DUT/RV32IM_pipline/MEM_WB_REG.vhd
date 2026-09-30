
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY MEM_WB_REG IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH				: integer := 13
	);
	PORT(
		--Inputs
		clk_i						: IN	STD_LOGIC;
		rst_i						: IN	STD_LOGIC;

		-- ---- Data from MEMORY (stage 4) ----
		pc_plus4_i					: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		alu_res_i					: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mem_data_i					: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mul_res_i					: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- final MUL result
		rd_i						: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);

		-- ---- WB control bundle (consumed in stage 5) ----
		RegWrite_i				: IN	STD_LOGIC; -- ena to decode of wirting to the register filr and to the fowording unit
		MemtoReg_i				: IN	STD_LOGIC; -- control bit to mun for data from dtcm or not
		RegDst_i				: IN	STD_LOGIC; -- to idecode
		WBSrc_i					: IN	STD_LOGIC; -- to the mux of mul vs alu result

		-- ---- Outputs to WRITEBACK (stage 5) ----
		pc_plus4_o					: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		alu_res_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mem_data_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		mul_res_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		rd_o					: OUT	STD_LOGIC_VECTOR(4 DOWNTO 0);

		RegWrite_o				: OUT	STD_LOGIC;
		MemtoReg_o				: OUT	STD_LOGIC;
		RegDst_o				: OUT	STD_LOGIC;
		WBSrc_o					: OUT	STD_LOGIC
	);
END MEM_WB_REG;


ARCHITECTURE behavior OF MEM_WB_REG IS

	SIGNAL pc_plus4_q						: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL alu_res_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_data_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mul_res_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL rd_q						: STD_LOGIC_VECTOR(4 DOWNTO 0);

	SIGNAL RegWrite_q			: STD_LOGIC;
	SIGNAL MemtoReg_q			: STD_LOGIC;
	SIGNAL RegDst_q				: STD_LOGIC;
	SIGNAL WBSrc_q				: STD_LOGIC;

BEGIN
	--------------------------------------------------------------------------
	-- Synchronous register, synchronous reset only. No flush, no stall --
	-- every cycle, whatever MEMORY produced is latched unconditionally.
	--------------------------------------------------------------------------
	PROCESS(clk_i)
	BEGIN
		IF (clk_i'EVENT AND clk_i = '1') THEN
			IF (rst_i = '1') THEN
				pc_plus4_q				<= (OTHERS => '0');
				alu_res_q				<= (OTHERS => '0');
				mem_data_q				<= (OTHERS => '0');
				mul_res_q				<= (OTHERS => '0');
				rd_q					<= (OTHERS => '0');

				RegWrite_q				<= '0';
				MemtoReg_q				<= '0';
				RegDst_q				<= '0';
				WBSrc_q					<= '0';

			ELSE
				pc_plus4_q				<= pc_plus4_i;
				alu_res_q				<= alu_res_i;
				mem_data_q				<= mem_data_i;
				mul_res_q				<= mul_res_i;
				rd_q					<= rd_i;

				RegWrite_q				<= RegWrite_i;
				MemtoReg_q				<= MemtoReg_i;
				RegDst_q				<= RegDst_i;
				WBSrc_q					<= WBSrc_i;
			END IF;
		END IF;
	END PROCESS;

	-- Data outputs
	pc_plus4_o					<= pc_plus4_q;
	alu_res_o					<= alu_res_q;
	mem_data_o					<= mem_data_q;
	mul_res_o					<= mul_res_q;
	rd_o						<= rd_q;

	-- WB bundle outputs
	RegWrite_o				<= RegWrite_q;
	MemtoReg_o				<= MemtoReg_q;
	RegDst_o				<= RegDst_q;
	WBSrc_o					<= WBSrc_q;

END behavior;