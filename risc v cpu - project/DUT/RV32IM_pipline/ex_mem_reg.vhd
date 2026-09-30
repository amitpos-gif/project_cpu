
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.const_package.all;

ENTITY EX_MEM_REG IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH				: integer := 13
	);
	PORT(
		--Inputs
		clk_i					: IN	STD_LOGIC;
		rst_i					: IN	STD_LOGIC;

		flush_i					: IN	STD_LOGIC;	-- branch/jump taken in stage 4
		stall_i					: IN	STD_LOGIC;	-- load-use bubble request

		-- ---- Data from IDECODE (stage 2) ----
		pc_plus4_i				: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- PC+4 (link value for JAL/JALR)
		read_data1_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i			: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		imm32_i					: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		rs1_i					: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		rs2_i					: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		rd_i					: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		mul_stg1_p0_i			: IN	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p1_i			: IN	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p2_i			: IN	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p3_i			: IN	STD_LOGIC_VECTOR(15 DOWNTO 0);
		Alu_Res_i				: IN	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- from the ALU in EX stage, for JALR target and for forwarding
		Adder_gen_i		 	: IN	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- from the adder in EX stage, for branch target and for forwarding
		MULOp_i					: IN	STD_LOGIC;
		------------------ control to the flush or gate logic -------------------
		br_or_jump_taken_i		: IN	STD_LOGIC;
		Jalr_ctrl_i				: IN	STD_LOGIC;
	
		-- ---- M control bundle (consumed in stage 4) ----
		MemRead_i				: IN	STD_LOGIC;
		MemWrite_i				: IN	STD_LOGIC;

		-- ---- WB control bundle (consumed in stage 5) ----
		RegWrite_i				: IN	STD_LOGIC;
		MemtoReg_i				: IN	STD_LOGIC;
		RegDst_i				: IN	STD_LOGIC;
		WBSrc_i					: IN	STD_LOGIC;

		-- ---- Outputs to EXECUTE (stage 3) ----
		pc_plus4_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- PC+4 (link value for JAL/JALR)
		read_data1_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o			: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		imm32_o					: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		rs1_o					: OUT	STD_LOGIC_VECTOR(4 DOWNTO 0);
		rs2_o					: OUT	STD_LOGIC_VECTOR(4 DOWNTO 0);
		rd_o					: OUT	STD_LOGIC_VECTOR(4 DOWNTO 0);
		Alu_Res_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0); -- to JALR target and for forwarding
		Adder_gen_o				: OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0); -- to branch target and for forwarding
		------------------ mul output -------------------
		mul_stg1_p0_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p1_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p2_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);
		mul_stg1_p3_o			: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0);

		MULOp_o					: OUT	STD_LOGIC;
		
		br_or_jump_taken_o		: OUT	STD_LOGIC;
		Jalr_ctrl_o				: OUT	STD_LOGIC;

		MemRead_o				: OUT	STD_LOGIC;
		MemWrite_o				: OUT	STD_LOGIC;

		RegWrite_o				: OUT	STD_LOGIC;
		MemtoReg_o				: OUT	STD_LOGIC;
		RegDst_o				: OUT	STD_LOGIC;
		WBSrc_o					: OUT	STD_LOGIC
	);
END EX_MEM_REG;


ARCHITECTURE behavior OF EX_MEM_REG IS

		signal pc_plus4_q			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		signal read_data1_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		signal read_data2_q			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		signal imm32_q				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		signal rs1_q				: STD_LOGIC_VECTOR(4 DOWNTO 0);
		signal rs2_q				: STD_LOGIC_VECTOR(4 DOWNTO 0);
		signal rd_q					: STD_LOGIC_VECTOR(4 DOWNTO 0);
		------------------ mul output -------------------
		signal mul_stg1_p0_q			: STD_LOGIC_VECTOR(15 DOWNTO 0);
		signal mul_stg1_p1_q			: STD_LOGIC_VECTOR(15 DOWNTO 0);
		signal mul_stg1_p2_q			: STD_LOGIC_VECTOR(15 DOWNTO 0);
		signal mul_stg1_p3_q			: STD_LOGIC_VECTOR(15 DOWNTO 0);
		signal MULOp_q					: STD_LOGIC;
		SIGNAL Adder_gen_q				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		SIGNAL Alu_Res_q				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		
		signal br_or_jump_taken_q		: STD_LOGIC;
		signal Jalr_ctrl_q				: STD_LOGIC;

		signal MemRead_q				: STD_LOGIC;
		signal MemWrite_q				: STD_LOGIC;

		signal RegWrite_q				: STD_LOGIC;
		signal MemtoReg_q				: STD_LOGIC;
		signal RegDst_q					: STD_LOGIC;
		signal WBSrc_q					: STD_LOGIC;

BEGIN
	
	PROCESS(clk_i)
	BEGIN
		IF (clk_i'EVENT AND clk_i = '1') THEN
			IF (rst_i = '1') THEN
				-- Synchronous reset: clear to NOP (highest priority)
			pc_plus4_q			<= (OTHERS => '0');
			read_data1_q		<= (OTHERS => '0');
			read_data2_q		<= (OTHERS => '0');
			imm32_q				<= (OTHERS => '0');
			rs1_q				<= (OTHERS => '0');
			rs2_q				<= (OTHERS => '0');
			rd_q				<= (OTHERS => '0');
			mul_stg1_p0_q		<= (OTHERS => '0');
			mul_stg1_p1_q		<= (OTHERS => '0');
			mul_stg1_p2_q		<= (OTHERS => '0');
			mul_stg1_p3_q		<= (OTHERS => '0');
			Alu_Res_q			<= (OTHERS => '0');
			Adder_gen_q			<= (OTHERS => '0');
			MULOp_q				<= '0';
			br_or_jump_taken_q		<= '0';
			Jalr_ctrl_q				<= '0';
			MemRead_q				<= '0';
			MemWrite_q				<= '0';
			RegWrite_q				<= '0';
			MemtoReg_q				<= '0';
			RegDst_q				<= '0';
			WBSrc_q					<= '0';	

			ELSIF (flush_i = '1') THEN
				pc_plus4_q			<= (OTHERS => '0');
				read_data1_q		<= (OTHERS => '0');
				read_data2_q		<= (OTHERS => '0');
				imm32_q				<= (OTHERS => '0');
				rs1_q				<= (OTHERS => '0');
				rs2_q				<= (OTHERS => '0');
				rd_q				<= (OTHERS => '0');
				mul_stg1_p0_q		<= (OTHERS => '0');
				mul_stg1_p1_q		<= (OTHERS => '0');
				mul_stg1_p2_q		<= (OTHERS => '0');
				mul_stg1_p3_q		<= (OTHERS => '0');
				Alu_Res_q			<= (OTHERS => '0');
				Adder_gen_q			<= (OTHERS => '0');
				MULOp_q				<= '0';
				br_or_jump_taken_q		<= '0';
				Jalr_ctrl_q				<= '0';
				MemRead_q				<= '0';
				MemWrite_q				<= '0';
				RegWrite_q				<= '0';
				MemtoReg_q				<= '0';
				RegDst_q				<= '0';
				WBSrc_q					<= '0';

			ELSE
				-- Normal operation: latch everything Decode produced
				pc_plus4_q			<= pc_plus4_i;
				read_data1_q		<= read_data1_i;
				read_data2_q		<= read_data2_i;
				imm32_q				<= imm32_i;
				rs1_q				<= rs1_i;
				rs2_q				<= rs2_i;
				rd_q				<= rd_i;
				mul_stg1_p0_q		<= mul_stg1_p0_i;
				mul_stg1_p1_q		<= mul_stg1_p1_i;
				mul_stg1_p2_q		<= mul_stg1_p2_i;
				mul_stg1_p3_q		<= mul_stg1_p3_i;
				Alu_Res_q			<= Alu_Res_i;
				Adder_gen_q			<= Adder_gen_i;
				MULOp_q				<= MULOp_i;
				br_or_jump_taken_q		<= br_or_jump_taken_i;
				Jalr_ctrl_q				<= Jalr_ctrl_i;
				MemRead_q				<= MemRead_i;
				MemWrite_q				<= MemWrite_i;
				RegWrite_q				<= RegWrite_i;
				MemtoReg_q				<= MemtoReg_i;
				RegDst_q				<= RegDst_i;
				WBSrc_q					<= WBSrc_i;

			END IF;
		END IF;
	END PROCESS;

	pc_plus4_o			<= pc_plus4_q;
	read_data1_o			<= read_data1_q;
	read_data2_o			<= read_data2_q;
	imm32_o					<= imm32_q;
	rs1_o					<= rs1_q;
	rs2_o					<= rs2_q;
	rd_o					<= rd_q;
	------------------ mul output -------------------
	mul_stg1_p0_o			<= mul_stg1_p0_q;
	mul_stg1_p1_o			<= mul_stg1_p1_q;
	mul_stg1_p2_o			<= mul_stg1_p2_q;
	mul_stg1_p3_o			<= mul_stg1_p3_q;
	Alu_Res_o				<= Alu_Res_q;
	Adder_gen_o				<= Adder_gen_q;
	MULOp_o					<= MULOp_q;
	
	br_or_jump_taken_o		<= br_or_jump_taken_q;
	Jalr_ctrl_o				<= Jalr_ctrl_q;

	MemRead_o				<= MemRead_q;
	MemWrite_o				<= MemWrite_q;

	RegWrite_o				<= RegWrite_q;
	MemtoReg_o				<= MemtoReg_q;
	RegDst_o				<= RegDst_q;
	WBSrc_o					<= WBSrc_q;

END behavior;