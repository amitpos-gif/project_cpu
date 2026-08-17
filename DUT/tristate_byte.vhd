-------------------------------------------------------------------------------
-- tristate_byte.vhd
--
-- 8-bit tri-state driver, the block used by the PORT_SW interface in
-- Figure 5 to place SW7-SW0 onto the shared bidirectional Data bus when
-- CS_SW AND MemRead are both asserted; high-impedance otherwise.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tristate_byte is
    port (
        D  : in  std_logic_vector(7 downto 0);
        OE : in  std_logic;
        Y  : out std_logic_vector(7 downto 0)
    );
end entity tristate_byte;

architecture rtl of tristate_byte is
begin
    Y <= D when OE = '1' else (others => 'Z');
end architecture rtl;
