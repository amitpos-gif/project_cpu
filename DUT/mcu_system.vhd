-------------------------------------------------------------------------------
-- mcu_system.vhd
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity mcu_system is
    port (
        CLOCK_50 : in  std_logic;                     -- 50 MHz board oscillator
        KEY0     : in  std_logic;                     -- system RESET, active low
        KEY1     : in  std_logic;
        KEY2     : in  std_logic;
        KEY3     : in  std_logic;

        SW       : in  std_logic_vector(7 downto 0);  -- SW7-SW0
        LEDR     : out std_logic_vector(7 downto 0);  -- LEDR7-LEDR0
        HEX0     : out std_logic_vector(6 downto 0);
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0);
        HEX4     : out std_logic_vector(6 downto 0);
        HEX5     : out std_logic_vector(6 downto 0)
    );
end entity mcu_system;

architecture structural of mcu_system is

    component clock_tree is
        port (
            rst_i      : in  std_logic;
            baseclk_i  : in  std_logic;
            mclk_o     : out std_logic;
            accelclk_o : out std_logic;
            smclk_o    : out std_logic;
            locked_o   : out std_logic
        );
    end component;

    component mcu_top is
        port (
            rst_i    : in  std_logic;
            clk_i    : in  std_logic;
            divclk_i : in  std_logic;
            smclk    : in  std_logic;
            KEY1     : in  std_logic;
            KEY2     : in  std_logic;
            KEY3     : in  std_logic;
            SW       : in  std_logic_vector(7 downto 0);
            LEDR     : out std_logic_vector(7 downto 0);
            HEX0     : out std_logic_vector(6 downto 0);
            HEX1     : out std_logic_vector(6 downto 0);
            HEX2     : out std_logic_vector(6 downto 0);
            HEX3     : out std_logic_vector(6 downto 0);
            HEX4     : out std_logic_vector(6 downto 0);
            HEX5     : out std_logic_vector(6 downto 0)
        );
    end component;

    signal mclk_w     : std_logic;
    signal accelclk_w : std_logic;
    signal smclk_w    : std_logic;
    signal locked_w   : std_logic;

    signal key0_rst_w : std_logic;   -- KEY0 inverted to active high
    signal rst_w      : std_logic;   -- system reset, active high

begin

    ----------------------------------------------------------------
    -- Reset: KEY0 is active low, the design is active high. Reset is
    -- also held while the PLL has not locked.
    ----------------------------------------------------------------
    key0_rst_w <= not KEY0;
    rst_w      <= key0_rst_w or (not locked_w);

    ----------------------------------------------------------------
    -- Clock Tree (Figure 1)
    ----------------------------------------------------------------
    CLKTREE : clock_tree
        port map (
            rst_i      => key0_rst_w,   -- not gated by locked, it generates it
            baseclk_i  => CLOCK_50,
            mclk_o     => mclk_w,
            accelclk_o => accelclk_w,
            smclk_o    => smclk_w,
            locked_o   => locked_w
        );

    ----------------------------------------------------------------
    -- MCU (Figure 1: core + bus interface + peripherals)
    ----------------------------------------------------------------
    MCU : mcu_top
        port map (
            rst_i    => rst_w,
            clk_i    => mclk_w,
            divclk_i => accelclk_w,
            smclk    => smclk_w,
            KEY1     => KEY1,
            KEY2     => KEY2,
            KEY3     => KEY3,
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
