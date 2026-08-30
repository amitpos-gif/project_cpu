--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU Architecture and Hardware Accelerators Lab 361-1-4693 BGU
--
-- Unsigned restoring integer divider based on Figure 9.
-- DIVRST initializes the divider core and loads both operands in parallel.
-- One quotient bit is calculated on every enabled rising edge of DIVCLK.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;


ENTITY divider_accelerator IS
	GENERIC(
		DATA_BUS_WIDTH	: POSITIVE := 32;
		N					: POSITIVE := 32
	);
	PORT(
		-- Inputs
		ain_i			: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- dividend
		bin_i			: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- divisor
		divclk_i		: IN  STD_LOGIC;									-- CLK from the clock tree
		divrst_i		: IN  STD_LOGIC;									-- reset signal (arms the start of a new divide)
		divena_i		: IN  STD_LOGIC;									-- enable signal (starts the N-step divide operation)													

		-- Outputs
		quotient_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- RESULT: quotient
		rem_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- RESULT: remainder
		divbusy_o		: OUT STD_LOGIC										-- indication that we are still busy with the current divide operation
	);
END divider_accelerator;


ARCHITECTURE behavior OF divider_accelerator IS
	CONSTANT DOUBLE_WIDTH_C	: POSITIVE := 2 * DATA_BUS_WIDTH;   -- constant for the 64 bit load register

	-- Upper half: partial remainder. Lower half: shifting dividend.
	SIGNAL dividend_q	: STD_LOGIC_VECTOR(DOUBLE_WIDTH_C-1 DOWNTO 0);  -- the 64 bit load register  [numers - 32bit | dividend - 32bit]
	SIGNAL divisor_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- the divisor register
	SIGNAL quotient_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- the quotient register
	SIGNAL count_q		: NATURAL RANGE 0 TO N-1;						-- the iteration counter
	SIGNAL busy_q		: STD_LOGIC;									-- the busy signal

	-- DIVRST arms exactly one start. This prevents a level-held DIVENA from
	-- restarting the completed divide before BUSY reaches MCLK.
	SIGNAL armed_q		: STD_LOGIC;

BEGIN
	
	PROCESS(divclk_i)
		VARIABLE shifted_v	: STD_LOGIC_VECTOR(DOUBLE_WIDTH_C-1 DOWNTO 0);	-- the shifted dividend register
		VARIABLE upper_v	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- the upper half of the shifted dividend register
		VARIABLE quotient_v	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- the shifted quotient register
	BEGIN
		IF rising_edge(divclk_i) THEN
			IF divrst_i = '1' THEN
				-- DIVRST initializes the core while loading the gray interface
				-- registers: upper dividend=0, lower dividend=ain, divisor=bin.
				dividend_q	<= (DATA_BUS_WIDTH-1 DOWNTO 0 => '0') & ain_i;  -- this is the 64 bit load register
				divisor_q		<= bin_i;
				quotient_q	<= (OTHERS => '0');
				count_q			<= 0;
				busy_q			<= '0';
				armed_q			<= '1';

			ELSIF busy_q = '0' THEN
				IF divena_i = '1' AND armed_q = '1' THEN
					-- Operands were loaded by DIVRST. DIVENA starts the N steps.
					count_q			<= 0;
					busy_q			<= '1';
					armed_q			<= '0';
				END IF;

			ELSE
				-- Step 2: shift the combined dividend register left.
				shifted_v := dividend_q(DOUBLE_WIDTH_C-2 DOWNTO 0) & '0';
				upper_v := shifted_v(DOUBLE_WIDTH_C-1 DOWNTO DATA_BUS_WIDTH);
				quotient_v := quotient_q(DATA_BUS_WIDTH-2 DOWNTO 0) & '0';

				-- Step 3: subtract/test and append the quotient bit.
				IF upper_v >= divisor_q THEN  -- so we have a valid subtraction
					upper_v := upper_v - divisor_q;  -- it is the actual subtraction
					shifted_v(DOUBLE_WIDTH_C-1 DOWNTO DATA_BUS_WIDTH) := upper_v;
					quotient_v(0) := '1';
				END IF;

				dividend_q	<= shifted_v;
				quotient_q	<= quotient_v;

				-- Step 4: exactly N iterations.
				IF count_q = N-1 THEN
					count_q	<= 0;
					busy_q	<= '0';
				ELSE
					count_q	<= count_q + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- Step 5: quotient and remainder outputs hold until the next operation.
	quotient_o	<= quotient_q;
	rem_o			<= dividend_q(DOUBLE_WIDTH_C-1 DOWNTO DATA_BUS_WIDTH);
	divbusy_o	<= busy_q;

END behavior;
