-----------------------------------------
-- clock_tree.vhd
------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cond_compilation_package.all;

entity clock_tree is
    port (
        rst_i      : in  std_logic;   -- asynchronous reset, active high
        baseclk_i  : in  std_logic;   -- 50 MHz board oscillator (CLOCK_50)

        mclk_o     : out std_logic;   -- 25 MHz  CPU
        accelclk_o : out std_logic;   -- 125 MHz divider accelerator
        smclk_o    : out std_logic;   -- 50 MHz  peripherals
        locked_o   : out std_logic    -- all three PLLs locked
    );
end entity clock_tree;

architecture structural of clock_tree is

 
    component PLL is
        generic (
            OUT_DIVIDE_BY   : NATURAL := G_PLL_DIV;
            OUT_MULTIPLY_BY : NATURAL := G_PLL_MUL
        );
        port (
            areset : in  std_logic;
            inclk0 : in  std_logic;
            c0     : out std_logic;
            locked : out std_logic
        );
    end component;

    signal mclk_lock_w  : std_logic;
    signal smclk_lock_w : std_logic;
    signal accel_lock_w : std_logic;

begin

    G0 : if (G_MODELSIM = 0) generate

        MCLK_PLL_U : PLL
            generic map (
                OUT_DIVIDE_BY => G_PLL_DIV,
                OUT_MULTIPLY_BY => G_PLL_MUL
            )
            port map (
                areset	=> rst_i,
                inclk0	=> baseclk_i,
                c0		=> mclk_o,
                locked		=> mclk_lock_w
            );

        SMCLK_PLL_U : PLL
            generic map (
                OUT_DIVIDE_BY => G_SMCLK_PLL_DIV,
                OUT_MULTIPLY_BY => G_SMCLK_PLL_MUL
            )
            port map (
                areset	=> rst_i,
                inclk0	=> baseclk_i,
                c0		=> smclk_o,
                locked		=> smclk_lock_w
            );

        DIVCLK_PLL_U : PLL
            generic map (
                OUT_DIVIDE_BY => G_DIVCLK_PLL_DIV,
                OUT_MULTIPLY_BY => G_DIVCLK_PLL_MUL
            )
            port map (
                areset	=> rst_i,
                inclk0	=> baseclk_i,
                c0		=> accelclk_o,
                locked		=> accel_lock_w
            );

        locked_o <= mclk_lock_w and smclk_lock_w and accel_lock_w;

    end generate;

end architecture structural;
