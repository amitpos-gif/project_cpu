
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY Ifetch IS
	generic(
		WORD_GRANULARITY 	: boolean	:= False;
		DATA_BUS_WIDTH 		: integer	:= 32; 
		PC_WIDTH 			: integer	:= 10;
		ITCM_ADDR_WIDTH 	: integer	:= 8;
		WORDS_NUM 				: integer	:= 256
	);
	PORT(
		--Inputs
		clk_i			: IN 	STD_LOGIC; 
		rst_i 			: IN 	STD_LOGIC;
		ena_i			: IN 	STD_LOGIC;	-- PCwrite from Stall Condition Unit; '0' = hold

		addr_gen_i 			: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- branch target, from EX_MEM_REG (registered)
        br_or_jump_taken_i	: IN 	STD_LOGIC;   -- "this is a branch instruction", carried via EX/MEM's M/WB bundle path
		Jalr_ctrl_i			: IN 	STD_LOGIC;   -- "this is JALR"
		alu_res_i 			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- JALR target, from EX_MEM_REG.alu_res_o
		
		--Outputs
		pc_plus4_o			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- PC+4 (link value for JAL/JALR)
		pc_o 				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- current PC (registered)
		instruction_o 	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)		-- 32-bit instruction word from ITCM (combinational)
	);
END Ifetch;


ARCHITECTURE behavior OF Ifetch IS
	SIGNAL pc_q				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);			-- registered PC (what we output)
	SIGNAL pc_plus4_r 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);			-- combinational PC+4 (sequential case only)
	SIGNAL itcm_addr_w		: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);		-- address sent to ITCM
	SIGNAL next_pc_w  		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);			-- combinational next PC value (MUX output)
								
	
BEGIN
	--=======================================
	-- ITCM (ROM) connection
	--=======================================
	inst_memory: altsyncram
	GENERIC MAP (
		operation_mode						=> "ROM",
		width_a 							=> DATA_BUS_WIDTH,
		widthad_a 							=> ITCM_ADDR_WIDTH,
		numwords_a 							=> WORDS_NUM,
		lpm_hint 							=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type 							=> "altsyncram",
		outdata_reg_a 						=> "UNREGISTERED",
		init_file 							=> "C:\Users\amitp\OneDrive\Desktop\Comp_Lab\Lab5\seat2(gemma5x5)\bin\M9K-intel\ITCM.hex",
		intended_device_family	=> "Cyclone"
	)
	PORT MAP (
		clock0    => clk_i,
		address_a	=> itcm_addr_w, 
		q_a 	   	=> instruction_o 
	);

-----------------------------------------------------------------------------------		
	-- Adder to compute PC+4 (sequential next-PC candidate)
  pc_plus4_r(PC_WIDTH-1 DOWNTO 0)	<= pc_q(PC_WIDTH-1 DOWNTO 0) + 4;
	
-----------------------------------------------------------------------------------
	
	
	next_pc_w	<=	(others => '0') 								WHEN	rst_i = '1'							ELSE
								pc_q(PC_WIDTH-1 DOWNTO 0)				WHEN	ena_i = '0'							ELSE	-- stall: hold, re-fetch same instruction
								alu_res_i(PC_WIDTH-1 DOWNTO 0)		WHEN	Jalr_ctrl_i							ELSE	-- case of jalr
								addr_gen_i(PC_WIDTH-1 DOWNTO 0)		WHEN	br_or_jump_taken_i ELSE	-- case of Branch Taken or jal 
								pc_plus4_r(PC_WIDTH-1 DOWNTO 0);																			-- case of Branch Not-Taken 				

-----------------------------------------------------------------------------------
-- pc register: holds the current PC value. Synchronous reset, per LAB5
-- design requirement #2. Always loads next_pc_w on every rising edge --
-- the "hold" behaviour during a stall is achieved entirely through the
-- next_pc_w mux above (next_pc_w = pc_q when ena_i='0'), not through a
-- separate write-enable on the register itself, since rst_i must always
-- be able to override (synchronous reset has top priority either way).
-------------------------------------------------------------------------------------
PROCESS (clk_i)
	BEGIN
		IF (clk_i'EVENT AND clk_i='1') THEN
			IF rst_i = '1' THEN
				pc_q(PC_WIDTH-1 DOWNTO 0) <= (OTHERS => '0');
			ELSE
				pc_q(PC_WIDTH-1 DOWNTO 0) <= next_pc_w;
			END IF;
		END IF;
END PROCESS;
-----------------------------------------------------------------------------------	
	-- send address to inst. memory address register
	G1: 
	if (WORD_GRANULARITY = True) generate 			-- i.e. each WORD has unike address
		itcm_addr_w <= next_pc_w(PC_WIDTH-1 DOWNTO 2);
	elsif (WORD_GRANULARITY = False) generate 	-- i.e. each BYTE has unike address
		itcm_addr_w <= next_pc_w;
	end generate;
---------------------------------------------------------------------------------------
	pc_o 				<= 	pc_q;
	pc_plus4_o 			<= 	pc_plus4_r;
---------------------------------------------------------------------------------------
	
END behavior;