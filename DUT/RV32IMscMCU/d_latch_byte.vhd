-------------------------------------------------------------------------------
-- d_latch_byte.vhd
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity d_latch_byte is
    port (
        clk : in  std_logic;
        D   : in  std_logic_vector(7 downto 0);
        En  : in  std_logic;
        Q   : out std_logic_vector(7 downto 0)
    );
end entity d_latch_byte;

architecture rtl of d_latch_byte is
begin
    process (clk, En, D)
    begin
        if En = '1' and clk = '0' then
            Q <= D;
        end if;
    end process;
end architecture rtl;
