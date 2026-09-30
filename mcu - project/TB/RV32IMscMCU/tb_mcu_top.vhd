-------------------------------------------------------------------------------
-- tb_mcu_top.vhd
-- Simple testbench for the complete MCU: core, GPIO, pushbuttons, timer,
-- interrupt controller, synchronizer, and divider accelerator.
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE WORK.aux_package.ALL;

ENTITY tb_mcu_top IS
END ENTITY tb_mcu_top;

ARCHITECTURE sim OF tb_mcu_top IS
    -- Simulation clocks match the selected FPGA configuration:
    -- MCLK = SMCLK = 25 MHz, DIVCLK = 125 MHz.
    CONSTANT MCLK_PERIOD   : TIME := 40 ns;
    CONSTANT DIVCLK_PERIOD : TIME := 8 ns;

    SIGNAL rst_i    : STD_LOGIC := '1';
    SIGNAL clk_i    : STD_LOGIC := '0';
    SIGNAL smclk_i  : STD_LOGIC := '0';
    SIGNAL divclk_i : STD_LOGIC := '0';

    -- DE10 inputs. Keys are active-low: '1' = released, '0' = pressed.
    SIGNAL KEY1   : STD_LOGIC := '1';
    SIGNAL KEY2   : STD_LOGIC := '1';
    SIGNAL KEY3   : STD_LOGIC := '1';
    SIGNAL CAPIN1 : STD_LOGIC := '0';
    SIGNAL CAPIN2 : STD_LOGIC := '0';
    SIGNAL SW     : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    SIGNAL LEDR : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL PWM  : STD_LOGIC;
    SIGNAL HEX0 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL HEX1 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL HEX2 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL HEX3 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL HEX4 : STD_LOGIC_VECTOR(6 DOWNTO 0);
    SIGNAL HEX5 : STD_LOGIC_VECTOR(6 DOWNTO 0);
BEGIN
    DUT : mcu_top
        PORT MAP (
            rst_i    => rst_i,
            clk_i    => clk_i,
            divclk_i => divclk_i,
            smclk    => smclk_i,
            KEY1     => KEY1,
            KEY2     => KEY2,
            KEY3     => KEY3,
            CAPIN1   => CAPIN1,
            CAPIN2   => CAPIN2,
            SW       => SW,
            LEDR     => LEDR,
            PWM      => PWM,
            HEX0     => HEX0,
            HEX1     => HEX1,
            HEX2     => HEX2,
            HEX3     => HEX3,
            HEX4     => HEX4,
            HEX5     => HEX5
        );

    -- MCLK and SMCLK are synchronous and have the same phase.
    MCLK_SMCLK_GEN : PROCESS
    BEGIN
        clk_i   <= '0';
        smclk_i <= '0';
        WAIT FOR MCLK_PERIOD / 2;
        clk_i   <= '1';
        smclk_i <= '1';
        WAIT FOR MCLK_PERIOD / 2;
    END PROCESS;

    DIVCLK_GEN : PROCESS
    BEGIN
        divclk_i <= '0';
        WAIT FOR DIVCLK_PERIOD / 2;
        divclk_i <= '1';
        WAIT FOR DIVCLK_PERIOD / 2;
    END PROCESS;

    STIMULUS : PROCESS
    BEGIN
        -- Reset for five MCLK cycles, then run the program loaded in ITCM.
        rst_i <= '1';
        WAIT FOR 5 * MCLK_PERIOD;
        rst_i <= '0';

        -- Inputs remain idle by default. They may be changed from the
        -- ModelSim Objects/Wave window or by adding stimulus below.
        WAIT;
    END PROCESS;
END ARCHITECTURE sim;
