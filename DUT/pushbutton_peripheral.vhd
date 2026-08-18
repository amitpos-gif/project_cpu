-------------------------------------------------------------------------------
-- pushbutton_peripheral.vhd
--
-- KEY1-KEY3 input peripheral from Figure 6.
--
-- The DE10-Standard pushbuttons are active low and are hardware debounced by
-- the board interface.  This block exposes their levels through the byte-wide
-- PORT_PB register at 0x2014 and emits a one-SMCLK-cycle event for each new
-- button press.  The future interrupt
-- controller latches these events into KEY1IFG/KEY2IFG/KEY3IFG.
--
-- PORT_PB layout:
--   bit 3 = KEY3 level, bit 2 = KEY2 level, bit 1 = KEY1 level, bit 0 = 0
--   bits 7..4 = 0.  A pressed key reads as 0 (the physical active-low level).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.gpio_pkg.all;

entity pushbutton_peripheral is
    port (
        smclk      : in    std_logic;
        rst_i      : in    std_logic;
        Address    : in    std_logic_vector(ADDR_WIDTH-1 downto 0);
        Data       : inout std_logic_vector(7 downto 0);
        MemRead    : in    std_logic;

        KEY1       : in    std_logic;
        KEY2       : in    std_logic;
        KEY3       : in    std_logic;

        key_irq_o  : out   std_logic_vector(2 downto 0)
    );
end entity pushbutton_peripheral;

architecture rtl of pushbutton_peripheral is
    constant PORT_PB_ADDR_C : std_logic_vector(ADDR_WIDTH-1 downto 0) :=
        "10000000010100";  -- 0x2014

    signal key_level_w : std_logic_vector(2 downto 0);
    signal key_prev_q : std_logic_vector(2 downto 0);
    signal port_pb_cs_w : std_logic;
    signal port_pb_data_w : std_logic_vector(7 downto 0);
begin
    key_level_w <= KEY3 & KEY2 & KEY1;

    ---------------------------------------------------------------------------
    -- The board already debounces the keys.  key_prev_q is only edge history;
    -- it is not a synchronizer stage.  Reset to released ('1') so reset release
    -- cannot create a false falling-edge press event.
    ---------------------------------------------------------------------------
    process (smclk, rst_i)
    begin
        if rst_i = '1' then
            key_prev_q <= (others => '1');
            key_irq_o  <= (others => '0');
        elsif rising_edge(smclk) then
            -- Active-low press: previous sample released, current sample low.
            key_irq_o  <= key_prev_q and not key_level_w;
            key_prev_q <= key_level_w;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Read-only PORT_PB register, byte address 0x2014.
    ---------------------------------------------------------------------------
    port_pb_cs_w <= '1' when Address = PORT_PB_ADDR_C else '0';
    port_pb_data_w <= "0000" & key_level_w & '0';

    Data <= port_pb_data_w
            when MemRead = '1' and port_pb_cs_w = '1'
            else (others => 'Z');
end architecture rtl;
