-------------------------------------------------------------------------------
-- addr_decoder_interrupt.vhd
--
-- Byte-address decoder for the interrupt-controller registers.
--   0x202C  IE    Interrupt Enable register
--   0x202D  IFG   Interrupt Flag register
--   0x202E  TYPE  Interrupt Type register
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY addr_decoder_interrupt IS
    PORT (
        Address : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        CS_IE   : OUT STD_LOGIC;
        CS_IFG  : OUT STD_LOGIC;
        CS_TYPE : OUT STD_LOGIC
    );
END ENTITY addr_decoder_interrupt;

ARCHITECTURE rtl OF addr_decoder_interrupt IS
    CONSTANT IE_ADDR_C   : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000101100"; -- 0x202C
    CONSTANT IFG_ADDR_C  : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000101101"; -- 0x202D
    CONSTANT TYPE_ADDR_C : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000101110"; -- 0x202E
BEGIN
    CS_IE   <= '1' WHEN Address = IE_ADDR_C   ELSE '0';
    CS_IFG  <= '1' WHEN Address = IFG_ADDR_C  ELSE '0';
    CS_TYPE <= '1' WHEN Address = TYPE_ADDR_C ELSE '0';
END ARCHITECTURE rtl;
