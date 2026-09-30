
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.aux_package.all;
USE work.const_package.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY dmemory IS
	generic(
		DATA_BUS_WIDTH 	: integer := 32;
		DTCM_ADDR_WIDTH : integer := 8;
		WORDS_NUM 			: integer := 256
	);
	PORT(	
		--Inputs
		clk_i						: IN 	STD_LOGIC;
		rst_i						: IN 	STD_LOGIC;
		dtcm_addr_i 				: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0); -- alu_res from EX_MEM_REG that is used as adress to DTCM
		dtcm_data_wr_i 				: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); ----rd(f2)
		MemRead_ctrl_i  			: IN 	STD_LOGIC;
		MemWrite_ctrl_i 			: IN 	STD_LOGIC;--
		mulop_i						: IN 	STD_LOGIC;
		mul_stg1_p0_i 				: IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p1_i 				: IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p2_i 				: IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p3_i 				: IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);

		
		--Outputs--
		mul_result_o 				: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o 				: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		
	);
END dmemory;



ARCHITECTURE behavior OF dmemory IS
	SIGNAL wrclk_w : STD_LOGIC;
	signal mulop7_w : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL mem_mul_res_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	
BEGIN
	data_memory : altsyncram
	GENERIC MAP  (
		operation_mode					=> "SINGLE_PORT",
		width_a									=> DATA_BUS_WIDTH,
		widthad_a								=> DTCM_ADDR_WIDTH,
		numwords_a 							=> WORDS_NUM,
		lpm_hint 								=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = DTCM",
		lpm_type 						=> "altsyncram",
		outdata_reg_a 			=> "UNREGISTERED",
		init_file 				=> "C:\Users\amitp\OneDrive\Desktop\Comp_Lab\Lab5\seat2(gemma5x5)\bin\M9K-intel\DTCM.hex",
		intended_device_family 	=> "Cyclone"
	)
	PORT MAP (
		wren_a 									=> MemWrite_ctrl_i,
		clock0									=> wrclk_w,
		address_a								=> dtcm_addr_i,
		data_a									=> dtcm_data_wr_i,
		q_a										=> dtcm_data_rd_o	
	);

	wrclk_w <= NOT clk_i;	-- Load memory address register with write clock

	mulop7_w <= "000000" & mulop_i;

	MUL2_inst : MUL_STAGE2
		generic map (
			DATA_WIDTH => DATA_BUS_WIDTH
		)
		port map (
			p0_i             => mul_stg1_p0_i,
			p1_i             => mul_stg1_p1_i,
			p2_i             => mul_stg1_p2_i,
			p3_i             => mul_stg1_p3_i,
			mulop_i          => mulop7_w,
			mul_stage1_res_o => mem_mul_res_w
		);


	mul_result_o <= mem_mul_res_w ;
	

END behavior;
