
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.cond_compilation_package.all;

PACKAGE aux_package IS

	COMPONENT rv32i_core_pipline IS
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
		--Inputs (Figure 8 left side)
		clk_i            : IN  STD_LOGIC;                                  -- 50MHz
		rst_i            : IN  STD_LOGIC;                                  -- KEY0, synchronous
		BPADDR_i         : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);               -- SW[7:0] breakpoint (word granularity)

		--Outputs (Figure 8 right side) -- Signal-Tap / IPC instrumentation
		CLKCNT_o         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);             -- free-running clock counter
		IFpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IFinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IDinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EXpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMpc_o          : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEMinstruction_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		WBpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		WBinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		STRIGGER_o       : OUT STD_LOGIC;                                  -- (IFpc_word == BPADDR_i)
		FHCNT_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);              -- flush counter
		STCNT_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)               -- stall counter
	);
END COMPONENT;
---------------------------------------------------
COMPONENT PIPLINE_USER_INTERFACE IS
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
		--------------------------------------------------------------------
		-- Physical board pins (names MUST match the .qsf)
		--------------------------------------------------------------------
		CLOCK_50 : IN  STD_LOGIC;                       -- 50 MHz oscillator
		KEY      : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);    -- push-buttons, ACTIVE-LOW
		SW       : IN  STD_LOGIC_VECTOR(9 DOWNTO 0)     -- slide switches
		-- No output pins: all Figure-8 taps are observed via SignalTap.
	);
END COMPONENT;

	--========================================================================
	-- Stage 1 : Instruction Fetch
	--========================================================================
	COMPONENT Ifetch IS
		generic(
			WORD_GRANULARITY : boolean := False;
			DATA_BUS_WIDTH   : integer := 32;
			PC_WIDTH         : integer := 10;
			ITCM_ADDR_WIDTH  : integer := 8;
			WORDS_NUM        : integer := 256
		);
		PORT(
			clk_i              : IN  STD_LOGIC;
			rst_i              : IN  STD_LOGIC;
			ena_i              : IN  STD_LOGIC;
			addr_gen_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			br_or_jump_taken_i : IN  STD_LOGIC;
			Jalr_ctrl_i        : IN  STD_LOGIC;
			alu_res_i          : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			pc_plus4_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_o               : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Stage 2 : Instruction Decode (Register File + immediate generation)
	--========================================================================
	COMPONENT Idecode IS
		generic(
			PC_WIDTH       : integer := 10;
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			clk_i            : IN  STD_LOGIC;
			rst_i            : IN  STD_LOGIC;
			instruction_i    : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			RegDst_i         : IN  STD_LOGIC;
			RegWrite_i       : IN  STD_LOGIC;
			rd_i             : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			writeback_data_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			pc_plus4_i       : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			read_data1_o     : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o     : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			SignExt_o        : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_o            : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_o            : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_o             : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Control Unit (lives in stage 2, drives the ID/EX control bundle)
	--========================================================================
	COMPONENT control IS
		PORT(
			instruction_i   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			RegDst_ctrl_o   : OUT STD_LOGIC;
			ALUSrc_ctrl_o   : OUT STD_LOGIC;
			MemtoReg_ctrl_o : OUT STD_LOGIC;
			RegWrite_ctrl_o : OUT STD_LOGIC;
			MemRead_ctrl_o  : OUT STD_LOGIC;
			MemWrite_ctrl_o : OUT STD_LOGIC;
			Branch_ctrl_o   : OUT STD_LOGIC;
			Jal_ctrl_o      : OUT STD_LOGIC;
			Jalr_ctrl_o     : OUT STD_LOGIC;
			UpperIm_ctrl_o  : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_o    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			MULOp_ctrl_o    : OUT STD_LOGIC;
			WBSrc_ctrl_o    : OUT STD_LOGIC
		);
	END COMPONENT;

	--========================================================================
	-- Stage 3 : Execute (ALU + branch resolve + addr_gen) -- exposes ain_o/bin_o
	--           (post-forward operands) so MUL_STAGE1 can be driven in the core
	--========================================================================
	COMPONENT  Execute IS
	generic(
		DATA_BUS_WIDTH 	: integer := 32;
		PC_WIDTH 				: integer := 10
	);
	PORT(	
		--Inputs
		read_data1_i 			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i 			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		sign_extend_i 			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		pc_i					: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		--control signals ex---
		mulop_i					: IN 	STD_LOGIC; 
		ALUOp_ctrl_i	 		: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		ALUSrc_ctrl_i 			: IN 	STD_LOGIC;
		Branch_ctrl_i			: IN 	STD_LOGIC;	-- "this is a branch instruction" (EX bundle, from ID/EX)
		Jal_ctrl_i				: IN 	STD_LOGIC;	-- "this is JAL"
		Jalr_ctrl_i				: IN 	STD_LOGIC;	-- "this is JALR"
		UpperIm_ctrl_i 			: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);	-- "00"=normal RF read, "01"=PC for AUIPC, "10"=zeros for LUI

		Forward_Ain_i			: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);	-- from Forwarding-Unit: "00"=none, "10"=EX/MEM, "01"=MEM/WB
		Forward_Bin_i			: IN 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		exmem_fwd_val_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- EX/MEM's forwardable result (ALUres typically)
		memwb_fwd_val_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- MEM/WB's forwardable result (post writeback-mux)
			
		--Outputs
		Jalr_ctrl_o 			: OUT	STD_LOGIC;
		br_or_jump_taken_o		: OUT	STD_LOGIC;	-- (Branch AND brTaken) OR Jal OR Jalr, latched by EX_MEM_REG
		alu_res_o 				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		adder_gen_o 			: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		mulop_o					: OUT 	STD_LOGIC;
		ex_mul_stg1_p0_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		ex_mul_stg1_p1_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		ex_mul_stg1_p2_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		ex_mul_stg1_p3_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0)
		);
	END COMPONENT;
	--========================================================================
	-- Multiplier stage 1 (EX stage) : four 8x8 partial products
	--========================================================================
	COMPONENT Mul_Stage1 IS
		GENERIC(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			Ain   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Bin   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MULOP : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			P0_o  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P1_o  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P2_o  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P3_o  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Stage 4 : Data memory (DTCM)
	--========================================================================
	COMPONENT dmemory IS
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
		mulop_i				: IN 	STD_LOGIC;
		mul_stg1_p0_i : IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p1_i : IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p2_i : IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p3_i : IN 	STD_LOGIC_VECTOR(15 DOWNTO 0);

		
		--Outputs
		mul_result_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)

	);
END COMPONENT;

	--========================================================================
	-- Multiplier stage 2 (MEM stage) : combine partials into 32-bit product
	-- NOTE: entity output port is named mul_stage1_res_o (legacy name).
	--========================================================================
	COMPONENT MUL_STAGE2 IS
		GENERIC(
			DATA_WIDTH : integer := 32
		);
		PORT(
			p0_i             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			p1_i             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			p2_i             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			p3_i             : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			mulop_i          : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			mul_stage1_res_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Stage 5 : Write-back MUX (alu / mem / mul). PC+4 link handled in IDECODE.
	--========================================================================
	COMPONENT WB_MUX IS
		generic(
			PC_WIDTH       : integer := 13;
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			alu_res_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mul_res_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mem_data_i      : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			WBSrc_ctrl_i    : IN  STD_LOGIC;
			MemtoReg_ctrl_i : IN  STD_LOGIC;
			writeback_data_o: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Pipeline register : IF/ID
	--========================================================================
	COMPONENT IF_ID_REG IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := 13
		);
		PORT(
			clk_i         : IN  STD_LOGIC;
			rst_i         : IN  STD_LOGIC;
			ena_i         : IN  STD_LOGIC;
			flush_i       : IN  STD_LOGIC;
			pc_plus4_i    : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_i          : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			pc_plus4_o    : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_o          : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			instruction_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	END COMPONENT;

	--========================================================================
	-- Pipeline register : ID/EX
	--========================================================================
	COMPONENT ID_EX_REG IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := 13
		);
		PORT(
			clk_i        : IN  STD_LOGIC;
			rst_i        : IN  STD_LOGIC;
			flush_i      : IN  STD_LOGIC;
			stall_i      : IN  STD_LOGIC;
			pc_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_plus4_i   : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			read_data1_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			imm32_i      : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_i        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_i        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_i         : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUOp_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUSrc_i     : IN  STD_LOGIC;
			UpperImm_ctrl_i   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			MULOp_i      : IN  STD_LOGIC;
			Branch_i     : IN  STD_LOGIC;
			Jal_i        : IN  STD_LOGIC;
			Jalr_i       : IN  STD_LOGIC;
			MemRead_i    : IN  STD_LOGIC;
			MemWrite_i   : IN  STD_LOGIC;
			RegWrite_i   : IN  STD_LOGIC;
			MemtoReg_i   : IN  STD_LOGIC;
			RegDst_i     : IN  STD_LOGIC;
			WBSrc_i      : IN  STD_LOGIC;
			pc_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			pc_plus4_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			read_data1_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			imm32_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_o        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_o        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_o         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUOp_o      : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUSrc_o     : OUT STD_LOGIC;
			UpperImm_ctrl_o   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			MULOp_o      : OUT STD_LOGIC;
			Branch_o     : OUT STD_LOGIC;
			Jal_o        : OUT STD_LOGIC;
			Jalr_o       : OUT STD_LOGIC;
			MemRead_o    : OUT STD_LOGIC;
			MemWrite_o   : OUT STD_LOGIC;
			RegWrite_o   : OUT STD_LOGIC;
			MemtoReg_o   : OUT STD_LOGIC;
			RegDst_o     : OUT STD_LOGIC;
			WBSrc_o      : OUT STD_LOGIC
		);
	END COMPONENT;

	--========================================================================
	-- Pipeline register : EX/MEM
	--========================================================================
	COMPONENT EX_MEM_REG IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := 13
		);
		PORT(
			clk_i              : IN  STD_LOGIC;
			rst_i              : IN  STD_LOGIC;
			flush_i            : IN  STD_LOGIC;
			stall_i            : IN  STD_LOGIC;
			pc_plus4_i         : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			read_data1_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			imm32_i            : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_i              : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_i              : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_i               : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			mul_stg1_p0_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p1_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p2_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p3_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			Alu_Res_i          : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Adder_gen_i        : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MULOp_i            : IN  STD_LOGIC;
			br_or_jump_taken_i : IN  STD_LOGIC;
			Jalr_ctrl_i        : IN  STD_LOGIC;
			MemRead_i          : IN  STD_LOGIC;
			MemWrite_i         : IN  STD_LOGIC;
			RegWrite_i         : IN  STD_LOGIC;
			MemtoReg_i         : IN  STD_LOGIC;
			RegDst_i           : IN  STD_LOGIC;
			WBSrc_i            : IN  STD_LOGIC;
			pc_plus4_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			read_data1_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o       : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			imm32_o            : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_o              : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_o              : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_o               : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			Alu_Res_o          : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Adder_gen_o        : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			mul_stg1_p0_o      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p1_o      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p2_o      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			mul_stg1_p3_o      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			MULOp_o            : OUT STD_LOGIC;
			br_or_jump_taken_o : OUT STD_LOGIC;
			Jalr_ctrl_o        : OUT STD_LOGIC;
			MemRead_o          : OUT STD_LOGIC;
			MemWrite_o         : OUT STD_LOGIC;
			RegWrite_o         : OUT STD_LOGIC;
			MemtoReg_o         : OUT STD_LOGIC;
			RegDst_o           : OUT STD_LOGIC;
			WBSrc_o            : OUT STD_LOGIC
		);
	END COMPONENT;

	--========================================================================
	-- Pipeline register : MEM/WB
	--========================================================================
	COMPONENT MEM_WB_REG IS
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := 13
		);
		PORT(
			clk_i       : IN  STD_LOGIC;
			rst_i       : IN  STD_LOGIC;
			pc_plus4_i  : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			alu_res_i   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mem_data_i  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mul_res_i   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rd_i        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegWrite_i  : IN  STD_LOGIC;
			MemtoReg_i  : IN  STD_LOGIC;
			RegDst_i    : IN  STD_LOGIC;
			WBSrc_i     : IN  STD_LOGIC;
			pc_plus4_o  : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			alu_res_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mem_data_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			mul_res_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rd_o        : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			RegWrite_o  : OUT STD_LOGIC;
			MemtoReg_o  : OUT STD_LOGIC;
			RegDst_o    : OUT STD_LOGIC;
			WBSrc_o     : OUT STD_LOGIC
		);
	END COMPONENT;

	--========================================================================
	-- Hazard hardware
	--========================================================================
	COMPONENT FORWARDING_UNIT IS
		PORT(
			ID_EX_rs1_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ID_EX_rs2_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			EX_MEM_rd_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			EX_MEM_RegWrite_i: IN  STD_LOGIC;
			MEM_WB_rd_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			MEM_WB_RegWrite_i: IN  STD_LOGIC;
			Forward_Ain_o    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			Forward_Bin_o    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT STALL_UNIT IS
		PORT(
			MemRead_i  : IN  STD_LOGIC;
			MULOp_i    : IN  STD_LOGIC;
			idex_rd_i  : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ifid_rs1_i : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ifid_rs2_i : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			Stall_o    : OUT STD_LOGIC
		);
	END COMPONENT;

	COMPONENT FLUSH_UNIT IS
		PORT(
			br_or_jump_taken_i : IN  STD_LOGIC;
			Jalr_i             : IN  STD_LOGIC;
			flush_o            : OUT STD_LOGIC
		);
	END COMPONENT;

	--========================================================================
	-- PLL (clock synthesizer, used on FPGA; bypassed in ModelSim)
	--========================================================================
	COMPONENT PLL IS
		PORT(
			areset : IN  STD_LOGIC := '0';
			inclk0 : IN  STD_LOGIC := '0';
			c0     : OUT STD_LOGIC;
			locked : OUT STD_LOGIC
		);
	END COMPONENT;

END aux_package;