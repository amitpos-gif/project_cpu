
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cond_compilation_package.all;
-- RV32I_CORE's component declaration lives in aux_package (the project's
-- central component registry), so it is not repeated here.
use work.aux_package.all;

entity mcu_top is
    port (
        rst_i    : in  std_logic;                     -- KEY0, System RESET
        clk_i    : in  std_logic;                      -- baseclk 50MHz
        divclk_i : in  std_logic;                      -- fast divider clock (Clock Tree/PLL not built yet - passed through)
        -- Peripheral clock from the Clock Tree (Figure 1). Must be
        -- synchronous and in phase with the CPU clock - gpio_peripherals
        -- uses its low phase as the safe window for its D-latch writes.
        smclk    : in  std_logic;

        SW       : in  std_logic_vector(7 downto 0);    -- SW7-SW0
        LEDR     : out std_logic_vector(7 downto 0);    -- LEDR7-LEDR0
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0);
        HEX4     : out std_logic_vector(6 downto 0);
        HEX5     : out std_logic_vector(6 downto 0)
    );
end entity mcu_top;

architecture structural of mcu_top is

    component BidirPin is
        generic ( width : integer := 16 );
        port (
            Dout  : in    std_logic_vector(width-1 downto 0);
            en    : in    std_logic;
            Din   : out   std_logic_vector(width-1 downto 0);
            IOpin : inout std_logic_vector(width-1 downto 0)
        );
    end component;

    component gpio_peripherals is
        port (
            smclk    : in    std_logic;
            Address  : in    std_logic_vector(13 downto 0);
            Data     : inout std_logic_vector(7 downto 0);
            MemRead  : in    std_logic;
            MemWrite : in    std_logic;
            SW       : in    std_logic_vector(7 downto 0);
            LEDR     : out   std_logic_vector(7 downto 0);
            HEX0     : out   std_logic_vector(6 downto 0);
            HEX1     : out   std_logic_vector(6 downto 0);
            HEX2     : out   std_logic_vector(6 downto 0);
            HEX3     : out   std_logic_vector(6 downto 0);
            HEX4     : out   std_logic_vector(6 downto 0);
            HEX5     : out   std_logic_vector(6 downto 0)
        );
    end component;

    -- Signals tapped for the (stub) BUS Interface Logic
    signal alu_res_w      : std_logic_vector(31 downto 0);
    signal dtcm_data_wr_w : std_logic_vector(31 downto 0);
    signal mem_write_w    : std_logic;
    signal mem_read_w     : std_logic;

    signal io_address_w   : std_logic_vector(13 downto 0);
    signal io_data_w      : std_logic_vector(7 downto 0);  -- BidirPin's IOpin: the shared peripheral Data bus
    signal io_data_rd_w   : std_logic_vector(7 downto 0);  -- BidirPin's Din: live readback of io_data_w

    -- Remaining RV32I_CORE outputs: not consumed by this stub, wired only
    -- to keep the port map complete (mirrors the core's own Signal-Tap
    -- verification outputs, per its header comment).
    signal pc_w           : std_logic_vector(G_PC_WIDTH-1 downto 0);
    signal instruction_w  : std_logic_vector(31 downto 0);
    signal reg_write_w    : std_logic;
    signal branch_w       : std_logic;
    signal read_data1_w   : std_logic_vector(31 downto 0);
    signal read_data2_w   : std_logic_vector(31 downto 0);
    signal write_data_w   : std_logic_vector(31 downto 0);
    signal brtaken_w      : std_logic;
    signal dtcm_addr_w    : std_logic_vector(G_ADDRWIDTH-1 downto 0);
    signal dtcm_data_rd_w : std_logic_vector(31 downto 0);
    signal mclk_cnt_w     : std_logic_vector(15 downto 0);

begin

    ----------------------------------------------------------------
    -- RISC-V core (Figure 1 "RISC-V core" box)
    -- MODELSIM => 1 overrides the core's own default (0 = FPGA/PLL path)
    -- so this wrapper simulates without needing Altera PLL simulation
    -- models; revisit when this is actually compiled in Quartus.
    ----------------------------------------------------------------
    CORE : RV32I_CORE
        generic map (
            MODELSIM => 1
        )
        port map (
            rst_i           => rst_i,
            clk_i           => clk_i,
            divclk_i        => divclk_i,
            dtcm_data_rd_i  => x"000000" & io_data_rd_w,

            pc_o            => pc_w,
            instruction_o   => instruction_w,
            RegWrite_ctrl_o => reg_write_w,
            MemWrite_ctrl_o => mem_write_w,
            MemRead_ctrl_o  => mem_read_w,
            Branch_ctrl_o   => branch_w,
            read_data1_o    => read_data1_w,
            read_data2_o    => read_data2_w,
            write_data_o    => write_data_w,
            alu_res_o       => alu_res_w,
            brTaken_o       => brtaken_w,
            dtcm_addr_o     => dtcm_addr_w,
            dtcm_data_wr_o  => dtcm_data_wr_w,
            dtcm_data_rd_o  => dtcm_data_rd_w,
            mclk_cnt_o      => mclk_cnt_w
        );

    ----------------------------------------------------------------
    -- "BUS Interface Logic" (Figure 1): full byte address straight from
    -- the ALU, and the "Bi-directional Data BUS" itself (BidirPin.vhd).
    ----------------------------------------------------------------
    io_address_w <= alu_res_w(13 downto 0);

    DATA_BUS : BidirPin
        generic map (
            width => 8
        )
        port map (
            Dout  => dtcm_data_wr_w(7 downto 0),
            en    => mem_write_w,
            Din   => io_data_rd_w,
            IOpin => io_data_w
        );

    ----------------------------------------------------------------
    -- Peripherals (Figure 1 "Peripherals" box) - GPIO only (Table 5).
    -- KEY[3-1] intentionally left out of this pass.
    ----------------------------------------------------------------
    GPIO : gpio_peripherals
        port map (
            smclk    => smclk,
            Address  => io_address_w,
            Data     => io_data_w,
            MemRead  => mem_read_w,
            MemWrite => mem_write_w,
            SW       => SW,
            LEDR     => LEDR,
            HEX0     => HEX0,
            HEX1     => HEX1,
            HEX2     => HEX2,
            HEX3     => HEX3,
            HEX4     => HEX4,
            HEX5     => HEX5
        );

end architecture structural;
