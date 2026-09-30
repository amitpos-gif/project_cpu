
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.const_package.all;


ENTITY WB_MUX IS
	generic(
		PC_WIDTH 		: integer	:= 13;
		DATA_BUS_WIDTH	: integer := 32
	);
	PORT(
		-- ---- From MEM/WB register (the retiring instruction) ----
		alu_res_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- MEM/WB.alu_res_o
		mul_res_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- MEM/WB.mul_res_o (final product)
		mem_data_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- MEM/WB.mem_data_o

		-- ---- WB control bundle (from MEM/WB) ----
		WBSrc_ctrl_i		: IN  STD_LOGIC;	
		MemtoReg_ctrl_i 	: IN 	STD_LOGIC;	

		-- ---- Selected write-back value -> IDECODE.writeback_data_i ----
		writeback_data_o	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END WB_MUX;

ARCHITECTURE behavior OF WB_MUX IS
BEGIN
	writeback_data_o <=	mem_data_i	WHEN (MemtoReg_ctrl_i = '1') ELSE
								alu_res_i		WHEN (WBSrc_ctrl_i = '0') ELSE
								mul_res_i;
END behavior;
