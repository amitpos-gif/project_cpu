-------------------------------------------------------------------------------
-- addr_decoder_gpio.vhd
--
-- Optimized address decoder for the memory-mapped GPIO registers.  Address
-- bits 13 downto 2 select a four-byte register group.  No numeric package or
-- numeric conversion is required: the address bits are compared directly.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity addr_decoder_gpio is
    port (
        Address  : in  std_logic_vector(13 downto 0);
        CS_LEDR  : out std_logic;  -- 0x2000
        CS_HEX01 : out std_logic;  -- 0x2004 / 0x2005
        CS_HEX23 : out std_logic;  -- 0x2008 / 0x2009
        CS_HEX45 : out std_logic;  -- 0x200C / 0x200D
        CS_SW    : out std_logic   -- 0x2010
    );
end entity addr_decoder_gpio;

architecture rtl of addr_decoder_gpio is
    signal word_addr : std_logic_vector(13 downto 2);
begin
    word_addr <= Address(13 downto 2);

    CS_LEDR  <= '1' when word_addr = x"800" else '0';
    CS_HEX01 <= '1' when word_addr = x"801" else '0';
    CS_HEX23 <= '1' when word_addr = x"802" else '0';
    CS_HEX45 <= '1' when word_addr = x"803" else '0';
    CS_SW    <= '1' when word_addr = x"804" else '0';
end architecture rtl;
