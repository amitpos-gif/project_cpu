
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
    SIGNAL word_addr : STD_LOGIC_VECTOR(13 DOWNTO 2);
BEGIN
    word_addr <= Address(13 DOWNTO 2);

    CS_BTCTL1 <= '1' WHEN word_addr = x"807" AND Address(0) = '0' ELSE '0';
    CS_BTCTL2 <= '1' WHEN word_addr = x"807" AND Address(0) = '1' ELSE '0';
    CS_BTCMPR0 <= '1' WHEN word_addr = x"808" ELSE '0';
    CS_BTCMPR1 <= '1' WHEN word_addr = x"809" ELSE '0';
    CS_BTCAPR  <= '1' WHEN word_addr = x"80A" ELSE '0';
END ARCHITECTURE rtl;
