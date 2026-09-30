---------------------------------------------------------------------------------------------
-- Testbench for RV32IM Single-Cycle Core
-- Generates clock (100 ns period) and reset, then lets the simulation run.
---------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.all;
USE work.aux_package.all;

ENTITY tb_RV32I_SC IS
    generic(
        WORD_GRANULARITY  : boolean  := G_WORD_GRANULARITY;
        MODELSIM          : integer  := 1;        -- 1 = ModelSim (bypass PLL)
        DATA_BUS_WIDTH    : integer  := 32;
        ITCM_ADDR_WIDTH   : integer  := G_ADDRWIDTH;
        DTCM_ADDR_WIDTH   : integer  := G_ADDRWIDTH;
        PC_WIDTH          : integer  := G_PC_WIDTH;
        MA_WIDTH          : integer  := G_MA_WIDTH;
        DATA_WORDS_NUM    : integer  := G_DATA_WORDSNUM;
        CLK_CNT_WIDTH     : integer  := 16
    );
END tb_RV32I_SC;

ARCHITECTURE struct OF tb_RV32I_SC IS
    SIGNAL clk_i : STD_LOGIC;
    SIGNAL rst_i : STD_LOGIC;
BEGIN

    CORE : RV32I_CORE
    generic map(
        WORD_GRANULARITY  => WORD_GRANULARITY,
        MODELSIM          => MODELSIM,
        DATA_BUS_WIDTH    => DATA_BUS_WIDTH,
        ITCM_ADDR_WIDTH   => ITCM_ADDR_WIDTH,
        DTCM_ADDR_WIDTH   => DTCM_ADDR_WIDTH,
        PC_WIDTH          => PC_WIDTH,
        MA_WIDTH          => MA_WIDTH,
        DATA_WORDS_NUM    => DATA_WORDS_NUM,
        CLK_CNT_WIDTH     => CLK_CNT_WIDTH
    )
    PORT MAP (
        clk_i            => clk_i,
        rst_i            => rst_i,
        pc_o             => open,
        instruction_o    => open,
        RegWrite_ctrl_o  => open,
        MemWrite_ctrl_o  => open,
        Branch_ctrl_o    => open,
        read_data1_o     => open,
        read_data2_o     => open,
        write_data_o     => open,
        alu_res_o        => open,
        brTaken_o        => open,
        dtcm_addr_o      => open,
        dtcm_data_wr_o   => open,
        dtcm_data_rd_o   => open,
        mclk_cnt_o       => open
    );

    gen_clk : process
    begin
        clk_i <= '1';
        wait for 50 ns;
        clk_i <= not clk_i;
        wait for 50 ns;
    end process;

    gen_rst : process
    begin
        rst_i <= '1';
        wait for 80 ns;
        rst_i <= '0';
        wait;
    end process;

END struct;
