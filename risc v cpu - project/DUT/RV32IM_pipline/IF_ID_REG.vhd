--============================================================================
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY IF_ID_REG IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH				: integer := 13
	);
	PORT(
		--Inputs
		clk_i						: IN	STD_LOGIC;
		rst_i						: IN	STD_LOGIC;

		-- Stall Condition Unit control (Figure 7, red box outputs)
		ena_i						: IN	STD_LOGIC;	-- '0' = hold (stall), '1' = latch normally
		flush_i						: IN	STD_LOGIC;	-- '1' = force NOP (branch/jump taken in stage 4)

		-- Data from IFETCH (stage 1)
		pc_plus4_i					: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- PC+4 (link value for JAL/JALR)
		pc_i						: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_i				: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		--Outputs to IDECODE (stage 2)
		pc_plus4_o					: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- PC+4 (link value for JAL/JALR)
		pc_o						: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END IF_ID_REG;


ARCHITECTURE behavior OF IF_ID_REG IS

	-- NOP encoding: ADDI x0, x0, 0  (opcode=0010011, funct3=000, rd=rs1=0, imm=0)
	-- Safe to insert anywhere in the pipeline: writes x0 (hardwired discard),
	-- reads no meaningful operands, triggers no memory access, no branch.
	CONSTANT NOP_INSTRUCTION : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000013";

	SIGNAL pc_q						: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_q				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL instruction_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN
	--------------------------------------------------------------------------
	-- Synchronous register with synchronous reset, flush, and stall (hold)
	--------------------------------------------------------------------------
	PROCESS(clk_i)
	BEGIN
		IF (clk_i'EVENT AND clk_i = '1') THEN
			IF (rst_i = '1') THEN
				pc_q					<= (OTHERS => '0');
				pc_plus4_q			<= (OTHERS => '0');
				instruction_q	<= NOP_INSTRUCTION;

			ELSIF (flush_i = '1') THEN
				-- Branch/jump taken in stage 4: squash whatever was fetched
				-- on the (now known to be wrong) sequential path.
				pc_q					<= (OTHERS => '0');
				pc_plus4_q			<= (OTHERS => '0');
				instruction_q	<= NOP_INSTRUCTION;

			ELSIF (ena_i = '1') THEN
				-- Normal operation: latch newly fetched instruction
				pc_q					<= pc_i;
				pc_plus4_q			<= pc_plus4_i;
				instruction_q	<= instruction_i;

			-- ELSE (ena_i = '0'): hold -- do nothing, pc_q/instruction_q
			-- retain their values automatically (no assignment = no change)
			END IF;
		END IF;
	END PROCESS;

	pc_o					<= pc_q;
	instruction_o	<= instruction_q;
	pc_plus4_o			<= pc_plus4_q;

END behavior;