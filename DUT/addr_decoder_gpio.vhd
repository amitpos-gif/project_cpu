-------------------------------------------------------------------------------
-- addr_decoder_gpio.vhd
--
-- "Optimized Address Decoder" block - Decodes Address<13..2>
-- (word granularity) into one chip-select per register group. PORT_HEX0/1,
-- PORT_HEX2/3 and PORT_HEX4/5 share one group each (2 bytes of a 4-byte
-- word); Address(0) is used downstream (in gpio_peripherals.vhd) to pick
-- between the even/odd byte register, exactly as the A0 / not(A0) signals
-- drawn into the PORT_HEX0 / PORT_HEX1 interfaces in Figure 5.
--
-- CS naming below corresponds to Figure 5: CS_LEDR = CS1, CS_HEX01 = CS6,
-- CS_SW = CS7 (CS_HEX23 / CS_HEX45 are the extra groups needed for
-- HEX2-HEX5, not individually labeled in the figure).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gpio_pkg.all;

entity addr_decoder_gpio is
    port (
        Address  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        CS_LEDR  : out std_logic;  -- 0x2000
        CS_HEX01 : out std_logic;  -- 0x2004 / 0x2005
        CS_HEX23 : out std_logic;  -- 0x2008 / 0x2009
        CS_HEX45 : out std_logic;  -- 0x200C / 0x200D
        CS_SW    : out std_logic   -- 0x2010
    );
end entity addr_decoder_gpio;

architecture rtl of addr_decoder_gpio is

    signal word_addr : unsigned(ADDR_WIDTH-1 downto 2);

    constant GRP_LEDR  : natural := PORT_LEDR_ADDR / 4;
    constant GRP_HEX01 : natural := PORT_HEX0_ADDR / 4;
    constant GRP_HEX23 : natural := PORT_HEX2_ADDR / 4;
    constant GRP_HEX45 : natural := PORT_HEX4_ADDR / 4;
    constant GRP_SW    : natural := PORT_SW_ADDR   / 4;

begin

    word_addr <= unsigned(Address(ADDR_WIDTH-1 downto 2));

    CS_LEDR  <= '1' when word_addr = to_unsigned(GRP_LEDR,  word_addr'length) else '0';
    CS_HEX01 <= '1' when word_addr = to_unsigned(GRP_HEX01, word_addr'length) else '0';
    CS_HEX23 <= '1' when word_addr = to_unsigned(GRP_HEX23, word_addr'length) else '0';
    CS_HEX45 <= '1' when word_addr = to_unsigned(GRP_HEX45, word_addr'length) else '0';
    CS_SW    <= '1' when word_addr = to_unsigned(GRP_SW,    word_addr'length) else '0';

end architecture rtl;
