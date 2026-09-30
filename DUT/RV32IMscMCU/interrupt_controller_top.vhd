-------------------------------------------------------------------------------
-- interrupt_controller_top.vhd
--
-- Structural interrupt-controller wrapper containing the address decoder,
-- IE/IFG/TYPE registers, priority selection, and the byte-wide MMIO interface.
-- During active-low INTA, TYPE is driven onto Data without using Address.
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE WORK.aux_package.ALL;

ENTITY interrupt_controller_top IS
    PORT (
        smclk_i     : IN    STD_LOGIC;
        rst_i       : IN    STD_LOGIC;

        Address     : IN    STD_LOGIC_VECTOR(13 DOWNTO 0);
        Data        : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        MemRead     : IN    STD_LOGIC;
        MemWrite    : IN    STD_LOGIC;

        BTIFG_i     : IN    STD_LOGIC;
        KEY_irq_i   : IN    STD_LOGIC_VECTOR(2 DOWNTO 0);
        GIE_i       : IN    STD_LOGIC;
        INTA_i      : IN    STD_LOGIC;

        INTR_o      : OUT   STD_LOGIC
    );
END ENTITY interrupt_controller_top;

ARCHITECTURE structural OF interrupt_controller_top IS
    SIGNAL cs_ie_w       : STD_LOGIC;
    SIGNAL cs_ifg_w      : STD_LOGIC;
    SIGNAL cs_type_w     : STD_LOGIC;
    SIGNAL ie_we_w       : STD_LOGIC;
    SIGNAL ifg_we_w      : STD_LOGIC;
    SIGNAL ie_w          : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ifg_w         : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL type_w        : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
    ADDRESS_DECODER : addr_decoder_interrupt
        PORT MAP (
            Address => Address,
            CS_IE   => cs_ie_w,
            CS_IFG  => cs_ifg_w,
            CS_TYPE => cs_type_w
        );

    ie_we_w  <= cs_ie_w  AND MemWrite;
    ifg_we_w <= cs_ifg_w AND MemWrite;

    CONTROLLER : interrupt_controller
        PORT MAP (
            smclk_i    => smclk_i,
            rst_i      => rst_i,
            IE_we_i    => ie_we_w,
            IFG_we_i   => ifg_we_w,
            reg_data_i => Data,
            BTIFG_i    => BTIFG_i,
            KEY_irq_i  => KEY_irq_i,
            GIE_i      => GIE_i,
            INTA_i     => INTA_i,
            IE_o       => ie_w,
            IFG_o      => ifg_w,
            TYPE_o     => type_w,
            INTR_o     => INTR_o
        );

    -- TYPE has priority during the acknowledge protocol because the controller
    -- must drive it without placing an address on the Address BUS.
    Data <= type_w WHEN INTA_i = '0' ELSE
            ie_w   WHEN MemRead = '1' AND cs_ie_w = '1' ELSE
            ifg_w  WHEN MemRead = '1' AND cs_ifg_w = '1' ELSE
            type_w WHEN MemRead = '1' AND cs_type_w = '1' ELSE
            (OTHERS => 'Z');
END ARCHITECTURE structural;
