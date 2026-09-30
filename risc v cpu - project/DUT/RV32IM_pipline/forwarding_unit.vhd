
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY FORWARDING_UNIT IS
	PORT(
		-- ---- Source registers of the instruction currently in EXECUTE ----
		ID_EX_rs1_i			: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);	-- ID/EX.rs1_o
		ID_EX_rs2_i			: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);	-- ID/EX.rs2_o

		-- ---- In-flight producer in EX/MEM (one instruction ahead) ----
		EX_MEM_rd_i			: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);	-- EX/MEM.rd_o
		EX_MEM_RegWrite_i	: IN	STD_LOGIC;										-- EX/MEM.RegWrite_o

		-- ---- In-flight producer in MEM/WB (two instructions ahead) ----
		MEM_WB_rd_i			: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);	-- MEM/WB.rd_o
		MEM_WB_RegWrite_i	: IN	STD_LOGIC;										-- MEM/WB.RegWrite_o

		-- ---- Forwarding selects -> EXECUTE ----
		Forward_Ain_o		: OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);	-- for ALU operand A (rs1)
		Forward_Bin_o		: OUT	STD_LOGIC_VECTOR(1 DOWNTO 0)	-- for ALU operand B (rs2)
	);
END FORWARDING_UNIT;


ARCHITECTURE behavior OF FORWARDING_UNIT IS

	CONSTANT X0 : STD_LOGIC_VECTOR(4 DOWNTO 0) := "00000";

	-- Per-source "is a valid forwarding producer" predicates
	SIGNAL ex_mem_valid_w	: STD_LOGIC;	-- EX/MEM writes a real, non-x0 register
	SIGNAL mem_wb_valid_w	: STD_LOGIC;	-- MEM/WB writes a real, non-x0 register

BEGIN
	-- A stage is a valid forwarding source only if it will really write a
	-- non-x0 destination. Computed once, reused for both operands.
	ex_mem_valid_w <= EX_MEM_RegWrite_i  WHEN (EX_MEM_rd_i /= X0) ELSE '0';
	mem_wb_valid_w <= MEM_WB_RegWrite_i  WHEN (MEM_WB_rd_i /= X0) ELSE '0';

	--------------------------------------------------------------------------
	-- Operand A (rs1): EX/MEM has priority over MEM/WB (younger wins).
	--------------------------------------------------------------------------
	Forward_Ain_o <=	"10"	WHEN (ex_mem_valid_w = '1' AND EX_MEM_rd_i = ID_EX_rs1_i) ELSE
							"01"	WHEN (mem_wb_valid_w = '1' AND MEM_WB_rd_i = ID_EX_rs1_i) ELSE
							"00";

	--------------------------------------------------------------------------
	-- Operand B (rs2): same structure, independently evaluated.
	--------------------------------------------------------------------------
	Forward_Bin_o <=	"10"	WHEN (ex_mem_valid_w = '1' AND EX_MEM_rd_i = ID_EX_rs2_i) ELSE
							"01"	WHEN (mem_wb_valid_w = '1' AND MEM_WB_rd_i = ID_EX_rs2_i) ELSE
							"00";

END behavior;
