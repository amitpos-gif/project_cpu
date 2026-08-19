-------------------------------------------------------------------------------
-- interrupt_controller.vhd
--
-- Required (non-bonus) interrupt controller:
--   IFG(2) = Basic Timer, TYPE 0x10, highest maskable priority
--   IFG(3) = KEY1,        TYPE 0x14
--   IFG(4) = KEY2,        TYPE 0x18
--   IFG(5) = KEY3,        TYPE 0x1C, lowest priority
-- Bits 7:6 and 1:0 of IE/IFG are reserved and remain zero.
--
-- RESET is the system NMI path (TYPE 0x00).  It resets this controller directly
-- and is therefore not stored in IE or IFG.
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY interrupt_controller IS
    PORT (
        smclk_i      : IN  STD_LOGIC;
        rst_i        : IN  STD_LOGIC;

        IE_we_i      : IN  STD_LOGIC;
        IFG_we_i     : IN  STD_LOGIC;
        reg_data_i   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);

        BTIFG_i      : IN  STD_LOGIC;
        KEY_irq_i    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0);

        GIE_i        : IN  STD_LOGIC;
        INTA_i       : IN  STD_LOGIC; -- active-low interrupt acknowledge

        IE_o         : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        IFG_o        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        TYPE_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        INTR_o       : OUT STD_LOGIC
    );
END ENTITY interrupt_controller;

ARCHITECTURE rtl OF interrupt_controller IS
    SIGNAL ie_q            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ifg_q           : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL type_q          : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL pending_w       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL inta_prev_q     : STD_LOGIC;
    SIGNAL btifg_prev_q    : STD_LOGIC;
BEGIN
    PROCESS (smclk_i, rst_i)
        VARIABLE ie_v      : STD_LOGIC_VECTOR(7 DOWNTO 0);
        VARIABLE ifg_v     : STD_LOGIC_VECTOR(7 DOWNTO 0);
        VARIABLE pending_v : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        IF rst_i = '1' THEN
            ie_q         <= (OTHERS => '0');
            ifg_q        <= (OTHERS => '0');
            type_q       <= (OTHERS => '0');
            inta_prev_q  <= '1';
            btifg_prev_q <= '0';

        ELSIF rising_edge(smclk_i) THEN
            ie_v  := ie_q;
            ifg_v := ifg_q;

            -- IE and IFG are byte-wide software read/write registers.  Only
            -- the four required-source bits are implemented.
            IF IE_we_i = '1' THEN
                ie_v := "00" & reg_data_i(5 DOWNTO 2) & "00";
            END IF;

            IF IFG_we_i = '1' THEN
                ifg_v := "00" & reg_data_i(5 DOWNTO 2) & "00";
            END IF;

            -- An acknowledged Basic-Timer interrupt is cleared automatically.
            -- KEY flags are intentionally not cleared here; their ISRs clear
            -- them through a software write to IFG.
            IF inta_prev_q = '1' AND INTA_i = '0' AND type_q = x"10" THEN
                ifg_v(2) := '0';
            END IF;

            -- Source events have priority over a simultaneous software/ack
            -- clear, preventing a new event from being lost.
            IF BTIFG_i = '1' AND btifg_prev_q = '0' THEN
                ifg_v(2) := '1';
            END IF;

            IF KEY_irq_i(0) = '1' THEN
                ifg_v(3) := '1';
            END IF;

            IF KEY_irq_i(1) = '1' THEN
                ifg_v(4) := '1';
            END IF;

            IF KEY_irq_i(2) = '1' THEN
                ifg_v(5) := '1';
            END IF;

            -- Force all unimplemented UART/reserved bits to zero.
            ie_v(7 DOWNTO 6)  := "00";
            ie_v(1 DOWNTO 0)  := "00";
            ifg_v(7 DOWNTO 6) := "00";
            ifg_v(1 DOWNTO 0) := "00";

            pending_v := ie_v AND ifg_v;

            ie_q           <= ie_v;
            ifg_q          <= ifg_v;
            inta_prev_q    <= INTA_i;
            btifg_prev_q   <= BTIFG_i;

            -- Priority encoder: Timer, KEY1, KEY2, KEY3.
            IF pending_v(2) = '1' THEN
                type_q <= x"10";
            ELSIF pending_v(3) = '1' THEN
                type_q <= x"14";
            ELSIF pending_v(4) = '1' THEN
                type_q <= x"18";
            ELSIF pending_v(5) = '1' THEN
                type_q <= x"1C";
            ELSE
                type_q <= x"00";
            END IF;
        END IF;
    END PROCESS;

    pending_w <= ie_q AND ifg_q;

    INTR_o <= GIE_i AND
              (pending_w(2) OR pending_w(3) OR
               pending_w(4) OR pending_w(5));

    IE_o   <= ie_q;
    IFG_o  <= ifg_q;
    TYPE_o <= type_q;
END ARCHITECTURE rtl;
