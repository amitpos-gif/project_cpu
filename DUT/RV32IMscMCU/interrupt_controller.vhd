-------------------------------------------------------------------------------
-- interrupt_controller.vhd
--
-- Required interrupt controller:
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

        IE_we_i      : IN  STD_LOGIC;  -- write enable for IE register
        IFG_we_i     : IN  STD_LOGIC;  -- write enable for IFG register
        reg_data_i   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0); -- data bus for IE/IFG writes

        BTIFG_i      : IN  STD_LOGIC; -- active-high basic timer interrupt request
        KEY_irq_i    : IN  STD_LOGIC_VECTOR(2 DOWNTO 0); -- active-high pushbutton interrupt requests

        GIE_i        : IN  STD_LOGIC;  -- global interrupt enable
        INTA_i       : IN  STD_LOGIC; -- active-low interrupt acknowledge, from cpu_top

        IE_o         : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- going to the CPU, interrupt-enable register
        IFG_o        : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- going to the CPU, interrupt-flag register
        TYPE_o       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- going to the CPU, interrupt-type register
        INTR_o       : OUT STD_LOGIC -- active-high interrupt request, to cpu_top
    );
END ENTITY interrupt_controller;

ARCHITECTURE rtl OF interrupt_controller IS
    SIGNAL ie_q            : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- interrupt-enable register
    SIGNAL ifg_q           : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- interrupt-flag register
    SIGNAL type_q          : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- interrupt-type register
    SIGNAL pending_w       : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- pending interrupt sources, ie AND ifg
    SIGNAL inta_prev_q     : STD_LOGIC;                     -- previous sample of INTA, to detect rising edge
    SIGNAL btifg_prev_q    : STD_LOGIC;                     -- previous sample of BTIFG, to detect rising edge
BEGIN
    PROCESS (smclk_i, rst_i)
        VARIABLE ie_v      : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- next value of ie_q
        VARIABLE ifg_v     : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- next value of ifg_q
        VARIABLE pending_v : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- next value of pending_w
    BEGIN
        IF rst_i = '1' THEN
            ie_q         <= (OTHERS => '0');
            ifg_q        <= (OTHERS => '0');
            type_q       <= (OTHERS => '0');
            inta_prev_q  <= '1';
            btifg_prev_q <= '0';

        ELSIF rising_edge(smclk_i) THEN
        -- load the current values of the registers into the variables, to be updated below
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

            -- Clear a synchronous Basic-Timer request only after cycle 1 has finished - cpu has interapt, no humen presing the button, can by cleared synchronous  
            IF inta_prev_q = '0' AND INTA_i = '1' AND type_q = x"10" THEN
                ifg_v(2) := '0';
            END IF;

            -- Source events have priority over a simultaneous software/ack
            -- clear, preventing a new event from being lost.
            -- main file is clening ifg(2) when he pudh 0 to the addressed of the ifg at the end og ISR KEY_J , J:={1,2,3}
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

            -- Force all BONOS option from hanan that we didnt implemented "UART/reserved bits" to zero.
            ie_v(7 DOWNTO 6)  := "00";
            ie_v(1 DOWNTO 0)  := "00";
            ifg_v(7 DOWNTO 6) := "00";
            ifg_v(1 DOWNTO 0) := "00";

            pending_v := ie_v AND ifg_v;

            ie_q           <= ie_v;
            ifg_q          <= ifg_v;
            inta_prev_q    <= INTA_i;
            btifg_prev_q   <= BTIFG_i;

            -- Priority encoder: Timer, KEY1, KEY2, KEY3  := ho is the type of the highest-priority pending interrupt source.
            IF    pending_v(2) = '1'  THEN type_q <= x"10";
            ELSIF pending_v(3) = '1'  THEN type_q <= x"14";
            ELSIF pending_v(4) = '1'  THEN type_q <= x"18";
            ELSIF pending_v(5) = '1'  THEN type_q <= x"1C";
            ELSE  type_q <= x"00";
            END IF;

        END IF;
    END PROCESS;

    pending_w <= ie_q AND ifg_q;

    INTR_o <= GIE_i AND (pending_w(2) 
                        OR pending_w(3)
                        OR pending_w(4) 
                        OR pending_w(5));

    IE_o   <= ie_q;
    IFG_o  <= ifg_q;
    TYPE_o <= type_q;
END ARCHITECTURE rtl;
