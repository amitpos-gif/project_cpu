--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU Architecture and Hardware Accelerators Lab 361-1-4693 BGU
--
-- Operand clock-domain synchronizer based on Figure 10b.
-- The operands cross from the low-frequency CPU domain into DIVCLK.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;


ENTITY sync IS
	GENERIC(
		DATA_BUS_WIDTH	: POSITIVE := 32
	);
	PORT(
		-- Inputs from the CPU/MCLK domain
		read_data1_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- data from the CPU/MCLK domain
		read_data2_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- data from the CPU/MCLK domain
		divclk_i		: IN  STD_LOGIC;									-- divider clock (DIVCLK) from the clock tree
		rst_i			: IN  STD_LOGIC;									-- reset signal

		-- Stable outputs in the DIVCLK domain
		ain_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		bin_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END sync;


ARCHITECTURE behavior OF sync IS
	-- First DFF stage: may enter a metastable state after an asynchronous change.
	SIGNAL read_data1_meta_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- read_data1_i after the first DFF stage
	SIGNAL read_data2_meta_q	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- read_data2_i after the first DFF stage

	-- Second DFF stage: stable values used by the divider.
	SIGNAL ain_sync_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); 	-- read_data1_meta_q after the second DFF stage
	SIGNAL bin_sync_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- read_data2_meta_q after the second DFF stage

BEGIN
	PROCESS(divclk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			read_data1_meta_q	<= (OTHERS => '0'); -- reset the first DFF stage
			read_data2_meta_q	<= (OTHERS => '0'); -- reset the first DFF stage
			ain_sync_q			<= (OTHERS => '0'); -- reset the second DFF stage
			bin_sync_q			<= (OTHERS => '0'); -- reset the second DFF stage

		ELSIF rising_edge(divclk_i) THEN
			-- First pair of DFFs 
			read_data1_meta_q	<= read_data1_i;
			read_data2_meta_q	<= read_data2_i;

			-- Second pair of DFFs 
			ain_sync_q			<= read_data1_meta_q;
			bin_sync_q			<= read_data2_meta_q;
		END IF;
	END PROCESS;

	ain_o <= ain_sync_q;
	bin_o <= bin_sync_q;

END behavior;