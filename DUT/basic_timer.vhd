-------------------------------------------------------------------------------
-- basic_timer.vhd
--
-- Basic Timer wrapper based on Figures 7 and 8.  This file instantiates the
-- supplied bit_Timer counter core and adds the documented control, compare,
-- capture and PWM structures.  The memory-address decoder is intentionally
-- left outside this unit; one-cycle write enables load the mapped registers.
--
-- BTCTL1 layout:
--   bit 7     BTOUTMD
--   bit 6     BTOUTEN
--   bit 5     BTHOLD
--   bits 4:3  BTSSEL
--   bit 2     BTCLR
--   bits 1:0  BTINT
--
-- BTCTL2 layout:
--   bits 7:4  read as zero
--   bits 3:2  CAPMD
--   bits 1:0  CAPISEL
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE WORK.aux_package.ALL;

ENTITY basic_timer IS
    GENERIC (
        N : INTEGER := 32
    );
    PORT (
        smclk_i       : IN  STD_LOGIC;
        rst_i         : IN  STD_LOGIC;

        -- One-SMCLK-cycle register write enables from a future address decoder.
        BTCTL1_we_i   : IN  STD_LOGIC;
        BTCTL2_we_i   : IN  STD_LOGIC;
        BTCMPR0_we_i  : IN  STD_LOGIC;
        BTCMPR1_we_i  : IN  STD_LOGIC;
        reg_data_i    : IN  STD_LOGIC_VECTOR(N-1 DOWNTO 0);

        -- External capture sources.
        CAPIN1_i      : IN  STD_LOGIC;
        CAPIN2_i      : IN  STD_LOGIC;

        -- Basic Timer system outputs.
        BTCAPR_o      : OUT STD_LOGIC_VECTOR(N-1 DOWNTO 0);
        BTIFG_o       : OUT STD_LOGIC;
        PWM_o         : OUT STD_LOGIC
    );
END ENTITY basic_timer;

ARCHITECTURE structural OF basic_timer IS
    -- Figure 7: both compare latches are permanently enabled.
    CONSTANT HEU0           : STD_LOGIC := '1';

    SIGNAL btctl1_q       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL btctl2_q       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL btcmpr0_q      : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL btcmpr1_q      : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL btcl0_q        : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL btcl1_q        : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL btcapr_q       : STD_LOGIC_VECTOR(N-1 DOWNTO 0);

    SIGNAL clk_div_q      : STD_LOGIC_VECTOR(2 DOWNTO 0);
    SIGNAL timer_clk_w    : STD_LOGIC;
    SIGNAL timer_rst_w    : STD_LOGIC;
    SIGNAL timer_ena_w    : STD_LOGIC;
    SIGNAL btcnt_w        : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL equ0_w         : STD_LOGIC;
    SIGNAL equ1_w         : STD_LOGIC;

    SIGNAL cap_input_w    : STD_LOGIC;
    SIGNAL cap_trigger_w  : STD_LOGIC;

    SIGNAL pwmout_w       : STD_LOGIC;
BEGIN
    ---------------------------------------------------------------------------
    -- Memory-mapped register storage.  The internal BTCL0/BTCL1 latches are
    -- updated automatically with their corresponding compare registers.
    ---------------------------------------------------------------------------
    PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            btctl1_q  <= (OTHERS => '0');
            btctl2_q  <= (OTHERS => '0');
            btcmpr0_q <= (OTHERS => '0');
            btcmpr1_q <= (OTHERS => '0');
            btcl0_q   <= (OTHERS => '0');
            btcl1_q   <= (OTHERS => '0');
            clk_div_q <= (OTHERS => '0');

        ELSIF rising_edge(smclk_i) THEN
            clk_div_q <= clk_div_q + 1;

            IF BTCTL1_we_i = '1' THEN
                btctl1_q <= reg_data_i(7 DOWNTO 0);
            END IF;

            IF BTCTL2_we_i = '1' THEN
                btctl2_q <= "0000" & reg_data_i(3 DOWNTO 0);
            END IF;

            IF BTCMPR0_we_i = '1' THEN
                btcmpr0_q <= reg_data_i;
                IF HEU0 = '1' THEN
                    btcl0_q <= reg_data_i;
                END IF;
            END IF;

            IF BTCMPR1_we_i = '1' THEN
                btcmpr1_q <= reg_data_i;
                IF HEU0 = '1' THEN
                    btcl1_q <= reg_data_i;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- BTSSEL clock source selector: SMCLK, SMCLK/2, SMCLK/4 or SMCLK/8.
    ---------------------------------------------------------------------------
    WITH btctl1_q(4 DOWNTO 3) SELECT
        timer_clk_w <= smclk_i      WHEN "00",
                       clk_div_q(0) WHEN "01",
                       clk_div_q(1) WHEN "10",
                       clk_div_q(2) WHEN OTHERS;

    timer_rst_w <= rst_i OR btctl1_q(2);   -- BTCLR
    timer_ena_w <= NOT btctl1_q(5);        -- BTHOLD

    TIMER_CORE : bit_Timer
        GENERIC MAP (
            n => N
        )
        PORT MAP (
            clk       => timer_clk_w,
            rst       => timer_rst_w,
            ena       => timer_ena_w,
            EQUY      => equ0_w,
            timer_val => btcnt_w
        );

    ---------------------------------------------------------------------------
    -- Capture Mode: CAPISEL chooses the source and CAPMD converts the selected
    -- rising/falling edge into one rising capture trigger.
    ---------------------------------------------------------------------------
    WITH btctl2_q(1 DOWNTO 0) SELECT
        cap_input_w <= CAPIN1_i WHEN "00",
                       CAPIN2_i WHEN "01",
                       '1'      WHEN "10",
                       '0'      WHEN OTHERS;

    WITH btctl2_q(3 DOWNTO 2) SELECT
        cap_trigger_w <= cap_input_w     WHEN "01",
                         NOT cap_input_w WHEN "10",
                         '0'             WHEN OTHERS;

    -- BTCAPR loads BTCNT only on the selected rising/falling capture event.
    PROCESS (cap_trigger_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            btcapr_q <= (OTHERS => '0');
        ELSIF rising_edge(cap_trigger_w) THEN
            btcapr_q <= btcnt_w;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- Output Compare/PWM unit.  BTCL0 is the Y comparison (EQU0), and BTCL1
    -- is the X comparison (EQU1).  BTOUTEN='0' holds the PWM output value.
    ---------------------------------------------------------------------------
    PWM_UNIT : OUTPUT_UNIT
        GENERIC MAP (
            n => N
        )
        PORT MAP (
            y_i        => btcl0_q,
            x_i        => btcl1_q,
            timer_i    => btcnt_w,
            ena_i      => btctl1_q(6),
            clk_i      => timer_clk_w,
            pwm_mode_i => btctl1_q(7),
            pwm_out    => pwmout_w,
            equy_out   => equ0_w,
            equx_out   => equ1_w
        );

    ---------------------------------------------------------------------------
    -- BTINT interrupt-source selection: EQU0, EQU1, or Capture event.
    -- Values "10" and "11" both select Capture, matching the three options.
    ---------------------------------------------------------------------------
    WITH btctl1_q(1 DOWNTO 0) SELECT
        BTIFG_o <= equ0_w        WHEN "00",
                   equ1_w        WHEN "01",
                   cap_trigger_w WHEN OTHERS;

    BTCAPR_o  <= btcapr_q;
    PWM_o     <= pwmout_w;
END ARCHITECTURE structural;
