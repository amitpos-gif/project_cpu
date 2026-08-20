-------------------------------------------------------------------------------
-- tb_mcu_top.vhd
--
-- Minimal, no-assertions testbench for mcu_top: just clocks, resets, and
-- holds SW steady, so the design can be watched running a real program
-- (currently whatever ITCM.hex/DTCM.hex IFETCH.VHD/DMEMORY.VHD point at)
-- in the ModelSim waveform viewer. Pair with run_mcu_top.do.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.aux_package.all;

entity tb_mcu_top is
end entity tb_mcu_top;

architecture sim of tb_mcu_top is

    -- Simulation-only clock periods (not tied to the real 50MHz baseclk).
    -- DIVCLK is kept faster than CLK, matching its role as the divider
    -- accelerator's "fast clock" (Figure 3).
    constant CLK_PERIOD    : time := 20 ns;
    constant DIVCLK_PERIOD : time := 5 ns;

    signal rst_i    : std_logic := '1';
    signal clk_i    : std_logic := '0';
    signal divclk_i : std_logic := '0';
    signal SW       : std_logic_vector(7 downto 0) := (others => '0');
    signal LEDR     : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);

begin

    DUT : mcu_top
        port map (
            rst_i    => rst_i,
            clk_i    => clk_i,
            divclk_i => divclk_i,
            smclk    => clk_i,
            KEY1     => '1',
            KEY2     => '1',
            KEY3     => '1',
            CAPIN1   => '0',
            CAPIN2   => '0',
            SW       => SW,
            LEDR     => LEDR,
            PWM      => open,
            HEX0     => HEX0,
            HEX1     => HEX1,
            HEX2     => HEX2,
            HEX3     => HEX3,
            HEX4     => HEX4,
            HEX5     => HEX5
        );

    clk_gen : process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD / 2;
        clk_i <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    divclk_gen : process
    begin
        divclk_i <= '0';
        wait for DIVCLK_PERIOD / 2;
        divclk_i <= '1';
        wait for DIVCLK_PERIOD / 2;
    end process;

    -- Hold rst_i for a few cycles (mimics KEY0), then release. SW stays at
    -- its default 0 throughout - edit here to test other GPIO benchmarks
    -- that read PORT_SW (e.g. test1/test2).
    stim : process
    begin
        rst_i <= '1';
        wait for 5 * CLK_PERIOD;
        rst_i <= '0';
        wait;
    end process;

end architecture sim;
