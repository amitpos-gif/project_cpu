-------------------------------------------------------------------------------
-- gpio_pkg.vhd
--
-- Address constants - All addresses are BYTE addresses inside the
-- 14-bit Data Address Space - I/O region 0x2000-0x3FFC.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package gpio_pkg is

    constant ADDR_WIDTH : natural := 14;  -- Data Address Space: A13..A0 (byte address)

    -- Table 5 : Memory-mapped GPIO without interrupt capability
    constant PORT_LEDR_ADDR : natural := 16#2000#;  -- LEDR7-LEDR0, GPO
    constant PORT_HEX0_ADDR : natural := 16#2004#;  -- GPO
    constant PORT_HEX1_ADDR : natural := 16#2005#;  -- GPO
    constant PORT_HEX2_ADDR : natural := 16#2008#;  -- GPO
    constant PORT_HEX3_ADDR : natural := 16#2009#;  -- GPO
    constant PORT_HEX4_ADDR : natural := 16#200C#;  -- GPO
    constant PORT_HEX5_ADDR : natural := 16#200D#;  -- GPO
    constant PORT_SW_ADDR   : natural := 16#2010#;  -- SW7-SW0, GPI

    -- Page 6: memory-mapped peripheral with interrupt capability
    constant PORT_PB_ADDR   : natural := 16#2014#;  -- KEY3-KEY1, GPI

end package gpio_pkg;
