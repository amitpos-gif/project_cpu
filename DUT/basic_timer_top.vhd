-------------------------------------------------------------------------------
-- basic_timer_top.vhd
--
-- Structural wrapper for the Basic Timer and its memory-address decoder.
-- The decoder selects the memory-mapped timer register, and MemWrite qualifies
-- the four writable timer inputs.  BTCAPR is capture-only, so its decoded
-- address is not connected to a write-enable.
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE WORK.aux_package.ALL;

ENTITY basic_timer_top IS
    GENERIC (
        N : INTEGER := 32
    );
    PORT (
        smclk_i      : IN  STD_LOGIC;
        rst_i        : IN  STD_LOGIC;

        Address_i    : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
        WriteData_i  : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0);
        MemWrite_i   : IN  STD_LOGIC;

        CAPIN1_i     : IN  STD_LOGIC;
        CAPIN2_i     : IN  STD_LOGIC;

        BTCAPR_o     : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
        BTIFG_o      : OUT STD_LOGIC;
        PWM_o        : OUT STD_LOGIC
    );
END ENTITY basic_timer_top;

ARCHITECTURE structural OF basic_timer_top IS
    SIGNAL cs_btctl1_w   : STD_LOGIC;
    SIGNAL cs_btctl2_w   : STD_LOGIC;
    SIGNAL cs_btcmpr0_w  : STD_LOGIC;
    SIGNAL cs_btcmpr1_w  : STD_LOGIC;

    SIGNAL btctl1_we_w   : STD_LOGIC;
    SIGNAL btctl2_we_w   : STD_LOGIC;
    SIGNAL btcmpr0_we_w  : STD_LOGIC;
    SIGNAL btcmpr1_we_w  : STD_LOGIC;
BEGIN
    ADDRESS_DECODER : addr_decoder_basic_timer
        PORT MAP (
            Address    => Address_i,
            CS_BTCTL1  => cs_btctl1_w,
            CS_BTCTL2  => cs_btctl2_w,
            CS_BTCMPR0 => cs_btcmpr0_w,
            CS_BTCMPR1 => cs_btcmpr1_w,
            CS_BTCAPR  => OPEN
        );

    -- A timer register is written only when its address is selected during a
    -- valid CPU memory-write operation.
    btctl1_we_w  <= cs_btctl1_w  AND MemWrite_i;
    btctl2_we_w  <= cs_btctl2_w  AND MemWrite_i;
    btcmpr0_we_w <= cs_btcmpr0_w AND MemWrite_i;
    btcmpr1_we_w <= cs_btcmpr1_w AND MemWrite_i;

    TIMER : basic_timer
        GENERIC MAP (
            N => N
        )
        PORT MAP (
            smclk_i       => smclk_i,
            rst_i         => rst_i,
            BTCTL1_we_i   => btctl1_we_w,
            BTCTL2_we_i   => btctl2_we_w,
            BTCMPR0_we_i  => btcmpr0_we_w,
            BTCMPR1_we_i  => btcmpr1_we_w,
            reg_data_i    => WriteData_i,
            CAPIN1_i      => CAPIN1_i,
            CAPIN2_i      => CAPIN2_i,
            BTCAPR_o      => BTCAPR_o,
            BTIFG_o       => BTIFG_o,
            PWM_o         => PWM_o
        );
END ARCHITECTURE structural;
