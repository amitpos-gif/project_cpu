-------------------------------------------------------------------------------
-- basic_timer

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

    -- Capture event CDC: the asynchronous edge stores a stable counter
    -- snapshot and toggles one bit.  The toggle is then synchronized into
    -- SMCLK and converted into a one-SMCLK-cycle pulse.
    SIGNAL capture_shadow_q       : STD_LOGIC_VECTOR(N-1 DOWNTO 0);
    SIGNAL capture_event_toggle_q : STD_LOGIC;
    SIGNAL capture_toggle_meta_q  : STD_LOGIC;
    SIGNAL capture_toggle_sync_q  : STD_LOGIC;
    SIGNAL capture_toggle_prev_q  : STD_LOGIC;
    SIGNAL capture_event_pulse_w  : STD_LOGIC;
    SIGNAL capture_armed_q        : STD_LOGIC;

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
            btcapr_q  <= (OTHERS => '0');
            clk_div_q <= (OTHERS => '0');
            capture_armed_q <= '0';

        ELSIF rising_edge(smclk_i) THEN
            clk_div_q <= clk_div_q + 1;

            IF BTCTL1_we_i = '1' THEN
                btctl1_q <= reg_data_i(7 DOWNTO 0);
            END IF;

            IF BTCTL2_we_i = '1' THEN
                btctl2_q <= "0000" & reg_data_i(3 DOWNTO 0);
                -- Ignore the artificial edge that the new CAPMD/CAPISEL
                -- configuration can create in cap_trigger_w.
                capture_armed_q <= '0';
            ELSE
                -- Re-arm after the new capture configuration has settled.
                capture_armed_q <= '1';
            END IF;

            IF BTCMPR0_we_i = '1' THEN
                btcmpr0_q <= reg_data_i;
            END IF;

            IF BTCMPR1_we_i = '1' THEN
                btcmpr1_q <= reg_data_i;
            END IF;

            -- capture_shadow_q has already been stable for the two-FF
            -- synchronizer delay when this pulse reaches the SMCLK domain.
            IF capture_event_pulse_w = '1' THEN
                btcapr_q <= capture_shadow_q;
            END IF;
        END IF;
    END PROCESS;

    -- LATCH FOR BTCL{0/1} --
    BTCL0_LATCH_P : PROCESS (btcmpr0_q)
    BEGIN
        IF HEU0 = '1' THEN
            btcl0_q <= btcmpr0_q;
        END IF;
    END PROCESS;

    BTCL1_LATCH_P : PROCESS (btcmpr1_q)
    BEGIN
        IF HEU0 = '1' THEN
            btcl1_q <= btcmpr1_q;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- BTSSEL clock source selector: SMCLK, SMCLK/2, SMCLK/4 or SMCLK/8.
    ---------------------------------------------------------------------------
    WITH btctl1_q(4 DOWNTO 3) SELECT  -- it is BTSELL -- 
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
    -- Capture Mode CAPISEL chooses the source, CAPMD selected rising/falling edge trigger.
    ---------------------------------------------------------------------------
    WITH btctl2_q(1 DOWNTO 0) SELECT  -- it is CAPSELL
        cap_input_w <= CAPIN1_i WHEN "00",
                       CAPIN2_i WHEN "01",
                       '1'      WHEN "10",
                       '0'      WHEN OTHERS;

    WITH btctl2_q(3 DOWNTO 2) SELECT  -- it is CAPMD
        cap_trigger_w <= cap_input_w     WHEN "01",
                         NOT cap_input_w WHEN "10",
                         '0'             WHEN OTHERS;

    ------------------------------------------------------------------------------------------------------
    -- we add this part for not missing puses that shorter then the SMCLK with tredoff of 2 cycle delay --
    ------------------------------------------------------------------------------------------------------
    PROCESS (cap_trigger_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            capture_shadow_q       <= (OTHERS => '0');
            capture_event_toggle_q <= '0';
        ELSIF rising_edge(cap_trigger_w) THEN
            IF capture_armed_q = '1' THEN
                capture_shadow_q       <= btcnt_w;
                capture_event_toggle_q <= NOT capture_event_toggle_q;
            END IF;
        END IF;
    END PROCESS;

    -- Two flip-flops reduce metastability risk while crossing the single-bit event indicator into the SMCLK domain.  The third register remembers --
    PROCESS (smclk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            capture_toggle_meta_q <= '0';
            
            capture_toggle_sync_q <= '0';
            capture_toggle_prev_q <= '0';
        ELSIF rising_edge(smclk_i) THEN
            capture_toggle_meta_q <= capture_event_toggle_q;
            capture_toggle_sync_q <= capture_toggle_meta_q;
            capture_toggle_prev_q <= capture_toggle_sync_q;
        END IF;
    END PROCESS;

    capture_event_pulse_w <= capture_toggle_sync_q XOR capture_toggle_prev_q; 

    ---------------------------------------------------------------------------
    -- Output Compare/PWM unit:
    --  BTCL0 is the Y comparison (EQU0) 
    --  BTCL1 is the X comparison (EQU1)
    --  BTOUTEN ='0' holds the PWM output value.
    ---------------------------------------------------------------------------
    PWM_UNIT : OUTPUT_UNIT
        GENERIC MAP (
            n => N
        )
        PORT MAP (
            y_i        => btcl0_q,
            x_i        => btcl1_q,
            timer_i    => btcnt_w,
            ena_i      => btctl1_q(6), -- BTOUTEN --
            clk_i      => timer_clk_w,
            rst_i      => rst_i,
            pwm_mode_i => btctl1_q(7), -- BTOUTMD --
            pwm_out    => pwmout_w,
            equy_out   => equ0_w,
            equx_out   => equ1_w
        );

    ---------------------------------------------------------------------------
    -- BTINT interrupt-source selection: EQU0, EQU1, or Capture event.
    -- Values "10" and "11" both select Capture, matching the three options.
    ---------------------------------------------------------------------------
    WITH btctl1_q(1 DOWNTO 0) SELECT -- it is BTINT -- 
        BTIFG_o <= equ0_w        WHEN "00",
                   equ1_w        WHEN "01",
                   capture_event_pulse_w WHEN OTHERS;

    BTCAPR_o  <= btcapr_q;
    PWM_o     <= pwmout_w;
END ARCHITECTURE structural;
