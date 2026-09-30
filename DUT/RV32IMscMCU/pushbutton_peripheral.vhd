-------------------------------------------------------------------------------
-- pushbutton_peripheral.vhd
-- KEY1-KEY3 input peripheral 
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity pushbutton_peripheral is
    port (
        smclk      : in    std_logic; -- coming from the PLL, 50MHz
        rst_i      : in    std_logic; -- coming from the CPU, active high key0
        Address    : in    std_logic_vector(13 downto 0); -- coming from the CPU, address bus
        Data       : inout std_logic_vector(7 downto 0); -- coming from the CPU, data bus
        MemRead    : in    std_logic; -- coming from the control, active high

        KEY1       : in    std_logic; -- coming from the board
        KEY2       : in    std_logic; -- coming from the board 
        KEY3       : in    std_logic; -- coming from the board

        key_irq_o  : out   std_logic_vector(2 downto 0) -- going to the CPU, interrupt-request output.
    );
end entity pushbutton_peripheral;

architecture rtl of pushbutton_peripheral is

    signal key_level_wire : std_logic_vector(2 downto 0); -- 3-bit vector of the current level of the pushbuttons
    signal key_prev_q : std_logic_vector(2 downto 0);     -- 3 FF flip-flops to synchronize the pushbutton inputs to the smclk domain
    signal port_pb_cs_w : std_logic;                      -- chip select for the pushbutton peripheral
    signal port_pb_data_w : std_logic_vector(7 downto 0); -- data to be read from the pushbutton peripheral
begin

    key_level_wire <= KEY3 & KEY2 & KEY1; -- creating the vector of status of the pushbuttons
    --------------------------------------------------------------------------
    process (smclk, rst_i)
    begin
        if rst_i = '1' then
            key_prev_q <= (others => '1'); --- 111 means that the pushbuttons are not pressed, because they are active low
            key_irq_o  <= (others => '0'); --- 000 means that no interrupt is requested
        elsif rising_edge(smclk) then
            key_irq_o  <= key_prev_q and not key_level_wire;
            key_prev_q <= key_level_wire;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Read-only PORT_PB register, byte address 0x2014.
    ---------------------------------------------------------------------------
    port_pb_cs_w <= '1' WHEN Address(13 DOWNTO 2) = x"805" ELSE '0'; -- 0x2014 is the address of the pushbutton peripheral, coresponding 12 bits ois x"805" (0x2014 shifted right by 2 bits).
    port_pb_data_w <= "0000" & key_level_wire & '0'; -- 

    Data <= port_pb_data_w
            when MemRead = '1' and port_pb_cs_w = '1'
            else (others => 'Z');
end architecture rtl;
