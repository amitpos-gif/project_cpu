---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
USE work.cond_compilation_package.all;


package aux_package is

	component RV32I_CORE is
		generic( 
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
	    MODELSIM 					: integer 	:= G_MODELSIM;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			--#FinalProject Divider: these two defaulted to 10 here while the
			-- RV32I_CORE entity defaults them to G_PC_WIDTH/G_MA_WIDTH (13).
			-- Instantiation binds against THIS declaration, so any instance that
			-- did not override them silently got a 10-bit PC. Aligned to the entity.
			PC_WIDTH 					: integer 	:= G_PC_WIDTH;
			MA_WIDTH 					: integer 	:= G_MA_WIDTH;
			DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
			CLK_CNT_WIDTH 		: integer 	:= 16
		);
		PORT(
			--Inputs
			rst_i		 					:IN	STD_LOGIC;
			clk_i							:IN	STD_LOGIC;
			--#FinalProject Divider: fast divider clock
			divclk_i					:IN	STD_LOGIC;
			dtcm_data_rd_i		:IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			INTR_i                 :IN STD_LOGIC;

			--Outputs (used also for Signal-Tap auxiliary pins)
			pc_o							:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			
			RegWrite_ctrl_o		:OUT 	STD_LOGIC;
			MemWrite_ctrl_o		:OUT 	STD_LOGIC;
			MemRead_ctrl_o		:OUT 	STD_LOGIC;
			Branch_ctrl_o			:OUT 	STD_LOGIC;
			
			read_data1_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			write_data_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			
			alu_res_o 				:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);															
			brTaken_o					:OUT 	STD_LOGIC; 
			
			dtcm_addr_o				:OUT 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
			dtcm_data_wr_o		:OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			dtcm_data_rd_o		:OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

			mclk_cnt_o				:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
			INTA_o                  :OUT STD_LOGIC;
			GIE_o                   :OUT STD_LOGIC
		);
	end component;
--------------------------------------------------------- 
	component single_cycle_user_interface IS
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
		--#FinalProject Divider: fast divider clock
		divclk_i					: IN	STD_LOGIC;

		--#FinalProject Stage0: I/O bus
		io_data_rd_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		io_addr_o					: OUT	STD_LOGIC_VECTOR(13 DOWNTO 0);
		io_wr_o						: OUT	STD_LOGIC;
		io_rd_o						: OUT	STD_LOGIC;

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
END component;
	-------------------------------------------------------------------------------
	component control is
		PORT( 
		--Inputs
		clk_i                 : IN  STD_LOGIC;
		rst_i                 : IN  STD_LOGIC;
		instruction_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
		DIVbusy_ctrl_i		: IN	STD_LOGIC;
		DIVstall_ctrl_i       : IN  STD_LOGIC;
		INTR_ctrl_i           : IN  STD_LOGIC;
		TYPEdata_ctrl_i       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		--Outputs
		RegDst_ctrl_o 		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		MemtoReg_ctrl_o 	: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
		Branch_ctrl_o 		: OUT 	STD_LOGIC;
		Jal_ctrl_o 				: OUT 	STD_LOGIC;
		Jalr_ctrl_o 			: OUT 	STD_LOGIC;
		UpperIm_ctrl_o		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_o	 		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		-- #RV32IM task: MULOp enables MUL component
		MULOp_ctrl_o			: OUT 	STD_LOGIC;
		DIVOp_ctrl_o			: OUT	STD_LOGIC;
		PChold_ctrl_o		: OUT	STD_LOGIC;
		WBSrc0_ctrl_o		: OUT	STD_LOGIC;
		WBSrc1_ctrl_o		: OUT	STD_LOGIC_VECTOR(1 DOWNTO 0);
		INTA_ctrl_o           : OUT STD_LOGIC;
		IRQhold_ctrl_o        : OUT STD_LOGIC;
		IRQservice_ctrl_o     : OUT STD_LOGIC;
		IRQtype_ctrl_o        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		GIEclear_ctrl_o       : OUT STD_LOGIC;
		GIEset_ctrl_o         : OUT STD_LOGIC
	);
	end component;
---------------------------------------------------------	
	component dmemory is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM 			: integer := 256
		);
		PORT(	
			--Inputs
			clk_i						: IN 	STD_LOGIC;
			rst_i						: IN 	STD_LOGIC;
			dtcm_addr_i 		: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
			dtcm_data_wr_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MemRead_ctrl_i  : IN 	STD_LOGIC;
			MemWrite_ctrl_i : IN 	STD_LOGIC;
			
			--Outputs
			dtcm_data_rd_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Execute is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			PC_WIDTH 				: integer := 10
		);
		PORT(	
			--Inputs
			read_data1_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			read_data2_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			sign_extend_i 	: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
			UpperIm_ctrl_i	: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_i	 	: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUSrc_ctrl_i 	: IN 	STD_LOGIC;
			pc_i						: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
				
			--Outputs
			brTaken_o 			: OUT	STD_LOGIC;
			alu_res_o 			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			addr_gen_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Idecode is
		generic(
			PC_WIDTH 				: integer	:= 10;
			DATA_BUS_WIDTH	: integer := 32
		);
		PORT(
			--Inputs
			clk_i						: IN 	STD_LOGIC;
			rst_i						: IN 	STD_LOGIC;
			pc_plus4_i			: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			dtcm_data_rd_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			alu_res_i				: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			RegDst_ctrl_i 	: IN 	STD_LOGIC;
			RegWrite_ctrl_i : IN 	STD_LOGIC;
			MemtoReg_ctrl_i : IN 	STD_LOGIC;
			-- Cascaded write-back mux controls and accelerator results
			WBSrc0_ctrl_i   : IN  STD_LOGIC;
			WBSrc1_ctrl_i   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			mul_res_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			quotient_i      : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rem_i           : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IRQ_clear_gie_i : IN  STD_LOGIC;
			IRQ_set_gie_i   : IN  STD_LOGIC;
			IRQ_save_tp_i   : IN  STD_LOGIC;
			IRQ_return_pc_i : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

			--Outputs
			read_data1_o		: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			SignExt_o 			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			GIE_o           : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------		
	component Ifetch is
		generic(
			WORD_GRANULARITY 	: boolean	:= False;
			DATA_BUS_WIDTH 		: integer	:= 32;
			PC_WIDTH 					: integer	:= 10;
			ITCM_ADDR_WIDTH 	: integer	:= 8;
			WORDS_NUM 				: integer	:= 256
		);
		PORT(
			--Inputs
			clk_i					: IN 	STD_LOGIC;
			rst_i 				: IN 	STD_LOGIC;
			PChold_i			: IN	STD_LOGIC;
			addr_gen_i 		: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			Branch_ctrl_i	: IN 	STD_LOGIC;
			brTaken_i 		: IN 	STD_LOGIC;
			Jal_ctrl_i		: IN 	STD_LOGIC;
			Jalr_ctrl_i		: IN 	STD_LOGIC;
			alu_res_i 		: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			
			--Outputs
			pc_o 					: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_plus4_o 		: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o : OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	COMPONENT PLL IS
		generic(
			OUT_DIVIDE_BY   : NATURAL := G_PLL_DIV;
			OUT_MULTIPLY_BY : NATURAL := G_PLL_MUL
		);
		port(
			areset		: IN STD_LOGIC  := '0';
			inclk0		: IN STD_LOGIC  := '0';
			c0     		: OUT STD_LOGIC ;
			locked		: OUT STD_LOGIC 
		);
  END COMPONENT;
---------------------------------------------------------
	-- #RV32IM task: MUL component - 16-bit multiplier using four 8-bit partial products
	component MUL is
		GENERIC(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			ain_i     : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			bin_i     : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			MULOp_i   : IN  STD_LOGIC;
			mul_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	-- Divider operand synchronizer - Figure 10b
	component sync is
		GENERIC(
			DATA_BUS_WIDTH	: POSITIVE := 32
		);
		PORT(
			read_data1_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			divclk_i		: IN  STD_LOGIC;
			rst_i			: IN  STD_LOGIC;
			ain_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			bin_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	-- Unsigned multicycle restoring divider
	component divider_accelerator is
		GENERIC(
			DATA_BUS_WIDTH	: POSITIVE := 32;
			N					: POSITIVE := 32
		);
		PORT(
			ain_i				: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			bin_i				: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			divclk_i		: IN	STD_LOGIC;
			divrst_i		: IN	STD_LOGIC;
			divena_i		: IN	STD_LOGIC;
			quotient_o	: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rem_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			divbusy_o		: OUT	STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Basic Timer counter core
	component bit_Timer is
		GENERIC(
			n : INTEGER := 32
		);
		PORT(
			clk       : IN  STD_LOGIC;
			rst       : IN  STD_LOGIC;
			ena       : IN  STD_LOGIC;
			EQUY      : IN  STD_LOGIC;
			timer_val : OUT STD_LOGIC_VECTOR(n-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	-- Basic Timer output-compare/PWM unit
	component OUTPUT_UNIT is
		GENERIC(
			n : INTEGER := 32
		);
		PORT(
			y_i        : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
			x_i        : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
			timer_i    : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
			ena_i      : IN  STD_LOGIC;
			clk_i      : IN  STD_LOGIC;
			rst_i      : IN  STD_LOGIC;
			pwm_mode_i : IN  STD_LOGIC;
			pwm_out    : OUT STD_LOGIC;
			equy_out   : OUT STD_LOGIC;
			equx_out   : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Basic Timer register/address decoder
	component addr_decoder_basic_timer is
		PORT(
			Address    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
			CS_BTCTL1  : OUT STD_LOGIC;
			CS_BTCTL2  : OUT STD_LOGIC;
			CS_BTCMPR0 : OUT STD_LOGIC;
			CS_BTCMPR1 : OUT STD_LOGIC;
			CS_BTCAPR  : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Basic Timer datapath/control unit
	component basic_timer is
		GENERIC(
			N : INTEGER := 32
		);
		PORT(
			smclk_i       : IN  STD_LOGIC;
			rst_i         : IN  STD_LOGIC;
			BTCTL1_we_i   : IN  STD_LOGIC;
			BTCTL2_we_i   : IN  STD_LOGIC;
			BTCMPR0_we_i  : IN  STD_LOGIC;
			BTCMPR1_we_i  : IN  STD_LOGIC;
			reg_data_i    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0);
			CAPIN1_i      : IN  STD_LOGIC;
			CAPIN2_i      : IN  STD_LOGIC;
			BTCAPR_o      : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
			BTIFG_o       : OUT STD_LOGIC;
			PWM_o         : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Basic Timer with its memory-address decoder
	component basic_timer_top is
		GENERIC(
			N : INTEGER := 32
		);
		PORT(
			smclk_i     : IN  STD_LOGIC;
			rst_i       : IN  STD_LOGIC;
			Address_i   : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
			WriteData_i : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0);
			MemWrite_i  : IN  STD_LOGIC;
			CAPIN1_i    : IN  STD_LOGIC;
			CAPIN2_i    : IN  STD_LOGIC;
			BTCAPR_o    : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
			BTIFG_o     : OUT STD_LOGIC;
			PWM_o       : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Interrupt-controller register address decoder
	component addr_decoder_interrupt is
		PORT(
			Address : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
			CS_IE   : OUT STD_LOGIC;
			CS_IFG  : OUT STD_LOGIC;
			CS_TYPE : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Required non-bonus interrupt controller
	component interrupt_controller is
		PORT(
			smclk_i    : IN  STD_LOGIC;
			rst_i      : IN  STD_LOGIC;
			IE_we_i    : IN  STD_LOGIC;
			IFG_we_i   : IN  STD_LOGIC;
			reg_data_i : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			BTIFG_i    : IN  STD_LOGIC;
			KEY_irq_i  : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);
			GIE_i      : IN  STD_LOGIC;
			INTA_i     : IN  STD_LOGIC;
			IE_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			IFG_o      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			TYPE_o     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			INTR_o     : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- Interrupt controller with decoder and byte-wide MMIO interface
	component interrupt_controller_top is
		PORT(
			smclk_i   : IN    STD_LOGIC;
			rst_i     : IN    STD_LOGIC;
			Address   : IN    STD_LOGIC_VECTOR(13 DOWNTO 0);
			Data      : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			MemRead   : IN    STD_LOGIC;
			MemWrite  : IN    STD_LOGIC;
			BTIFG_i   : IN    STD_LOGIC;
			KEY_irq_i : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);
			GIE_i     : IN    STD_LOGIC;
			INTA_i    : IN    STD_LOGIC;
			INTR_o    : OUT   STD_LOGIC
		);
	end component;
---------------------------------------------------------
	-- GPIO address decoder
	component addr_decoder_gpio is
		PORT(
			Address  : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
			CS_LEDR  : OUT STD_LOGIC;
			CS_HEX01 : OUT STD_LOGIC;
			CS_HEX23 : OUT STD_LOGIC;
			CS_HEX45 : OUT STD_LOGIC;
			CS_SW    : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component d_latch_byte is
		PORT(
			clk : IN  STD_LOGIC;
			D   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			En  : IN  STD_LOGIC;
			Q   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component tristate_byte is
		PORT(
			D  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			OE : IN  STD_LOGIC;
			Y  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component hex7seg_decoder is
		PORT(
			hex_in : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
			seg    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component gpio_peripherals is
		PORT(
			smclk    : IN    STD_LOGIC;
			Address  : IN    STD_LOGIC_VECTOR(13 DOWNTO 0);
			Data     : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			MemRead  : IN    STD_LOGIC;
			MemWrite : IN    STD_LOGIC;
			SW       : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);
			LEDR     : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0);
			HEX0     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX1     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX2     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX3     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX4     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX5     : OUT   STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component pushbutton_peripheral is
		PORT(
			smclk     : IN    STD_LOGIC;
			rst_i     : IN    STD_LOGIC;
			Address   : IN    STD_LOGIC_VECTOR(13 DOWNTO 0);
			Data      : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			MemRead   : IN    STD_LOGIC;
			KEY1      : IN    STD_LOGIC;
			KEY2      : IN    STD_LOGIC;
			KEY3      : IN    STD_LOGIC;
			key_irq_o : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component BidirPin is
		GENERIC(
			width : INTEGER := 16
		);
		PORT(
			Dout  : IN    STD_LOGIC_VECTOR(width-1 DOWNTO 0);
			en    : IN    STD_LOGIC;
			Din   : OUT   STD_LOGIC_VECTOR(width-1 DOWNTO 0);
			IOpin : INOUT STD_LOGIC_VECTOR(width-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component clock_tree is
		PORT(
			rst_i      : IN  STD_LOGIC;
			baseclk_i  : IN  STD_LOGIC;
			mclk_o     : OUT STD_LOGIC;
			accelclk_o : OUT STD_LOGIC;
			smclk_o    : OUT STD_LOGIC;
			locked_o   : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component mcu_top is
		PORT(
			rst_i    : IN  STD_LOGIC;
			clk_i    : IN  STD_LOGIC;
			divclk_i : IN  STD_LOGIC;
			smclk    : IN  STD_LOGIC;
			KEY1     : IN  STD_LOGIC;
			KEY2     : IN  STD_LOGIC;
			KEY3     : IN  STD_LOGIC;
			CAPIN1   : IN  STD_LOGIC;
			CAPIN2   : IN  STD_LOGIC;
			SW       : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
			LEDR     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			PWM      : OUT STD_LOGIC;
			HEX0     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX1     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX2     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX3     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX4     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			HEX5     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
		);
	end component;
---------------------------------------------------------

end aux_package;
