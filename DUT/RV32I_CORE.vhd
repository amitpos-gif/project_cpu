--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Top Level Structural Model for Single-Cycle RISC-V Core
---============================================================================ 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.const_package.all;
USE work.aux_package.all;


ENTITY RV32I_CORE IS
    generic( 
            WORD_GRANULARITY    : boolean   := G_WORD_GRANULARITY;
        MODELSIM                : integer   := G_MODELSIM;
            DATA_BUS_WIDTH      : integer   := 32;
            ITCM_ADDR_WIDTH     : integer   := G_ADDRWIDTH;
            DTCM_ADDR_WIDTH     : integer   := G_ADDRWIDTH;
            PC_WIDTH            : integer   := G_PC_WIDTH;
            MA_WIDTH            : integer   := G_MA_WIDTH;
            DATA_WORDS_NUM      : integer   := G_DATA_WORDSNUM;
            CLK_CNT_WIDTH       : integer   := 16
    );
    PORT(   
        --Inputs
        rst_i                   :IN STD_LOGIC;
        clk_i                   :IN STD_LOGIC;
        divclk_i                :IN STD_LOGIC;
        dtcm_data_rd_i          :IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        INTR_i                  :IN STD_LOGIC;
        
        --Outputs (used also for Signal-Tap auxiliary pins)
        pc_o                    :OUT    STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        instruction_o           :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        
        RegWrite_ctrl_o         :OUT    STD_LOGIC;
        MemWrite_ctrl_o         :OUT    STD_LOGIC;
        MemRead_ctrl_o          :OUT    STD_LOGIC;
        Branch_ctrl_o           :OUT    STD_LOGIC;
        
        read_data1_o            :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        read_data2_o            :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        write_data_o            :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        
        alu_res_o               :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);                                                            
        brTaken_o               :OUT    STD_LOGIC; 
        
        dtcm_addr_o             :OUT    STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
        dtcm_data_wr_o          :OUT    STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        dtcm_data_rd_o          :OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        
        mclk_cnt_o              :OUT    STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
        INTA_o                  :OUT STD_LOGIC;
        GIE_o                   :OUT STD_LOGIC
    );      
END RV32I_CORE;
--============================================================================
ARCHITECTURE structure OF RV32I_CORE IS
    -- declare signals used to connect VHDL components
    SIGNAL pc_w                 : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL pc_plus4_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL read_data1_w         : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL read_data2_w         : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL sign_extend_w        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL addr_gen_w           : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
    SIGNAL alu_res_w            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL dtcm_data_rd_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL dtcm_addr_w          : STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
    SIGNAL alu_src_w            : STD_LOGIC;
    SIGNAL branch_w             : STD_LOGIC;
    SIGNAL Jal_ctrl_w           : STD_LOGIC;
    SIGNAL Jalr_ctrl_w          : STD_LOGIC;
    SIGNAL reg_write_ctrl_w     : STD_LOGIC;
    SIGNAL reg_write_w          : STD_LOGIC;
    SIGNAL reg_dst_w            : STD_LOGIC;
    SIGNAL brTaken_w            : STD_LOGIC;
    SIGNAL mem_write_w          : STD_LOGIC;
    SIGNAL MemtoReg_w           : STD_LOGIC;
    SIGNAL mem_read_w           : STD_LOGIC;
    SIGNAL upper_im_w           : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL alu_op_w             : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL instruction_w        : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL mclk_w               : STD_LOGIC;
    SIGNAL mclk_cnt_q           : STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
    -- #RV32IM task: MUL internal wires
    SIGNAL mul_op_w             : STD_LOGIC;  -- MULOp enable from CONTROL to MUL
    SIGNAL wb_src0_w            : STD_LOGIC;
    SIGNAL wb_src1_w            : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL mul_res_w            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- MUL result to IDECODE
    -- Divider datapath and control signals
    SIGNAL div_op_w             : STD_LOGIC;
    SIGNAL pc_hold_ctrl_w       : STD_LOGIC;
    SIGNAL pc_hold_w            : STD_LOGIC;
    SIGNAL div_ain_w            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL div_bin_w            : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    -- MCLK source registers shorten the CDC path into the DIVCLK synchronizer.
    SIGNAL div_operand1_m_q : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL div_operand2_m_q : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL quotient_w           : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL remainder_w          : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL div_busy_w           : STD_LOGIC;
    SIGNAL div_stall_w          : STD_LOGIC;
    SIGNAL div_stage_q          : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL div_rst_q            : STD_LOGIC;
    SIGNAL div_ena_q            : STD_LOGIC;
    SIGNAL accelerator_res_w    : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL execution_res_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL is_io_addr_w         : STD_LOGIC;
    SIGNAL dtcm_write_w         : STD_LOGIC;
    SIGNAL wb_dtcm_data_w       : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    -- Interrupt protocol datapath/control signals
    SIGNAL irq_hold_w           : STD_LOGIC;
    SIGNAL irq_service_w        : STD_LOGIC;
    SIGNAL irq_type_w           : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL irq_type_addr_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL gie_clear_w          : STD_LOGIC;
    SIGNAL gie_set_w            : STD_LOGIC;
    SIGNAL gie_w                : STD_LOGIC;
    SIGNAL inta_w               : STD_LOGIC;
    SIGNAL data_addr_w          : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL ifetch_target_w      : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
    SIGNAL ifetch_jalr_w        : STD_LOGIC;

    CONSTANT DIV_IDLE_C         : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
    CONSTANT DIV_LOAD_C         : STD_LOGIC_VECTOR(2 DOWNTO 0) := "001";
    CONSTANT DIV_START_BUSY_C   : STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
    CONSTANT DIV_WAIT_DONE_C    : STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
    CONSTANT DIV_COMPLETE_C     : STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";

BEGIN
    
    --=======================================
    -- PLL module connection
    --=======================================
    G0:
    if (MODELSIM = 0) generate
      MCLK: PLL
        PORT MAP (
            inclk0  => clk_i,
            c0      => mclk_w
        );
    else generate
        mclk_w <= clk_i;
    end generate;
    --===========================================
    -- IFETCH (including ITCM) module connection
    --===========================================
    IFE : Ifetch
    generic map(
        WORD_GRANULARITY    =>  WORD_GRANULARITY,
        DATA_BUS_WIDTH      =>  DATA_BUS_WIDTH, 
        PC_WIDTH                    =>  PC_WIDTH,
        ITCM_ADDR_WIDTH     =>  ITCM_ADDR_WIDTH,
        WORDS_NUM                   =>  DATA_WORDS_NUM
    )
    PORT MAP (
        --Inputs
        clk_i                   => mclk_w,  
        rst_i                   => rst_i, 
        PChold_i                => pc_hold_w,
        addr_gen_i          => addr_gen_w,
        Branch_ctrl_i   => branch_w,
        brTaken_i               => brTaken_w,
        Jal_ctrl_i          => Jal_ctrl_w,
        Jalr_ctrl_i         => ifetch_jalr_w,
        alu_res_i               => ifetch_target_w,
        
        --Outputs
        pc_o                        => pc_w,
        pc_plus4_o          => pc_plus4_w,
        instruction_o   => instruction_w    
    );
    --=======================================
    -- IDECODE module connection
    --=======================================
    ID : Idecode
  generic map(
        PC_WIDTH                =>  PC_WIDTH,
        DATA_BUS_WIDTH  =>  DATA_BUS_WIDTH
    )
    PORT MAP (  
        --Inputs
        clk_i                   => mclk_w,  
        rst_i                   => rst_i,
        pc_plus4_i          => pc_plus4_w,
    instruction_i   => instruction_w,
    dtcm_data_rd_i  => wb_dtcm_data_w,
        alu_res_i           => alu_res_w,
        RegDst_ctrl_i       => reg_dst_w,
        RegWrite_ctrl_i => reg_write_w,
        MemtoReg_ctrl_i => MemtoReg_w,
        -- Cascaded write-back mux controls and accelerator results
        WBSrc0_ctrl_i   => wb_src0_w,
        WBSrc1_ctrl_i   => wb_src1_w,
        mul_res_i       => mul_res_w,
        quotient_i          => quotient_w,
        rem_i                   => remainder_w,
        IRQ_clear_gie_i => gie_clear_w,
        IRQ_set_gie_i   => gie_set_w,
        IRQ_save_tp_i   => irq_service_w,
        IRQ_return_pc_i => pc_w,
        
        --Outputs
        read_data1_o        => read_data1_w,
        read_data2_o        => read_data2_w,
        SignExt_o           => sign_extend_w,
        GIE_o           => gie_w
    );
    --=======================================
    -- CONTROL module connection
    --=======================================
    CTL:   control
    PORT MAP (  
        --Inputs
        clk_i                 => mclk_w,
        rst_i                 => rst_i,
        instruction_i       => instruction_w,
        DIVbusy_ctrl_i      => div_busy_w,
        DIVstall_ctrl_i       => div_stall_w,
        INTR_ctrl_i           => INTR_i,
        TYPEdata_ctrl_i       => dtcm_data_rd_i(7 DOWNTO 0),
        
        --Outputs
        RegDst_ctrl_o           => reg_dst_w,
        ALUSrc_ctrl_o       => alu_src_w,
        MemtoReg_ctrl_o     => MemtoReg_w,
        RegWrite_ctrl_o     => reg_write_ctrl_w,
        MemRead_ctrl_o      => mem_read_w,
        MemWrite_ctrl_o     => mem_write_w,
        Branch_ctrl_o       => branch_w,
        Jal_ctrl_o              => Jal_ctrl_w,
        Jalr_ctrl_o             => Jalr_ctrl_w,
        UpperIm_ctrl_o      => upper_im_w,
        ALUOp_ctrl_o            => alu_op_w,
        -- Multiplier/divider and write-back controls
        MULOp_ctrl_o            => mul_op_w,
        DIVOp_ctrl_o            => div_op_w,
        PChold_ctrl_o       => pc_hold_ctrl_w,
        WBSrc0_ctrl_o       => wb_src0_w,
        WBSrc1_ctrl_o       => wb_src1_w,
        INTA_ctrl_o           => inta_w,
        IRQhold_ctrl_o        => irq_hold_w,
        IRQservice_ctrl_o     => irq_service_w,
        IRQtype_ctrl_o        => irq_type_w,
        GIEclear_ctrl_o       => gie_clear_w,
        GIEset_ctrl_o         => gie_set_w
    );

    -- Stall immediately on decode and keep the instruction until the complete stage. This covers the delay before synchronized DIVBUSY becomes high.
    div_stall_w <= '0' WHEN div_stage_q = DIV_COMPLETE_C ELSE div_op_w;
    pc_hold_w  <= pc_hold_ctrl_w OR div_stall_w OR irq_hold_w;
    reg_write_w <= reg_write_ctrl_w AND NOT div_stall_w;

    -- Cycle 2 reuses the existing JALR input of IFETCH.  The target is the
    -- handler address read from the vector table at Memory[TYPE].
    -- " FAKE " JALR when interrupt service cycle 2.
    ifetch_jalr_w   <= Jalr_ctrl_w OR irq_service_w;
    ifetch_target_w <= dtcm_data_rd_w WHEN irq_service_w = '1' ELSE alu_res_w;  
    --=======================================
    -- EXECUTE module connection
    --=======================================
    EXE:  Execute
  generic map(
        DATA_BUS_WIDTH  =>  DATA_BUS_WIDTH,
        PC_WIDTH                =>  PC_WIDTH
    )
    PORT MAP (  
        --Inputs
        read_data1_i        => read_data1_w,
    read_data2_i        => read_data2_w,
        sign_extend_i   => sign_extend_w,
        UpperIm_ctrl_i  => upper_im_w,
        ALUOp_ctrl_i        => alu_op_w,
        ALUSrc_ctrl_i   => alu_src_w,
        pc_i                        => pc_w,
        
        --Outputs
        brTaken_o           => brTaken_w,
    alu_res_o               => alu_res_w,
        addr_gen_o          => addr_gen_w           
    );
    --=======================================
    -- #RV32IM task: MUL module connection
    -- Receives read_data1/2 directly from register file (parallel to ALU)
    -- MULOp enable from CONTROL, result goes to IDECODE write-back MUX
    --=======================================
    MUL_INST: MUL
    GENERIC MAP(
        DATA_BUS_WIDTH => DATA_BUS_WIDTH
    )
    PORT MAP(
        ain_i     => read_data1_w(15 DOWNTO 0),
        bin_i     => read_data2_w(15 DOWNTO 0),
        MULOp_i   => mul_op_w,
        mul_res_o => mul_res_w
    );

    --=======================================
    -- Divider operand synchronizer (Figure 10b)
    --=======================================
    DIV_SYNC_INST: sync
    GENERIC MAP(
        DATA_BUS_WIDTH => DATA_BUS_WIDTH
    )
    PORT MAP(
        read_data1_i => div_operand1_m_q,
        read_data2_i => div_operand2_m_q,
        divclk_i     => divclk_i,
        rst_i        => rst_i,
        ain_o        => div_ain_w,
        bin_o        => div_bin_w
    );

    -- Five-stage divider controller in the CPU clock domain:
    -- idle, load/reset, start+wait-busy, wait-done, complete/write-back.
    -- DIVRST and DIVENA are held for complete MCLK stages, so the faster DIVCLK
    -- samples them safely. DIVENA and waiting for BUSY high share one stage.
    PROCESS(mclk_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            div_stage_q      <= DIV_IDLE_C;
            div_operand1_m_q <= (OTHERS => '0');
            div_operand2_m_q <= (OTHERS => '0');
        ELSIF rising_edge(mclk_w) THEN
            CASE div_stage_q IS
                WHEN DIV_IDLE_C =>
                    IF div_op_w = '1' THEN
                        -- Capture both operands in the source clock domain before CDC.
                        div_operand1_m_q <= read_data1_w;
                        div_operand2_m_q <= read_data2_w;
                        div_stage_q      <= DIV_LOAD_C;
                    END IF;

                WHEN DIV_LOAD_C =>
                    div_stage_q <= DIV_START_BUSY_C;

                WHEN DIV_START_BUSY_C =>
                    IF div_busy_w = '1' THEN
                        div_stage_q <= DIV_WAIT_DONE_C;
                    END IF;

                WHEN DIV_WAIT_DONE_C =>
                    IF div_busy_w = '0' THEN
                        div_stage_q <= DIV_COMPLETE_C;
                    END IF;

                WHEN DIV_COMPLETE_C =>
                    div_stage_q <= DIV_IDLE_C;

                WHEN OTHERS =>
                    div_stage_q <= DIV_IDLE_C;
            END CASE;
        END IF;
    END PROCESS;

    -- Synchronous divider load/start controls. Global reset also asserts
    -- DIVRST so the divider's internal registers are initialized at power-up.
    div_rst_q <= '1' WHEN rst_i = '1' OR div_stage_q = DIV_LOAD_C ELSE '0';
    div_ena_q <= '1' WHEN div_stage_q = DIV_START_BUSY_C ELSE '0';

    --=======================================
    -- Unsigned multicycle divider (Figure 9)
    --=======================================
    DIV_INST: divider_accelerator
    GENERIC MAP(
        DATA_BUS_WIDTH => DATA_BUS_WIDTH,
        N              => DATA_BUS_WIDTH
    )
    PORT MAP(
        ain_i      => div_ain_w,
        bin_i      => div_bin_w,
        divclk_i   => divclk_i,
        divrst_i   => div_rst_q,
        divena_i   => div_ena_q,
        quotient_o => quotient_w,
        rem_o      => remainder_w,
        divbusy_o  => div_busy_w
    );

    --=======================================
    -- DTCM module connection
    --=======================================
    -- During interrupt cycle 2, TYPE is the byte address of the vector-table entry - that is actialy in the main DTCM adress. 
    -- Otherwise the ordinary ALU result supplies the data address.
    irq_type_addr_w <= (DATA_BUS_WIDTH-1 DOWNTO 8 => '0') & irq_type_w;
    data_addr_w     <= irq_type_addr_w WHEN irq_service_w = '1' ELSE alu_res_w;

    G1: 
    if (WORD_GRANULARITY = True) generate -- i.e. each WORD has a unike address
        dtcm_addr_w <= data_addr_w(MA_WIDTH-1 DOWNTO 2); -- increment memory address by 4;
    elsif (WORD_GRANULARITY = False) generate -- i.e. each BYTE has a unike address
        dtcm_addr_w <= data_addr_w(MA_WIDTH-1 DOWNTO 0);
    end generate;

    -- Address bit MA_WIDTH selects the peripheral region. An I/O store must
    -- not alias into DTCM, and an I/O load returns the external bus data.
    is_io_addr_w   <= data_addr_w(MA_WIDTH);-- a13= 0 = dtcm, a13 = 1 = gpio
    dtcm_write_w   <= mem_write_w AND NOT is_io_addr_w; --if a13 = 1, not makes 0 and then dtcm wrtie is 0
    wb_dtcm_data_w <= dtcm_data_rd_i WHEN is_io_addr_w = '1' ELSE dtcm_data_rd_w;
    
    MEM:  dmemory
    generic map(
        DATA_BUS_WIDTH      =>  DATA_BUS_WIDTH, 
        DTCM_ADDR_WIDTH     =>  DTCM_ADDR_WIDTH,
        WORDS_NUM                   =>  DATA_WORDS_NUM
    )
    PORT MAP (  
        --Inputs
        clk_i                       => mclk_w,  
        rst_i                       => rst_i,
        dtcm_addr_i             => dtcm_addr_w,
        dtcm_data_wr_i      => read_data2_w,
        MemRead_ctrl_i      => mem_read_w, 
        MemWrite_ctrl_i     => dtcm_write_w,
                
        --Outputs
        dtcm_data_rd_o      => dtcm_data_rd_w 
    );  
    
    --=======================================
    -- MCLK counter register connection
    --=======================================                                   
    process (mclk_w , rst_i)
    begin
        if rst_i = '1' then
            mclk_cnt_q  <=  (others => '0');
        elsif rising_edge(mclk_w) then
            mclk_cnt_q  <=  mclk_cnt_q + '1';
        end if;
    end process;
---------------------------------------------------------------------------------------
-- Copying out important signals only for Verification and FPGA Velidation(Signal-TAP)
---------------------------------------------------------------------------------------
    pc_o                <=  pc_w;                                                                               -- IFETCH output                                
    instruction_o       <=  instruction_w;                                                          -- IFETCH output
    RegWrite_ctrl_o     <=  reg_write_w;                                                                -- CONTROL output
    MemWrite_ctrl_o     <=  mem_write_w;                                                                -- CONTROL output
    MemRead_ctrl_o      <=  mem_read_w;                                                             -- CONTROL output
    Branch_ctrl_o       <=  branch_w;                                                                       -- CONTROL output      
    read_data1_o        <=  read_data1_w;                                                               -- IDECODE output
    read_data2_o        <=  read_data2_w;                                                               -- IDECODE output
-- Mirror the IDECODE accelerator and ALU muxes for verification output.
    accelerator_res_w <= remainder_w WHEN wb_src1_w = "00" ELSE
                             quotient_w  WHEN wb_src1_w = "01" ELSE
                             mul_res_w   WHEN wb_src1_w = "10" ELSE
                             (OTHERS => '0');
    execution_res_w <= accelerator_res_w WHEN wb_src0_w = '0' ELSE alu_res_w;
    write_data_o <= ZEROS_DBUS2PCADDR & pc_plus4_w WHEN reg_dst_w = '1' ELSE
                      wb_dtcm_data_w                  WHEN MemtoReg_w = '1' ELSE
                      execution_res_w;
                                                
    alu_res_o           <=  alu_res_w;                                                                  -- EXECUTE output           
    brTaken_o           <=  brTaken_w;                                                                  -- EXECUTE output
  
    dtcm_addr_o         <=  dtcm_addr_w;                                                                -- DMEMORY input
    dtcm_data_wr_o      <=  read_data2_w;                                                               -- DMEMORY input
    dtcm_data_rd_o      <=  wb_dtcm_data_w;                                                         -- DTCM/peripheral read data
    
    mclk_cnt_o          <=  mclk_cnt_q;                                                                 -- TOP output
    
---------------------------------------------------------------------------------------
    INTA_o <= inta_w;
    GIE_o  <= gie_w;

END structure;
