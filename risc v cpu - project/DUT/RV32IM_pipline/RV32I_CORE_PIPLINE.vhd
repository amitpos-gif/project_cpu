LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.aux_package.all;
USE work.cond_compilation_package.all;
USE work.const_package.all;

ENTITY rv32i_core_pipline IS
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
END rv32i_core_pipline;


ARCHITECTURE structure OF rv32i_core_pipline IS

	-- NOP encoding used to flush the debug shadow pipeline (ADDI x0,x0,0)
	CONSTANT NOP_INSTR : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00000013";

	--========================================================================
	-- STAGE 1 : IFETCH
	--========================================================================
	SIGNAL if_pc_w          : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_pc_plus4_w    : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_instruction_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	--========================================================================
	-- IF/ID outputs (stage 2 inputs)
	--========================================================================
	SIGNAL id_pc_w          : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL id_pc_plus4_w    : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL id_instruction_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	--========================================================================
	-- STAGE 2 : IDECODE + CONTROL outputs
	--========================================================================
	SIGNAL id_read_data1_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL id_read_data2_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL id_signext_w     : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL id_rs1_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL id_rs2_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL id_rd_w          : STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- control bundle (combinational, from CONTROL)
	SIGNAL c_RegDst_w       : STD_LOGIC;
	SIGNAL c_ALUSrc_w       : STD_LOGIC;
	SIGNAL c_MemtoReg_w     : STD_LOGIC;
	SIGNAL c_RegWrite_w     : STD_LOGIC;
	SIGNAL c_MemRead_w      : STD_LOGIC;
	SIGNAL c_MemWrite_w     : STD_LOGIC;
	SIGNAL c_Branch_w       : STD_LOGIC;
	SIGNAL c_Jal_w          : STD_LOGIC;
	SIGNAL c_Jalr_w         : STD_LOGIC;
	SIGNAL c_UpperIm_w      : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL c_ALUOp_w        : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL c_MULOp_w        : STD_LOGIC;
	SIGNAL c_WBSrc_w        : STD_LOGIC;

	--========================================================================
	-- ID/EX outputs (stage 3 inputs)
	--========================================================================
	SIGNAL ex_pc_w          : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ex_pc_plus4_w    : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ex_read_data1_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_read_data2_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_imm32_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_rs1_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ex_rs2_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ex_rd_w          : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ex_ALUOp_w       : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL ex_ALUSrc_w      : STD_LOGIC;
	SIGNAL ex_UpperImm_w    : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL ex_MULOp_w       : STD_LOGIC;
	SIGNAL ex_Branch_w      : STD_LOGIC;
	SIGNAL ex_Jal_w         : STD_LOGIC;
	SIGNAL ex_Jalr_w        : STD_LOGIC;
	SIGNAL ex_MemRead_w     : STD_LOGIC;
	SIGNAL ex_MemWrite_w    : STD_LOGIC;
	SIGNAL ex_RegWrite_w    : STD_LOGIC;
	SIGNAL ex_MemtoReg_w    : STD_LOGIC;
	SIGNAL ex_RegDst_w      : STD_LOGIC;
	SIGNAL ex_WBSrc_w       : STD_LOGIC;

	--========================================================================
	-- STAGE 3 : EXECUTE + MUL_STAGE1 outputs
	--========================================================================
	SIGNAL ex_alu_res_w        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_adder_gen_w      : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ex_brjmp_taken_w    : STD_LOGIC;
	SIGNAL ex_jalr_ctrl_w      : STD_LOGIC;
	SIGNAL ex_fwd_rs2_w        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ex_p0_w             : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ex_p1_w             : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ex_p2_w             : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ex_p3_w             : STD_LOGIC_VECTOR(15 DOWNTO 0);

	--========================================================================
	-- EX/MEM outputs (stage 4 inputs)
	--========================================================================
	SIGNAL mem_pc_plus4_w   : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL mem_read_data1_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_read_data2_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_imm32_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_rs1_w        : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL mem_rs2_w        : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL mem_rd_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL mem_alu_res_w    : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_adder_gen_w  : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL mem_p0_w         : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL mem_p1_w         : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL mem_p2_w         : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL mem_p3_w         : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL mem_MULOp_w      : STD_LOGIC;
	SIGNAL mem_brjmp_taken_w: STD_LOGIC;
	SIGNAL mem_jalr_ctrl_w  : STD_LOGIC;
	SIGNAL mem_MemRead_w    : STD_LOGIC;
	SIGNAL mem_MemWrite_w   : STD_LOGIC;
	SIGNAL mem_RegWrite_w   : STD_LOGIC;
	SIGNAL mem_MemtoReg_w   : STD_LOGIC;
	SIGNAL mem_RegDst_w     : STD_LOGIC;
	SIGNAL mem_WBSrc_w      : STD_LOGIC;

	--========================================================================
	-- STAGE 4 : DTCM + MUL_STAGE2 outputs
	--========================================================================
	SIGNAL mem_data_rd_w    : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mem_mul_res_w    : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	--========================================================================
	-- MEM/WB outputs (stage 5 inputs)
	--========================================================================
	SIGNAL wb_pc_plus4_w    : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL wb_alu_res_w     : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wb_mem_data_w    : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wb_mul_res_w     : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wb_rd_w          : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL wb_RegWrite_w    : STD_LOGIC;
	SIGNAL wb_MemtoReg_w    : STD_LOGIC;
	SIGNAL wb_RegDst_w      : STD_LOGIC;
	SIGNAL wb_WBSrc_w       : STD_LOGIC;

	--========================================================================
	-- STAGE 5 : write-back result
	--========================================================================
	SIGNAL wb_writeback_w   : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	--========================================================================
	-- Hazard control
	--========================================================================
	SIGNAL fwd_Ain_w        : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL fwd_Bin_w        : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL stall_w          : STD_LOGIC;
	SIGNAL flush_w          : STD_LOGIC;

	-- Derived enables (active levels for the register controls)
	SIGNAL pcwrite_ena_w    : STD_LOGIC;   -- '1' = PC advances, '0' = hold (stall)
	SIGNAL ifid_ena_w       : STD_LOGIC;   -- '1' = IF/ID latches, '0' = hold (stall)

	--========================================================================
	-- Debug shadow pipeline for instruction taps (observation-only)
	--========================================================================
	SIGNAL instr_id_q   : STD_LOGIC_VECTOR(31 DOWNTO 0);  -- mirrors IF/ID.instruction
	SIGNAL instr_ex_q   : STD_LOGIC_VECTOR(31 DOWNTO 0);  -- mirrors ID/EX
	SIGNAL instr_mem_q  : STD_LOGIC_VECTOR(31 DOWNTO 0);  -- mirrors EX/MEM
	SIGNAL instr_wb_q   : STD_LOGIC_VECTOR(31 DOWNTO 0);  -- mirrors MEM/WB

	-- Debug shadow PCs for EX/MEM/WB stages (PC is not carried past ID/EX in
	-- the datapath, so we mirror it here for the taps).
	SIGNAL pc_ex_q      : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_mem_q     : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_wb_q      : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

	--========================================================================
	-- Figure-8 instrumentation counters
	--========================================================================
	SIGNAL clkcnt_q     : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL stcnt_q      : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL fhcnt_q      : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL strigger_w   : STD_LOGIC;

	-- PLL output clock (mclk_w = clk_i in ModelSim, PLL-derived on FPGA)
	SIGNAL mclk_w       : STD_LOGIC;

BEGIN

	--========================================================================
	-- PLL: bypass in ModelSim, use PLL on FPGA
	--========================================================================
	G0:
	if (MODELSIM = 0) generate
		MCLK : PLL
		PORT MAP (
			inclk0 => clk_i,
			c0     => mclk_w
		);
	else generate
		mclk_w <= clk_i;
	end generate;

	--========================================================================
	-- Hazard enable derivation
	--   stall  -> freeze PC and IF/ID (hold), bubble ID/EX
	--   flush  -> kill IF/ID, ID/EX, EX/MEM (squash wrong-path instructions)
	-- A flush takes priority over a stall: if we're redirecting, there is no
	-- load-use dependency worth preserving on the squashed path.
	--========================================================================
	pcwrite_ena_w <= '0' WHEN (stall_w = '1' AND flush_w = '0') ELSE '1';
	ifid_ena_w    <= '0' WHEN (stall_w = '1' AND flush_w = '0') ELSE '1';

	--========================================================================
	-- STAGE 1 : Instruction Fetch
	--========================================================================
	IFETCH_inst : Ifetch
		generic map (
			WORD_GRANULARITY => G_WORD_GRANULARITY,
			DATA_BUS_WIDTH   => DATA_BUS_WIDTH,
			PC_WIDTH         => PC_WIDTH,
			ITCM_ADDR_WIDTH  => ITCM_ADDR_WIDTH,
			WORDS_NUM        => DATA_WORDS_NUM
		)
		port map (
			clk_i              => mclk_w,
			rst_i              => rst_i,
			ena_i              => pcwrite_ena_w,
			-- redirect comes from REGISTERED EX/MEM outputs (resolved at stage 4)
			addr_gen_i         => mem_adder_gen_w,
			br_or_jump_taken_i => mem_brjmp_taken_w,
			Jalr_ctrl_i        => mem_jalr_ctrl_w,
			alu_res_i          => mem_alu_res_w,
			pc_plus4_o         => if_pc_plus4_w,
			pc_o               => if_pc_w,
			instruction_o      => if_instruction_w
		);

	--========================================================================
	-- IF/ID pipeline register
	--========================================================================
	IF_ID_inst : IF_ID_REG
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH,
			PC_WIDTH       => PC_WIDTH
		)
		port map (
			clk_i         => mclk_w,
			rst_i         => rst_i,
			ena_i         => ifid_ena_w,
			flush_i       => flush_w,
			pc_plus4_i    => if_pc_plus4_w,
			pc_i          => if_pc_w,
			instruction_i => if_instruction_w,
			pc_plus4_o    => id_pc_plus4_w,
			pc_o          => id_pc_w,
			instruction_o => id_instruction_w
		);

	--========================================================================
	-- STAGE 2 : Control Unit (decodes IF/ID instruction)
	--========================================================================
	CONTROL_inst : control
		port map (
			instruction_i   => id_instruction_w,
			RegDst_ctrl_o   => c_RegDst_w,
			ALUSrc_ctrl_o   => c_ALUSrc_w,
			MemtoReg_ctrl_o => c_MemtoReg_w,
			RegWrite_ctrl_o => c_RegWrite_w,
			MemRead_ctrl_o  => c_MemRead_w,
			MemWrite_ctrl_o => c_MemWrite_w,
			Branch_ctrl_o   => c_Branch_w,
			Jal_ctrl_o      => c_Jal_w,
			Jalr_ctrl_o     => c_Jalr_w,
			UpperIm_ctrl_o  => c_UpperIm_w,
			ALUOp_ctrl_o    => c_ALUOp_w,
			MULOp_ctrl_o    => c_MULOp_w,
			WBSrc_ctrl_o    => c_WBSrc_w
		);

	--========================================================================
	-- STAGE 2 : IDECODE (RF read + immediate gen; RF write from MEM/WB)
	--   Write-back side is driven by the RETIRING instruction (MEM/WB):
	--   RegDst_i, RegWrite_i, rd_i, pc_plus4_i  all come from MEM/WB so the
	--   JAL/JALR link MUX inside IDECODE acts on the correct instruction.
	--========================================================================
	IDECODE_inst : Idecode
		generic map (
			PC_WIDTH       => PC_WIDTH,
			DATA_BUS_WIDTH => DATA_BUS_WIDTH
		)
		port map (
			clk_i            => mclk_w,
			rst_i            => rst_i,
			instruction_i    => id_instruction_w,
			RegDst_i         => wb_RegDst_w,
			RegWrite_i       => wb_RegWrite_w,
			rd_i             => wb_rd_w,
			writeback_data_i => wb_writeback_w,
			pc_plus4_i       => wb_pc_plus4_w,
			read_data1_o     => id_read_data1_w,
			read_data2_o     => id_read_data2_w,
			SignExt_o        => id_signext_w,
			rs1_o            => id_rs1_w,
			rs2_o            => id_rs2_w,
			rd_o             => id_rd_w
		);

	--========================================================================
	-- ID/EX pipeline register
	--   stall_i / flush_i both insert a bubble (zeroed control => NOP effect).
	--========================================================================
	ID_EX_inst : ID_EX_REG
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH,
			PC_WIDTH       => PC_WIDTH
		)
		port map (
			clk_i        => mclk_w,
			rst_i        => rst_i,
			flush_i      => flush_w,
			stall_i      => stall_w,
			pc_i         => id_pc_w,
			pc_plus4_i   => id_pc_plus4_w,
			read_data1_i => id_read_data1_w,
			read_data2_i => id_read_data2_w,
			imm32_i      => id_signext_w,
			rs1_i        => id_rs1_w,
			rs2_i        => id_rs2_w,
			rd_i         => id_rd_w,
			ALUOp_i      => c_ALUOp_w,
			ALUSrc_i     => c_ALUSrc_w,
			UpperImm_ctrl_i   => c_UpperIm_w,
			MULOp_i      => c_MULOp_w,
			Branch_i     => c_Branch_w,
			Jal_i        => c_Jal_w,
			Jalr_i       => c_Jalr_w,
			MemRead_i    => c_MemRead_w,
			MemWrite_i   => c_MemWrite_w,
			RegWrite_i   => c_RegWrite_w,
			MemtoReg_i   => c_MemtoReg_w,
			RegDst_i     => c_RegDst_w,
			WBSrc_i      => c_WBSrc_w,

			pc_o         => ex_pc_w,
			pc_plus4_o   => ex_pc_plus4_w,
			read_data1_o => ex_read_data1_w,
			read_data2_o => ex_read_data2_w,
			imm32_o      => ex_imm32_w,
			rs1_o        => ex_rs1_w,
			rs2_o        => ex_rs2_w,
			rd_o         => ex_rd_w,
			ALUOp_o      => ex_ALUOp_w,
			ALUSrc_o     => ex_ALUSrc_w,
			UpperImm_ctrl_o   => ex_UpperImm_w,
			MULOp_o      => ex_MULOp_w,
			Branch_o     => ex_Branch_w,
			Jal_o        => ex_Jal_w,
			Jalr_o       => ex_Jalr_w,
			MemRead_o    => ex_MemRead_w,
			MemWrite_o   => ex_MemWrite_w,
			RegWrite_o   => ex_RegWrite_w,
			MemtoReg_o   => ex_MemtoReg_w,
			RegDst_o     => ex_RegDst_w,
			WBSrc_o      => ex_WBSrc_w
		);

	--========================================================================
	-- STAGE 3 : EXECUTE
	--   exmem_fwd_val = EX/MEM ALU result ; memwb_fwd_val = final WB value.
	--========================================================================
	EXECUTE_inst : Execute
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH,
			PC_WIDTH       => PC_WIDTH
		)
		port map (
			read_data1_i      => ex_read_data1_w,
			read_data2_i      => ex_read_data2_w,
			sign_extend_i     => ex_imm32_w,
			pc_i              => ex_pc_w,
			mulop_i           => ex_MULOp_w,
			ALUOp_ctrl_i      => ex_ALUOp_w,
			ALUSrc_ctrl_i     => ex_ALUSrc_w,
			Branch_ctrl_i     => ex_Branch_w,
			Jal_ctrl_i        => ex_Jal_w,
			Jalr_ctrl_i       => ex_Jalr_w,
			UpperIm_ctrl_i    => ex_UpperImm_w,
			Forward_Ain_i     => fwd_Ain_w,
			Forward_Bin_i     => fwd_Bin_w,
			exmem_fwd_val_i   => mem_alu_res_w,
			memwb_fwd_val_i   => wb_writeback_w,

			Jalr_ctrl_o       => ex_jalr_ctrl_w,
			br_or_jump_taken_o=> ex_brjmp_taken_w,
			alu_res_o         => ex_alu_res_w,
			adder_gen_o       => ex_adder_gen_w,
			ex_mul_stg1_p0_o  => ex_p0_w,
			ex_mul_stg1_p1_o  => ex_p1_w,
			ex_mul_stg1_p2_o  => ex_p2_w,
			ex_mul_stg1_p3_o  => ex_p3_w
		);

	-- Forwarded rs2 for store data: select the correct rs2 value using the
	-- same forwarding control that Execute uses for Forward_Bin.
	-- This is captured into EX/MEM read_data2 so DMEMORY gets the right value.
	WITH fwd_Bin_w SELECT
		ex_fwd_rs2_w <= ex_read_data2_w WHEN "00",
		                mem_alu_res_w   WHEN "10",
		                wb_writeback_w  WHEN "01",
		                ex_read_data2_w WHEN OTHERS;

	--========================================================================
	-- EX/MEM pipeline register
	--========================================================================
	EX_MEM_inst : EX_MEM_REG
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH,
			PC_WIDTH       => PC_WIDTH
		)
		port map (
			clk_i              => mclk_w,
			rst_i              => rst_i,
			flush_i            => flush_w,
			stall_i            => stall_w,
			pc_plus4_i         => ex_pc_plus4_w,
			read_data1_i       => ex_read_data1_w,
			read_data2_i       => ex_fwd_rs2_w,
			imm32_i            => ex_imm32_w,
			rs1_i              => ex_rs1_w,
			rs2_i              => ex_rs2_w,
			rd_i               => ex_rd_w,
			mul_stg1_p0_i      => ex_p0_w,
			mul_stg1_p1_i      => ex_p1_w,
			mul_stg1_p2_i      => ex_p2_w,
			mul_stg1_p3_i      => ex_p3_w,
			Alu_Res_i          => ex_alu_res_w,
			Adder_gen_i        => ex_adder_gen_w,
			MULOp_i            => ex_MULOp_w,
			br_or_jump_taken_i => ex_brjmp_taken_w,
			Jalr_ctrl_i        => ex_jalr_ctrl_w,
			MemRead_i          => ex_MemRead_w,
			MemWrite_i         => ex_MemWrite_w,
			RegWrite_i         => ex_RegWrite_w,
			MemtoReg_i         => ex_MemtoReg_w,
			RegDst_i           => ex_RegDst_w,
			WBSrc_i            => ex_WBSrc_w,

			pc_plus4_o         => mem_pc_plus4_w,
			read_data1_o       => mem_read_data1_w,
			read_data2_o       => mem_read_data2_w,
			imm32_o            => mem_imm32_w,
			rs1_o              => mem_rs1_w,
			rs2_o              => mem_rs2_w,
			rd_o               => mem_rd_w,
			Alu_Res_o          => mem_alu_res_w,
			Adder_gen_o        => mem_adder_gen_w,
			mul_stg1_p0_o      => mem_p0_w,
			mul_stg1_p1_o      => mem_p1_w,
			mul_stg1_p2_o      => mem_p2_w,
			mul_stg1_p3_o      => mem_p3_w,
			MULOp_o            => mem_MULOp_w,

			br_or_jump_taken_o => mem_brjmp_taken_w,
			Jalr_ctrl_o        => mem_jalr_ctrl_w,

			MemRead_o          => mem_MemRead_w,
			MemWrite_o         => mem_MemWrite_w,

			RegWrite_o         => mem_RegWrite_w,
			MemtoReg_o         => mem_MemtoReg_w,
			RegDst_o           => mem_RegDst_w,
			WBSrc_o            => mem_WBSrc_w
		);

	--========================================================================
	-- STAGE 4 : DTCM (data memory)
	--   Address = ALU result (sliced to DTCM address width). Store data = rs2.
	--========================================================================
	DMEM_inst : dmemory
		generic map (
			DATA_BUS_WIDTH  => DATA_BUS_WIDTH,
			DTCM_ADDR_WIDTH => DTCM_ADDR_WIDTH,
			WORDS_NUM       => DATA_WORDS_NUM
		)
		port map (
			clk_i           => clk_i,
			rst_i           => rst_i,
			dtcm_addr_i     => mem_alu_res_w(DTCM_ADDR_WIDTH+1 DOWNTO 2),
			dtcm_data_wr_i  => mem_read_data2_w,
			MemRead_ctrl_i  => mem_MemRead_w,
			MemWrite_ctrl_i => mem_MemWrite_w,
			mulop_i         => mem_MULOp_w,
			mul_stg1_p0_i   => mem_p0_w,
			mul_stg1_p1_i   => mem_p1_w,
			mul_stg1_p2_i   => mem_p2_w,
			mul_stg1_p3_i   => mem_p3_w,
			mul_result_o    => mem_mul_res_w,
			dtcm_data_rd_o  => mem_data_rd_w
		);

	--========================================================================
	-- MEM/WB pipeline register
	--========================================================================
	MEM_WB_inst : MEM_WB_REG
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH,
			PC_WIDTH       => PC_WIDTH
		)
		port map (
			clk_i       => mclk_w,
			rst_i       => rst_i,
			pc_plus4_i  => mem_pc_plus4_w,
			alu_res_i   => mem_alu_res_w,
			mem_data_i  => mem_data_rd_w,
			mul_res_i   => mem_mul_res_w,
			rd_i        => mem_rd_w,
			RegWrite_i  => mem_RegWrite_w,
			MemtoReg_i  => mem_MemtoReg_w,
			RegDst_i    => mem_RegDst_w,
			WBSrc_i     => mem_WBSrc_w,

			pc_plus4_o  => wb_pc_plus4_w,
			alu_res_o   => wb_alu_res_w,
			mem_data_o  => wb_mem_data_w,
			mul_res_o   => wb_mul_res_w,
			rd_o        => wb_rd_w,
			RegWrite_o  => wb_RegWrite_w,
			MemtoReg_o  => wb_MemtoReg_w,
			RegDst_o    => wb_RegDst_w,
			WBSrc_o     => wb_WBSrc_w
		);

	--========================================================================
	-- STAGE 5 : Write-back MUX (alu / mem / mul). PC+4 link added in IDECODE.
	--========================================================================
	WB_MUX_inst : WB_MUX
		generic map (
			PC_WIDTH       => PC_WIDTH,
			DATA_BUS_WIDTH => DATA_BUS_WIDTH
		)
		port map (
			alu_res_i        => wb_alu_res_w,
			mul_res_i        => wb_mul_res_w,
			mem_data_i       => wb_mem_data_w,
			WBSrc_ctrl_i     => wb_WBSrc_w,
			MemtoReg_ctrl_i  => wb_MemtoReg_w,
			writeback_data_o => wb_writeback_w
		);

	--========================================================================
	-- Forwarding Unit (compares ID/EX rs1/rs2 against EX/MEM and MEM/WB rd)
	--========================================================================
	FWD_inst : FORWARDING_UNIT
		port map (
			ID_EX_rs1_i       => ex_rs1_w,
			ID_EX_rs2_i       => ex_rs2_w,
			EX_MEM_rd_i       => mem_rd_w,
			EX_MEM_RegWrite_i => mem_RegWrite_w,
			MEM_WB_rd_i       => wb_rd_w,
			MEM_WB_RegWrite_i => wb_RegWrite_w,
			Forward_Ain_o     => fwd_Ain_w,
			Forward_Bin_o     => fwd_Bin_w
		);

	--========================================================================
	-- Stall Unit (load-use + mul-use interlock; compares ID/EX vs IF/ID)
	--========================================================================
	STALL_inst : STALL_UNIT
		port map (
			MemRead_i  => ex_MemRead_w,
			MULOp_i    => ex_MULOp_w,
			idex_rd_i  => ex_rd_w,
			ifid_rs1_i => id_rs1_w,
			ifid_rs2_i => id_rs2_w,
			Stall_o    => stall_w
		);

	--========================================================================
	-- Flush Unit (redirect taken; reads REGISTERED EX/MEM bits => stage-4)
	--========================================================================
	FLUSH_inst : FLUSH_UNIT
		port map (
			br_or_jump_taken_i => mem_brjmp_taken_w,
			Jalr_i             => mem_jalr_ctrl_w,
			flush_o            => flush_w
		);

	-----------------------------------------------------------------------------
	DBG_SHADOW : PROCESS(mclk_w)
	BEGIN
		IF (mclk_w'EVENT AND mclk_w = '1') THEN
			IF (rst_i = '1') THEN
				instr_id_q  <= NOP_INSTR;
				instr_ex_q  <= NOP_INSTR;
				instr_mem_q <= NOP_INSTR;
				instr_wb_q  <= NOP_INSTR;
				pc_ex_q     <= (OTHERS => '0');
				pc_mem_q    <= (OTHERS => '0');
				pc_wb_q     <= (OTHERS => '0');
			ELSE
				-- IF/ID shadow: same control as the real IF/ID register
				IF (flush_w = '1') THEN
					instr_id_q <= NOP_INSTR;
				ELSIF (ifid_ena_w = '1') THEN
					instr_id_q <= if_instruction_w;
				-- else hold (stall)
				END IF;

				-- ID/EX shadow: bubble on flush or stall, else advance
				IF (flush_w = '1' OR stall_w = '1') THEN
					instr_ex_q <= NOP_INSTR;
					pc_ex_q    <= (OTHERS => '0');
				ELSE
					instr_ex_q <= instr_id_q;
					pc_ex_q    <= id_pc_w;
				END IF;

				-- EX/MEM shadow: bubble on flush, else advance (EX/MEM not stalled)
				IF (flush_w = '1') THEN
					instr_mem_q <= NOP_INSTR;
					pc_mem_q    <= (OTHERS => '0');
				ELSE
					instr_mem_q <= instr_ex_q;
					pc_mem_q    <= pc_ex_q;
				END IF;

				-- MEM/WB shadow: always advances
				instr_wb_q <= instr_mem_q;
				pc_wb_q    <= pc_mem_q;
			END IF;
		END IF;
	END PROCESS;

	--========================================================================
	-- Figure-8 counters + Signal-Tap trigger
	--========================================================================
	INSTR_COUNTERS : PROCESS(mclk_w)
	BEGIN
		IF (mclk_w'EVENT AND mclk_w = '1') THEN
			IF (rst_i = '1') THEN
				clkcnt_q <= (OTHERS => '0');
				stcnt_q  <= (OTHERS => '0');
				fhcnt_q  <= (OTHERS => '0');
			ELSE
				clkcnt_q <= clkcnt_q + 1;                       -- counts every cycle
				IF (stall_w = '1' AND flush_w = '0') THEN
					stcnt_q <= stcnt_q + 1;                       -- count stall cycles
				END IF;
				IF (flush_w = '1') THEN
					fhcnt_q <= fhcnt_q + 1;                       -- count flush cycles
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- Signal-Tap trigger: IF-stage PC (word index) matches the breakpoint.
	strigger_w <= '1' WHEN (if_pc_w(PC_WIDTH-1 DOWNTO 2) = BPADDR_i) ELSE '0';

	--========================================================================
	-- Output assignments (Figure 8 taps)
	--========================================================================
	CLKCNT_o         <= clkcnt_q;
	STCNT_o          <= stcnt_q;
	FHCNT_o          <= fhcnt_q;
	STRIGGER_o       <= strigger_w;

	IFpc_o           <= if_pc_w;
	IFinstruction_o  <= if_instruction_w;
	IDpc_o           <= id_pc_w;
	IDinstruction_o  <= id_instruction_w;
	EXpc_o           <= pc_ex_q;
	EXinstruction_o  <= instr_ex_q;
	MEMpc_o          <= pc_mem_q;
	MEMinstruction_o <= instr_mem_q;
	WBpc_o           <= pc_wb_q;
	WBinstruction_o  <= instr_wb_q;

END structure;