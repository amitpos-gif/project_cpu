-------------------------------------------------------------------------------
-- d_latch_byte.vhd
--
-- 8-bit transparent D-latch, the "D0..D7 / En / Q0..Q7" block reused by every
-- GPO register in Figure 5 (PORT_LEDR, PORT_HEX0..PORT_HEX5).
-- the write data is captured for as long as En = CSx AND MemWrite is asserted,
-- matching the single-cycle core's write strobe behavior.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity d_latch_byte is
    port (
        D  : in  std_logic_vector(7 downto 0);
        En : in  std_logic;
        Q  : out std_logic_vector(7 downto 0)
    );
end entity d_latch_byte;

architecture rtl of d_latch_byte is
begin
    process (En, D)
    begin
        if En = '1' then
            Q <= D;
        end if;
    end process;
end architecture rtl;
