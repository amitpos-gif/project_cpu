
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY FLUSH_UNIT IS
	PORT(
		-- Registered EX/MEM redirect signals
		br_or_jump_taken_i		: IN	STD_LOGIC;	-- EX_MEM_REG.Branch_o  
		Jalr_i			: IN	STD_LOGIC;	-- EX_MEM_REG.Jalr_o
		flush_o			: OUT	STD_LOGIC
	);
END FLUSH_UNIT;


ARCHITECTURE behavior OF FLUSH_UNIT IS
BEGIN

	-- (Branch AND brTaken) OR Jal OR Jalr  -- the gate the figure draws here
	flush_o <= (br_or_jump_taken_i) OR Jalr_i;

END behavior;
