-------------------------------------------------------------------------------
-- addr_decoder_basic_timer.vhd
--
-- Address decoder for the memory-mapped Basic Timer registers.
-- The address is the 14-bit BYTE address produced by the CPU.  The chip-select
-- outputs depend only on the address, so they can be used for both reads and
-- writes.  At the system level, qualify a chip select with MemWrite or MemRead.
--
-- Register map:
--   0x201C  BTCTL1   byte register
--   0x201D  BTCTL2   byte register
--   0x2020  BTCMPR0  word register
--   0x2024  BTCMPR1  word register
--   0x2028  BTCAPR   word register
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY addr_decoder_basic_timer IS
    PORT (
        Address    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        CS_BTCTL1  : OUT STD_LOGIC;
        CS_BTCTL2  : OUT STD_LOGIC;
        CS_BTCMPR0 : OUT STD_LOGIC;
        CS_BTCMPR1 : OUT STD_LOGIC;
        CS_BTCAPR  : OUT STD_LOGIC
    );
END ENTITY addr_decoder_basic_timer;

ARCHITECTURE rtl OF addr_decoder_basic_timer IS
    CONSTANT BTCTL1_ADDR_C  : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000011100"; -- 0x201C
    CONSTANT BTCTL2_ADDR_C  : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000011101"; -- 0x201D
    CONSTANT BTCMPR0_ADDR_C : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000100000"; -- 0x2020
    CONSTANT BTCMPR1_ADDR_C : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000100100"; -- 0x2024
    CONSTANT BTCAPR_ADDR_C  : STD_LOGIC_VECTOR(13 DOWNTO 0) := "10000000101000"; -- 0x2028
BEGIN
    CS_BTCTL1  <= '1' WHEN Address = BTCTL1_ADDR_C  ELSE '0';
    CS_BTCTL2  <= '1' WHEN Address = BTCTL2_ADDR_C  ELSE '0';
    CS_BTCMPR0 <= '1' WHEN Address = BTCMPR0_ADDR_C ELSE '0';
    CS_BTCMPR1 <= '1' WHEN Address = BTCMPR1_ADDR_C ELSE '0';
    CS_BTCAPR  <= '1' WHEN Address = BTCAPR_ADDR_C  ELSE '0';
END ARCHITECTURE rtl;
