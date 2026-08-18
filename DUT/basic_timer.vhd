--------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.aux_package.all;

entity basic_timer is
    generic (
        n : integer := 32
    );
    port (
        -- Compare values (from the BTCMPRx registers, outside this box)
        BTCMPR0  : in  std_logic_vector(n-1 downto 0);  --will go to latch BTCL0
        BTCMPR1  : in  std_logic_vector(n-1 downto 0);  --will go to latch BTCL1

        -- Control bits (from BTCTL1 / BTCTL2, outside this box)
        BTCLR    : in  std_logic;                       -- Clear timer
        BTHOLD   : in  std_logic;                       -- Hold timer
        BTSSEL   : in  std_logic_vector(1 downto 0);    -- Clock selection

        BTOUTMD  : in  std_logic;  -- for the output unit
        BTOUTEN  : in  std_logic;  -- for the output unit

        BTINT    : in  std_logic_vector(1 downto 0);
        CAPISEL  : in  std_logic_vector(1 downto 0);
        CAPMD    : in  std_logic_vector(1 downto 0);

        -- Clock sources into the BTSSEL mux
        SMCLK    : in  std_logic;
        SMCLK_2  : in  std_logic;
        SMCLK_4  : in  std_logic;
        SMCLK_8  : in  std_logic;

        -- Capture inputs
        CAPIN1   : in  std_logic;
        CAPIN2   : in  std_logic;

        -- Outputs
        PWM_out  : out std_logic;
        BTIFG    : out std_logic;
        BTCAPR   : out std_logic_vector(n-1 downto 0)
    );
end entity basic_timer;

architecture struct of basic_timer is

    signal btclk_w   : std_logic;                              -- BTSSEL mux output
    signal cnt_en_w  : std_logic;                              -- BTCNT /EN
    signal BTCNT_w   : std_logic_vector(n-1 downto 0);
    signal BTCL0_q   : std_logic_vector(n-1 downto 0) := (others => '0');
    signal BTCL1_q   : std_logic_vector(n-1 downto 0) := (others => '0');
    signal BTCAPR_q  : std_logic_vector(n-1 downto 0) := (others => '0');

    signal EUQ0_w    : std_logic;                              -- BTCNT = BTCL0
    signal EUQ1_w    : std_logic;                              -- BTCNT = BTCL1
    signal HEU0_w    : std_logic;                              -- BTCLx latch enable

    signal cap_src_w : std_logic;                              -- CAPISEL mux output
    signal cap_s1_q  : std_logic := '0';
    signal cap_s2_q  : std_logic := '0';
    signal cap_s3_q  : std_logic := '0';
    signal cap_evt_w : std_logic;                              -- Capture Mode event

begin

    ----------------------------------------------------------------
    -- BTSSEL clock mux: 00 SMCLK | 01 SMCLK:2 | 10 SMCLK:4 | 11 SMCLK:8
    ----------------------------------------------------------------
    with BTSSEL select btclk_w <=
        SMCLK   when "00",
        SMCLK_2 when "01",
        SMCLK_4 when "10",
        SMCLK_8 when others;

    ----------------------------------------------------------------
    -- BTCNT 32-bit Timer (Up-Mode). BTHOLD drives the active-low EN,
    -- BTCLR clears, EUQ0 wraps it.
    ----------------------------------------------------------------
    cnt_en_w <= not BTHOLD;

    BTCNT_INST : bit_Timer
        generic map (n => n)
        port map (
            clk       => btclk_w,
            rst       => BTCLR,
            ena       => cnt_en_w,
            EQUY      => EUQ0_w,
            timer_val => BTCNT_w
        );

    ----------------------------------------------------------------
    -- Output Unit -> PWM_out. Both comparators live here: equy_out is EUQ0
    -- (BTCNT = BTCL0) and equx_out is EUQ1 (BTCNT = BTCL1).
    ----------------------------------------------------------------
    

    OUT_UNIT_INST : OUTPUT_UNIT
        generic map (n => n)
        port map (
            y_i        => BTCL0_q,      -- period
            x_i        => BTCL1_q,      -- duty
            timer_i    => BTCNT_w,
            ena_i      => BTOUTEN,
            clk_i      => btclk_w,
            pwm_mode_i => BTOUTMD,
            pwm_out    => PWM_out,
            equy_out   => EUQ0_w,
            equx_out   => EUQ1_w
        );

    ----------------------------------------------------------------
    -- Latch BTCL0 / Latch BTCL1, enabled by HEU0 (O1)
    ----------------------------------------------------------------
    HEU0_w <= BTCLR or EUQ0_w;

    BTCL_LATCH : process (HEU0_w, BTCMPR0, BTCMPR1)
    begin
        if HEU0_w = '1' then
            BTCL0_q <= BTCMPR0;
            BTCL1_q <= BTCMPR1;
        end if;
    end process;

    ----------------------------------------------------------------
    -- CAPISEL mux: 00 CAPIN1 | 01 CAPIN2 | 10 VCC | 11 GND
    -- CAPIN1/CAPIN2 are external pins, so a 2FF synchroniser precedes the
    -- edge detector; the third flop supplies the edge history.
    ----------------------------------------------------------------
    with CAPISEL select cap_src_w <=
        CAPIN1 when "00",
        CAPIN2 when "01",
        '1'    when "10",
        '0'    when others;

    CAP_SYNC : process (btclk_w)
    begin
        if rising_edge(btclk_w) then
            cap_s1_q <= cap_src_w;
            cap_s2_q <= cap_s1_q;
            cap_s3_q <= cap_s2_q;
        end if;
    end process;

    -- Capture Mode (PDF text): 0,3 disabled | 1 rising | 2 falling
    with CAPMD select cap_evt_w <=
        (    cap_s2_q and not cap_s3_q) when "01",
        (not cap_s2_q and     cap_s3_q) when "10",
        '0'                             when others;

    ----------------------------------------------------------------
    -- BTCNT_CAPTURE on event register -> BTCAPR
    ----------------------------------------------------------------
    BTCNT_CAPTURE : process (btclk_w)
    begin
        if rising_edge(btclk_w) then
            if cap_evt_w = '1' then
                BTCAPR_q <= BTCNT_w;
            end if;
        end if;
    end process;

    BTCAPR <= BTCAPR_q;

    ----------------------------------------------------------------
    -- BTINT mux -> BTIFG : 00 EUQ0 | 01 EUQ1 | 10 capture event
    ----------------------------------------------------------------
    with BTINT select BTIFG <=
        EUQ0_w    when "00",
        EUQ1_w    when "01",
        cap_evt_w when "10",
        '0'       when others;

end architecture struct;
