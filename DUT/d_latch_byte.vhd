-------------------------------------------------------------------------------
-- d_latch_byte.vhd
--
-- 8-bit transparent D-latch, the "D0..D7 / En / Q0..Q7" block reused by every
-- GPO register in Figure 5 (PORT_LEDR, PORT_HEX0..PORT_HEX5).
--
-- The latch is transparent only while En = '1' AND clk = '0'; otherwise it
-- holds its last captured value.
--
-- Why the clock is part of the latch rather than just En = CSx AND MemWrite:
-- in a single-cycle CPU the whole combinational chain (ITCM -> CONTROL/RF ->
-- ALU -> address decoder) re-settles right after each rising clock edge, and
-- the address sweeps through intermediate values while MemWrite is already
-- asserted. A latch left transparent through that window captures the garbage
-- and a store lands in the wrong register. Holding the latch opaque while
-- clk = '1' and opening it only on the stable clk = '0' half is the same
-- convention the project already uses for data memory (DMEMORY.VHD:
-- wrclk_w <= NOT clk_i, the not(clk) drawn on DTCM in Figure 3).
--
-- REQUIREMENT: clk must be synchronous and in phase with the CPU's MCLK -
-- its low phase is what defines the safe write window.
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
