-------------------------------------------------------------------------------
-- mcu_top.vhd
--
-- Top-level MCU (Figure 1 shape): wires RV32I_CORE (RISC-V core) and
-- gpio_peripherals (Peripherals, Table 5) together through a "BUS Interface
-- Logic" stub. Built WITHOUT the KEY[3-1] peripheral for now, per request.
--
-- RV32I_CORE.vhd was extended (with permission) to support this:
--   - MemRead_ctrl_o forwards the core's internal mem_read_w (CONTROL's
--     MemRead_ctrl_o = ld_w) out to the entity boundary, so this file can
--     enable gpio_peripherals' PORT_SW tri-state read at the right time.
--   - dtcm_data_rd_i lets this file feed peripheral read data back into the
--     core's write-back path; the core muxes it in (wb_dtcm_data_w) for any
--     address with bit MA_WIDTH set (the DTCM-vs-IO discriminator, see
--     Figure 2), instead of its own internal DTCM's read result.
--   - The core now gates its OWN internal DTCM write with NOT is_io_addr_w,
--     so a store to a peripheral address (e.g. PORT_LEDR @ 0x2000) no
--     longer also aliases onto and corrupts a low DTCM word address.
--
-- The shared Data bus itself - the "Click Me: Bi-directional Data BUS
-- (reminder)" annotation on Figure 1 - is built from BidirPin.vhd, the
-- course's own reusable inout-pin component ("Bi-directional BUS" slides):
-- Din <= IOpin always, IOpin <= Dout when en='1' else 'Z'. Address/data
-- width is otherwise reduced to gpio_peripherals' 8-bit peripheral bus
-- (Figure 5).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cond_compilation_package.all;

entity mcu_top is
    port (
        rst_i    : in  std_logic;                     -- KEY0, System RESET
        clk_i    : in  std_logic;                      -- baseclk 50MHz
        divclk_i : in  std_logic;                      -- fast divider clock (Clock Tree/PLL not built yet - passed through)

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

    -- Signals tapped for the (stub) BUS Interface Logic
    signal alu_res_w      : std_logic_vector(31 downto 0);
    signal dtcm_data_wr_w : std_logic_vector(31 downto 0);
    signal mem_write_w    : std_logic;
    signal mem_read_w     : std_logic;

    signal io_address_w   : std_logic_vector(13 downto 0);
    signal io_write_w     : std_logic;                     -- clock-qualified peripheral write strobe
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
    CORE : entity work.RV32I_CORE
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

    -- Clock-qualified peripheral write strobe, same convention DMEMORY.VHD
    -- uses for DTCM (wrclk_w <= NOT clk_i - the not(clk) on DTCM in
    -- Figure 3). The peripherals' registers are transparent D-latches
    -- (Figure 5), so the strobe must not be high while the address is
    -- still settling out of the ALU right after a rising edge - otherwise
    -- an address glitch opens the wrong register's latch and the store
    -- lands in the wrong device. Restricting the strobe to the stable
    -- clk='0' half of the cycle closes that window.
    -- NOTE: BidirPin's en stays on the ungated mem_write_w on purpose, so
    -- the store data outlives this strobe - the latch closes first (at the
    -- rising edge), the bus goes high-Z later, never the other way round.
    io_write_w <= mem_write_w and not clk_i;

    DATA_BUS : entity work.BidirPin
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
    GPIO : entity work.gpio_peripherals
        port map (
            Address  => io_address_w,
            Data     => io_data_w,
            MemRead  => mem_read_w,
            MemWrite => io_write_w,
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
