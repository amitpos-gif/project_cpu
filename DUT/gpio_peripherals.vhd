-------------------------------------------------------------------------------
-- gpio_peripherals.vhd
--
-- Structural top-level for Required Support of CPU's GPIO Peripherals -
-- implements the eight memory-mapped GPIO registers
-- (Optimized Address Decoder + per-register D-latch / tri-state buffer interfaces).
--
-- Bus interface (matches the 8-bit "Data Memory BUS" drawn):
--   Address   : byte address, A13..A0 (Figure 2 Data Address Space)
--   Data      : bidirectional 8-bit peripheral data bus , The 32-bit <->
--               8-bit byte-lane translation from the CPU's Data-BUS is
--               assumed done upstream, in the "BUS Interface Logic" block
--               of Figure 1 - out of scope for this module.
--   MemRead / MemWrite : byte-wide access strobes, qualified per-register
--               with the decoded chip-select inside this module.
--
-- Table 5 map:
--   PORT_LEDR 0x2000  GPO  -> LEDR7-LEDR0
--   PORT_HEX0 0x2004  GPO  -> HEX0 (7-seg)
--   PORT_HEX1 0x2005  GPO  -> HEX1 (7-seg)
--   PORT_HEX2 0x2008  GPO  -> HEX2 (7-seg)
--   PORT_HEX3 0x2009  GPO  -> HEX3 (7-seg)
--   PORT_HEX4 0x200C  GPO  -> HEX4 (7-seg)
--   PORT_HEX5 0x200D  GPO  -> HEX5 (7-seg)
--   PORT_SW   0x2010  GPI  <- SW7-SW0
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.gpio_pkg.all;

entity gpio_peripherals is
    port (
        Address  : in    std_logic_vector(ADDR_WIDTH-1 downto 0);
        Data     : inout std_logic_vector(7 downto 0);
        MemRead  : in    std_logic;
        -- MemWrite must already be qualified with the clock phase by the
        -- BUS Interface Logic (see mcu_top.vhd). These are transparent
        -- D-latches, so a write strobe that is high while the address is
        -- still settling would let a store land in the wrong register.
        MemWrite : in    std_logic;

        SW       : in    std_logic_vector(7 downto 0);  -- SW7-SW0
        LEDR     : out   std_logic_vector(7 downto 0);  -- LEDR7-LEDR0
        HEX0     : out   std_logic_vector(6 downto 0);
        HEX1     : out   std_logic_vector(6 downto 0);
        HEX2     : out   std_logic_vector(6 downto 0);
        HEX3     : out   std_logic_vector(6 downto 0);
        HEX4     : out   std_logic_vector(6 downto 0);
        HEX5     : out   std_logic_vector(6 downto 0)
    );
end entity gpio_peripherals;

architecture structural of gpio_peripherals is

    component addr_decoder_gpio is
        port (
            Address  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            CS_LEDR  : out std_logic;
            CS_HEX01 : out std_logic;
            CS_HEX23 : out std_logic;
            CS_HEX45 : out std_logic;
            CS_SW    : out std_logic
        );
    end component;

    component d_latch_byte is
        port (
            D  : in  std_logic_vector(7 downto 0);
            En : in  std_logic;
            Q  : out std_logic_vector(7 downto 0)
        );
    end component;

    component tristate_byte is
        port (
            D  : in  std_logic_vector(7 downto 0);
            OE : in  std_logic;
            Y  : out std_logic_vector(7 downto 0)
        );
    end component;

    component hex7seg_decoder is
        port (
            hex_in : in  std_logic_vector(3 downto 0);
            seg    : out std_logic_vector(6 downto 0)
        );
    end component;

    signal CS_LEDR, CS_HEX01, CS_HEX23, CS_HEX45, CS_SW : std_logic;

    signal En_LEDR : std_logic;
    signal En_HEX0, En_HEX1, En_HEX2, En_HEX3, En_HEX4, En_HEX5 : std_logic;

    signal Q_LEDR : std_logic_vector(7 downto 0);
    signal Q_HEX0, Q_HEX1, Q_HEX2, Q_HEX3, Q_HEX4, Q_HEX5 : std_logic_vector(7 downto 0);

begin

    ----------------------------------------------------------------
    -- Optimized Address Decoder (Figure 5)
    ----------------------------------------------------------------
    u_decoder : addr_decoder_gpio
        port map (
            Address  => Address,
            CS_LEDR  => CS_LEDR,
            CS_HEX01 => CS_HEX01,
            CS_HEX23 => CS_HEX23,
            CS_HEX45 => CS_HEX45,
            CS_SW    => CS_SW
        );

    ----------------------------------------------------------------
    -- Per-register write enable: CSx AND MemWrite, with Address(0)
    -- selecting the even/odd byte in a shared group (A0 / not(A0)
    -- signals drawn into the PORT_HEX0 / PORT_HEX1 interfaces).
    ----------------------------------------------------------------
    En_LEDR <= CS_LEDR  and MemWrite;
    En_HEX0 <= CS_HEX01 and MemWrite and not Address(0);
    En_HEX1 <= CS_HEX01 and MemWrite and Address(0);
    En_HEX2 <= CS_HEX23 and MemWrite and not Address(0);
    En_HEX3 <= CS_HEX23 and MemWrite and Address(0);
    En_HEX4 <= CS_HEX45 and MemWrite and not Address(0);
    En_HEX5 <= CS_HEX45 and MemWrite and Address(0);

    ----------------------------------------------------------------
    -- PORT_LEDR (0x2000)
    ----------------------------------------------------------------
    u_ledr : d_latch_byte port map (D => Data, En => En_LEDR, Q => Q_LEDR);
    LEDR <= Q_LEDR;

    ----------------------------------------------------------------
    -- PORT_HEX0..PORT_HEX5 (0x2004-0x200D): D-latch -> 7-seg encoder
    ----------------------------------------------------------------
    u_hex0 : d_latch_byte port map (D => Data, En => En_HEX0, Q => Q_HEX0);
    u_hex1 : d_latch_byte port map (D => Data, En => En_HEX1, Q => Q_HEX1);
    u_hex2 : d_latch_byte port map (D => Data, En => En_HEX2, Q => Q_HEX2);
    u_hex3 : d_latch_byte port map (D => Data, En => En_HEX3, Q => Q_HEX3);
    u_hex4 : d_latch_byte port map (D => Data, En => En_HEX4, Q => Q_HEX4);
    u_hex5 : d_latch_byte port map (D => Data, En => En_HEX5, Q => Q_HEX5);

    u_enc0 : hex7seg_decoder port map (hex_in => Q_HEX0(3 downto 0), seg => HEX0);
    u_enc1 : hex7seg_decoder port map (hex_in => Q_HEX1(3 downto 0), seg => HEX1);
    u_enc2 : hex7seg_decoder port map (hex_in => Q_HEX2(3 downto 0), seg => HEX2);
    u_enc3 : hex7seg_decoder port map (hex_in => Q_HEX3(3 downto 0), seg => HEX3);
    u_enc4 : hex7seg_decoder port map (hex_in => Q_HEX4(3 downto 0), seg => HEX4);
    u_enc5 : hex7seg_decoder port map (hex_in => Q_HEX5(3 downto 0), seg => HEX5);

    ----------------------------------------------------------------
    -- PORT_SW (0x2010): GPI, tri-state driver onto the Data bus,
    -- enabled by CS_SW AND MemRead.
    ----------------------------------------------------------------
    u_sw : tristate_byte
        port map (
            D  => SW,
            OE => (CS_SW and MemRead),
            Y  => Data
        );

end architecture structural;
