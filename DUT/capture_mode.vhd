-------------------------------------------------------------------------------
-- capture_mode.vhd
--
-- Basic Timer input-capture unit from Figure 7.
-- CAPISEL selects the capture source and CAPMD selects the active edge.
-- On a valid selected edge, the current BTCNT value is stored in BTCAPR.
--
-- CAPMD:
--   "00" = capture disabled
--   "01" = rising-edge capture
--   "10" = falling-edge capture
--   "11" = capture disabled
--
-- CAPISEL:
--   "00" = CAPIN1
--   "01" = CAPIN2
--   "10" = VCC ('1')
--   "11" = GND ('0')
--
-- CAPISEL must be changed while CAPMD is disabled.  Otherwise, selecting a
-- source whose level differs from the previous source can look like an edge.
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY capture_mode IS
    PORT (
        rst_i       : IN  STD_LOGIC;

        CAPIN1_i    : IN  STD_LOGIC;
        CAPIN2_i    : IN  STD_LOGIC;
        CAPISEL_i   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
        CAPMD_i     : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);

        BTCNT_i     : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
        BTCAPR_o    : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
END ENTITY capture_mode;

ARCHITECTURE behavior OF capture_mode IS
    SIGNAL cap_input_w   : STD_LOGIC;
    SIGNAL cap_trigger_w : STD_LOGIC;
    SIGNAL btcapr_q      : STD_LOGIC_VECTOR(31 DOWNTO 0);
BEGIN
    ---------------------------------------------------------------------------
    -- Capture-input source multiplexer.
    ---------------------------------------------------------------------------
    WITH CAPISEL_i SELECT
        cap_input_w <= CAPIN1_i WHEN "00",
                       CAPIN2_i WHEN "01",
                       '1'      WHEN "10",
                       '0'      WHEN OTHERS;

    ---------------------------------------------------------------------------
    -- Convert the requested input edge into a rising edge of one internal
    -- capture trigger.  Rising mode passes the input; falling mode inverts it.
    -- Disabled modes hold the trigger low.
    ---------------------------------------------------------------------------
    WITH CAPMD_i SELECT
        cap_trigger_w <= cap_input_w     WHEN "01",
                         NOT cap_input_w WHEN "10",
                         '0'             WHEN OTHERS;

    ---------------------------------------------------------------------------
    -- The selected external edge clocks the capture register directly.  There
    -- is no periodic sampling clock in this unit.
    ---------------------------------------------------------------------------
    PROCESS (cap_trigger_w, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            btcapr_q <= (OTHERS => '0');

        ELSIF rising_edge(cap_trigger_w) THEN
            btcapr_q <= BTCNT_i;
        END IF;
    END PROCESS;

    BTCAPR_o <= btcapr_q;
END ARCHITECTURE behavior;
