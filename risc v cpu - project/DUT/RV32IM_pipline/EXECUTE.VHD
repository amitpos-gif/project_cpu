
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;
USE work.aux_package.all;


ENTITY  Execute IS
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
END Execute;


ARCHITECTURE struct OF Execute IS
	SIGNAL 	ain_w 					: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	bin_w 					: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	ain_pre_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- before forwarding override
	SIGNAL 	bin_pre_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- before forwarding override
	SIGNAL	fwd_rs2_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- forwarded rs2 value
	SIGNAL 	sub_res_w 				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL 	ltu_res_w 				: STD_LOGIC;
	SIGNAL 	eq_res_w				: STD_LOGIC;
	SIGNAL	msbneq_res_w			: STD_LOGIC;
	SIGNAL	alu_res_r 				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brTaken_w 				: STD_LOGIC;
	signal 	br_or_jump_taken_w		: STD_LOGIC;
	signal  Jalr_ctrl_w				: STD_LOGIC;
	SIGNAL  mulop7_w				: STD_LOGIC_VECTOR(6 DOWNTO 0);
	
	SIGNAL	brl_shl_s1_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s2_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s3_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shl_s4_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	
	SIGNAL	brl_shr_s1_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s2_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s3_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_s4_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL	brl_shr_pad_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	
		
BEGIN
--------------------------------------------------------------------------------------------------------
-- Branch Address Adder
-- addr_gen_o = pc_i + (sign_extend_i << 1)
--------------------------------------------------------------------------------------------------------					  
adder_gen_o	<= pc_i(PC_WIDTH-1 DOWNTO 0) + (sign_extend_i(PC_WIDTH-3 DOWNTO 0) & '0');

--------------------------------------------------------------------------------------------------------
--ALU
--------------------------------------------------------------------------------------------------------
-- ain_pre_w / bin_pre_w: UNCHANGED from the single-cycle version's logic --
-- this is the original RF/PC/zero selection (for ain) and RF/immediate
-- selection (for bin). Forwarding is only ever meaningful for the
-- read_data1_i/read_data2_i (RF) cases -- it makes no sense to forward
-- into a PC value, an immediate, or a hardcoded zero, since those never
-- depend on a register a previous instruction might still be computing.
WITH UpperIm_ctrl_i SELECT
	ain_pre_w <= 	read_data1_i														WHEN	"00",
								((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & pc_i	WHEN	"01",
								(others => '0')	WHEN	OTHERS;
	
bin_pre_w <= 	read_data2_i	WHEN not ALUSrc_ctrl_i ELSE	sign_extend_i(DATA_BUS_WIDTH-1 DOWNTO 0);

WITH Forward_Ain_i SELECT
	ain_w <= 	ain_pre_w							WHEN	"00",
						exmem_fwd_val_i				WHEN	"10",
						memwb_fwd_val_i				WHEN	"01",
						ain_pre_w							WHEN	OTHERS;

-- fwd_rs2_w: forwarded rs2 value (used as store data and as ALU-B when ALUSrc=0)
WITH Forward_Bin_i SELECT
	fwd_rs2_w <= read_data2_i    WHEN "00",
	             exmem_fwd_val_i WHEN "10",
	             memwb_fwd_val_i WHEN "01",
	             read_data2_i    WHEN OTHERS;

-- bin_w: when ALUSrc=1 (SW/LW/ADDI/etc.) always use the sign-extended immediate
-- so that Forward_Bin never corrupts the store/load address calculation.
-- When ALUSrc=0 (R-type, branches) use the forwarded rs2 for the ALU.
bin_w <= sign_extend_i(DATA_BUS_WIDTH-1 DOWNTO 0) WHEN ALUSrc_ctrl_i = '1' ELSE fwd_rs2_w;

mulop7_w <= (others => '0') WHEN mulop_i = '0' ELSE "0000001"; -- 1 for MUL, 0 for no MUL

mulop_o <= mulop_i;

MUL1_inst : Mul_Stage1
		generic map (
			DATA_BUS_WIDTH => DATA_BUS_WIDTH
		)
		port map (
			Ain   => ain_w,
			Bin   => bin_w,
			MULOP => mulop7_w,
			P0_o  => ex_mul_stg1_p0_o,
			P1_o  => ex_mul_stg1_p1_o,
			P2_o  => ex_mul_stg1_p2_o,
			P3_o  => ex_mul_stg1_p3_o
		);


--Reused resuls 
sub_res_w			<= ain_w - bin_w;
ltu_res_w			<= '1' WHEN ( (msbneq_res_w = '1' and bin_w(31) = '1') or (msbneq_res_w = '0' and sub_res_w(31) = '1') ) ELSE '0';
eq_res_w			<= '1' WHEN ain_w = bin_w 					ELSE '0'; 
msbneq_res_w	<= '1' WHEN ain_w(31) /= bin_w(31) 	ELSE '0';

	

PROCESS (all)
BEGIN
	-- default values
	alu_res_r 		<= (others => '0');
	brTaken_w 		<= '0';
	brl_shl_s1_r	<= (others => '0');
	brl_shl_s2_r	<= (others => '0');
	brl_shl_s3_r	<= (others => '0'); 
	brl_shl_s4_r	<= (others => '0');
	brl_shr_s1_r	<= (others => '0');
	brl_shr_s2_r	<= (others => '0');
	brl_shr_s3_r	<= (others => '0'); 
	brl_shr_s4_r	<= (others => '0');
	brl_shr_pad_r	<= (others => '0');
	
	
 	CASE ALUOp_ctrl_i IS	-- Select ALU operation
		------------------------------------------------------
    -- Arithmetic
    ------------------------------------------------------
		-- add, addi, auipc, jal, jalr
		WHEN ALU_ADD 	=>
			alu_res_r	<= ain_w + bin_w;
			brTaken_w	<= '0';
		
		-- sub
		WHEN ALU_SUB	=>
			alu_res_r	<= sub_res_w;		 
			brTaken_w	<= '0';
		------------------------------------------------------
    -- Logic
    ------------------------------------------------------
		-- and, andi	
    WHEN	ALU_AND 	=>
			alu_res_r	<= ain_w and bin_w;
			brTaken_w	<= '0';
		
		-- or, ori		
	 	WHEN ALU_OR	=>
			alu_res_r	<= ain_w or bin_w;
			brTaken_w	<= '0';
		
		-- xor, xori
		WHEN ALU_XOR 	=>
			alu_res_r	<= ain_w xor bin_w;
			brTaken_w	<= '0';
				
		------------------------------------------------------
    -- Shift Left
    ------------------------------------------------------
		-- sll, slli
 	 	WHEN ALU_SHIFTL	=>
			-- Barrel-Shifter SHL stage 0
			if (bin_w(0) = '1') then
				brl_shl_s1_r <= (ain_w(30 DOWNTO 0) & '0');
			else
				brl_shl_s1_r <= ain_w;
			end if;
					
			-- Barrel-Shifter SHL stage 1
			if (bin_w(1) = '1') then
				brl_shl_s2_r <= (brl_shl_s1_r(29 DOWNTO 0) & "00");
			else
				brl_shl_s2_r <= brl_shl_s1_r;
			end if;
					
			-- Barrel-Shifter SHL stage 2
			if (bin_w(2) = '1')	then
				brl_shl_s3_r <= (brl_shl_s2_r(27 DOWNTO 0) & "0000");
			else
				brl_shl_s3_r <= brl_shl_s2_r;
			end if;
					
			-- Barrel-Shifter SHL stage 3
			if (bin_w(3) = '1')	then
				brl_shl_s4_r <= (brl_shl_s3_r(23 DOWNTO 0) & "00000000");
			else
				brl_shl_s4_r <= brl_shl_s3_r;
			end if;
					
			-- Barrel-Shifter SHL stage 4
			if (bin_w(4) = '1')	then
				alu_res_r <= (brl_shl_s4_r(15 DOWNTO 0) & "0000000000000000");
			else
				alu_res_r <= brl_shl_s4_r;
			end if;
				      
			brTaken_w	<= '0';
		------------------------------------------------------
    -- Shift Right
    ------------------------------------------------------		
		-- srl, srli, sra, srai	
 	 	WHEN ALU_SHIFTR | ALU_SHIFTR_ARITH 	=>
			--if sra? pad with 1's else pad with 0's 
			if (ain_w(31) = '1' and (ALUOp_ctrl_i = ALU_SHIFTR_ARITH)) then
				brl_shr_pad_r <= 32x"FFFF";
			else
				brl_shr_pad_r <= 32x"0000";
			end if;
			
			-- Barrel-Shifter SHR stage 0
			if (bin_w(0) = '1') then
				brl_shr_s1_r <= (brl_shr_pad_r(31) & ain_w(31 DOWNTO 1));
			else
				brl_shr_s1_r <= ain_w;
			end if;
			
			-- Barrel-Shifter SHR stage 1
			if (bin_w(1) = '1') then
				brl_shr_s2_r <= (brl_shr_pad_r(31 DOWNTO 30) & brl_shr_s1_r(31 DOWNTO 2));
			else
				brl_shr_s2_r <= brl_shr_s1_r;
			end if;
			
			-- Barrel-Shifter SHR stage 2
			if (bin_w(2) = '1') then
				brl_shr_s3_r <= (brl_shr_pad_r(31 DOWNTO 28) & brl_shr_s2_r(31 DOWNTO 4));
			else
				brl_shr_s3_r <= brl_shr_s2_r;
			end if;
			
			-- Barrel-Shifter SHR stage 3
			if (bin_w(3) = '1') then
				brl_shr_s4_r <= (brl_shr_pad_r(31 DOWNTO 24) & brl_shr_s3_r(31 DOWNTO 8));
			else
				brl_shr_s4_r <= brl_shr_s3_r;
			end if;
			
			-- Barrel-Shifter SHR stage 4
			if (bin_w(4) = '1')	then
				alu_res_r <= (brl_shr_pad_r(31 DOWNTO 16) & brl_shr_s4_r(31 DOWNTO 16));
			else
				alu_res_r <= brl_shr_s4_r;
			end if;
				   
			brTaken_w	<= '0';		 	 				
		------------------------------------------------------
    -- Comparision
    ------------------------------------------------------
		-- slt, slti
		WHEN ALU_LESS_THAN_SIGNED	=>
			brTaken_w	<= '0';
			IF msbneq_res_w THEN
				IF ain_w(31) THEN
					alu_res_r	<= (0 => '1', others => '0');	--32'h1
				ELSE
					alu_res_r	<= (others => '0');						--32'h0
				END IF;
			ELSE
				IF sub_res_w(31) THEN
					alu_res_r	<= (0 => '1', others => '0');	--32'h1	
				ELSE
					alu_res_r	<= (others => '0');						--32'h0
				END IF;
			END IF;
		
		-- sltu, sltiu 
		WHEN ALU_LESS_THAN_UNSIGNED	=>
			brTaken_w	<= '0';
			IF ltu_res_w THEN
				alu_res_r	<= (0 => '1', others => '0');		--32'h1
			ELSE
				alu_res_r	<= (others => '0');							--32'h0
			END IF;

		------------------------------------------------------
    -- Condional Branch 
    ------------------------------------------------------
		-- beq
		WHEN ALU_BEQ	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= eq_res_w;
		
		-- bne
		WHEN ALU_BNE	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= not eq_res_w;
		
		-- blt
		WHEN ALU_BLT	=>
			alu_res_r	<= (others => '0');
			IF msbneq_res_w THEN
				brTaken_w	<= ain_w(31);
			ELSE
				brTaken_w	<= sub_res_w(31);
			END IF;
		
		-- bge
		WHEN ALU_BGE	=>
			alu_res_r	<= (others => '0');
			IF msbneq_res_w THEN
				brTaken_w	<= bin_w(31);
			ELSE
				brTaken_w	<= not sub_res_w(31);
			END IF;
		
		-- bltu
		WHEN ALU_BLTU	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= ltu_res_w;
		
		-- bgeu
		WHEN ALU_BGEU	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= not ltu_res_w;
		
 	 	WHEN OTHERS	=>
			alu_res_r	<= (others => '0');
			brTaken_w	<= '0';
			
  END CASE;
		
END PROCESS;
	
--------------------------------------------------------------------------------------------------------
alu_res_o	<= alu_res_r;
jalr_ctrl_w	 <= Jalr_ctrl_i;
jalr_ctrl_o 	<= jalr_ctrl_w ;
br_or_jump_taken_o	<= (Branch_ctrl_i AND brTaken_w) OR Jal_ctrl_i ; ---AND OA BAFORE SIGNAL AS AN INPT TO THE REGIDTER EX/MEM BEFORE FLADH

END struct;