
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.const_package.all;


ENTITY Idecode IS
	generic(
		PC_WIDTH 		: integer	:= 10;
		DATA_BUS_WIDTH	: integer := 32
	);
	PORT(
		--Inputs
		clk_i						: IN 	STD_LOGIC;
		rst_i						: IN 	STD_LOGIC;
		instruction_i 				: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		-- ---- Write-back interface (stage 5, all sourced from MEM/WB) ----
		RegDst_i 					: IN 	STD_LOGIC;		
		RegWrite_i					: IN 	STD_LOGIC;										-- MEM/WB.RegWrite_o : write enable
		rd_i						: IN 	STD_LOGIC_VECTOR(4 DOWNTO 0);			-- MEM/WB.rd_o      : write address
		writeback_data_i			: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- top-level WB MUX output

		pc_plus4_i					: IN 	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);			-- MEM/WB.pc_plus4_o : retiring JAL/JALR's link value (PC+4)
		--Outputs (read side, stage 2)
		read_data1_o				: OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o				: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		SignExt_o 					: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		rs1_o						: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		rs2_o						: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		rd_o						: OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
			);
END Idecode;


ARCHITECTURE behavior OF Idecode IS
TYPE register_file IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL RF_q							: register_file;
	SIGNAL pc_plus4_q					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- registered PC+4 (link value for JAL/JALR)
	SIGNAL opc_w						: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL rs1_w						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rs2_w						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rd_w						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	-- NOTE: rd is no longer sliced from instruction_i for the WRITE port.
	-- The instruction being written back in stage 5 is NOT the instruction
	-- in IF/ID; its rd travelled down the pipe and arrives on rd_i (MEM/WB).

	SIGNAL Iimm_w					: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL Simm_w					: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL SBimm_w					: STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL Uimm_w					: STD_LOGIC_VECTOR(19 DOWNTO 0);
	SIGNAL UJimm_w					: STD_LOGIC_VECTOR(19 DOWNTO 0);
	SIGNAL write_data_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL SignExt_Iimm_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_Simm_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_SBimm_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_Uimm_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_UJimm_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN
	opc_w		<= instruction_i(6 DOWNTO 0);

	rs1_w		<= instruction_i(19 DOWNTO 15);
	rs2_w		<= instruction_i(24 DOWNTO 20);
	rd_w		<= instruction_i(11 DOWNTO 7);

	Iimm_w 	<= instruction_i(31 DOWNTO 20);
	Simm_w 	<= instruction_i(31 DOWNTO 25) & instruction_i(11 DOWNTO 7);
	SBimm_w <= instruction_i(31) & instruction_i(7) & instruction_i(30 DOWNTO 25) & instruction_i(11 DOWNTO 8);
	Uimm_w 	<= instruction_i(31 DOWNTO 12);
	UJimm_w <= instruction_i(31) & instruction_i(19 DOWNTO 12) & instruction_i(20) & instruction_i(30 DOWNTO 21);

	-- Read the Register 1 output of the Register-File
	read_data1_o <= RF_q(CONV_INTEGER(rs1_w));

	-- Read the Register 2 output of the Register-File
	read_data2_o <= RF_q(CONV_INTEGER(rs2_w));

	-- ----------------------------------------------------------------------
	-- Write-back MUX REMOVED from here. It now lives at the top level (per
	-- Figure 7) and drives writeback_data_i. See WB_MUX.vhd / top entity.
	-- ----------------------------------------------------------------------

	-- Sign Extend 16-bits to 32-bits (UNCHANGED)
	SignExt_Iimm_w 	<=	ZEROS_IMM20 & Iimm_w 	WHEN	not Iimm_w(11) 	ELSE ONES_IMM20 & Iimm_w;
	SignExt_Simm_w 	<=	ZEROS_IMM20	& Simm_w 	WHEN 	not Simm_w(11)	ELSE ONES_IMM20 & Simm_w;
	SignExt_SBimm_w <=	ZEROS_IMM20	& SBimm_w WHEN 	not SBimm_w(11)	ELSE ONES_IMM20 & SBimm_w;
	SignExt_Uimm_w 	<=	ZEROS_IMM12 & Uimm_w 	WHEN 	not Uimm_w(19) 	ELSE ONES_IMM12 & Uimm_w;
	SignExt_UJimm_w	<=	ZEROS_IMM12 & UJimm_w WHEN 	not UJimm_w(19) ELSE ONES_IMM12 & UJimm_w;

----------------------------------------------------------------------
	with	opc_w select
		SignExt_o <=	SignExt_Iimm_w														when ITYPE_OPC,
									SignExt_Iimm_w														when "1100111",	-- JALR opcode (= INST_JALR(6:0)); literal for GHDL static-choice
									SignExt_Simm_w														when STYPE_OPC,
									SignExt_SBimm_w 													when SBTYPE_OPC,
									SignExt_Uimm_w(19 DOWNTO 0) & ZEROS_IMM12	when "0010111" | "0110111",	-- AUIPC | LUI
									SignExt_UJimm_w														when UJTYPE_OPC,
									(others => '0')														when others;
	
	-------------------------------------------	

	with RegDst_i select
		write_data_w <= (ZEROS_DBUS2PCADDR & pc_plus4_i)		when '1',	-- write-back from current instruction in IDECODE (R-type, I-type, etc.)
					writeback_data_i	when others;	-- write-back from previous instruction in EX/MEM or MEM/WB (store instructions write back rs2)			

	process(clk_i,rst_i)
	begin
		if (rst_i='1') then
			FOR i IN 0 TO 31 LOOP
				RF_q(i) <= CONV_STD_LOGIC_VECTOR(0,32);
			END LOOP;
		elsif (clk_i'event and clk_i='0') then
			if (RegWrite_i = '1' AND rd_i /= 0) then	-- RF(0) hard-wired of value zero
				RF_q(CONV_INTEGER(rd_i)) <= write_data_w;
				-- index type is integer so we must use conv_integer for type casting
			end if;
		end if;
	end process;


	rs1_o			<= rs1_w;			
	rs2_o			<= rs2_w;			
	rd_o			<= rd_w;
	
END behavior;
