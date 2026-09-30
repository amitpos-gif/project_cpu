library ieee;
use ieee.std_logic_1164.all;
use work.aux_package.all;

entity gpio_peripherals is
    port (
        smclk    : in    std_logic;
        Address  : in    std_logic_vector(13 downto 0);
        Data     : inout std_logic_vector(7 downto 0);
        MemRead  : in    std_logic;
        MemWrite : in    std_logic;

        SW       : in    std_logic_vector(7 downto 0);  -- SW7-SW0
        LEDR     : out   std_logic_vector(7 downto 0);  -- LEDR7-LEDR0
        HEX0     : out   std_logic_vector(6 downto 0);
        HEX1     : out   std_logic_vector(6 downto 0);
        HEX2     : out   std_logic_vector(6 downto 0);
        HEX3     : out   std_logic_vector(6 downto 0);
        HEX4     : out   std_logic_vector(6 downto 0);
        HEX5     : out   std_logic_vector(6 downto 0)
    );
end entity gpio_peripherals;

architecture structural of gpio_peripherals is

    signal CS_LEDR, CS_HEX01, CS_HEX23, CS_HEX45, CS_SW : std_logic;

    signal En_LEDR_WR : std_logic;
    signal En_LEDR_RD : std_logic;
    signal En_HEX0_WR, En_HEX1_WR, En_HEX2_WR : std_logic;
    signal En_HEX3_WR, En_HEX4_WR, En_HEX5_WR : std_logic;
    signal En_HEX0_RD, En_HEX1_RD, En_HEX2_RD : std_logic;
    signal En_HEX3_RD, En_HEX4_RD, En_HEX5_RD : std_logic;
    signal En_SW_RD : std_logic;

    signal Q_LEDR : std_logic_vector(7 downto 0);
    signal Q_HEX0, Q_HEX1, Q_HEX2, Q_HEX3, Q_HEX4, Q_HEX5 : std_logic_vector(7 downto 0);

begin

    u_decoder : addr_decoder_gpio
        port map (
            Address  => Address,
            CS_LEDR  => CS_LEDR,
            CS_HEX01 => CS_HEX01,
            CS_HEX23 => CS_HEX23,
            CS_HEX45 => CS_HEX45,
            CS_SW    => CS_SW
        );
    -- prepere coressponding write enabels -- 
    En_LEDR_WR <= CS_LEDR  and MemWrite;
    En_HEX0_WR <= CS_HEX01 and MemWrite and not Address(0);
    En_HEX1_WR <= CS_HEX01 and MemWrite and Address(0);
    En_HEX2_WR <= CS_HEX23 and MemWrite and not Address(0);
    En_HEX3_WR <= CS_HEX23 and MemWrite and Address(0);
    En_HEX4_WR <= CS_HEX45 and MemWrite and not Address(0);
    En_HEX5_WR <= CS_HEX45 and MemWrite and Address(0);

    -- Read enables for the tri-state drivers on the shared Data bus --
    En_LEDR_RD <= CS_LEDR  and MemRead;
    En_HEX0_RD <= CS_HEX01 and MemRead and not Address(0);
    En_HEX1_RD <= CS_HEX01 and MemRead and Address(0);
    En_HEX2_RD <= CS_HEX23 and MemRead and not Address(0);
    En_HEX3_RD <= CS_HEX23 and MemRead and Address(0);
    En_HEX4_RD <= CS_HEX45 and MemRead and not Address(0);
    En_HEX5_RD <= CS_HEX45 and MemRead and Address(0);
    En_SW_RD   <= CS_SW    and MemRead;

    -- wirte to leds --
    u_ledr : d_latch_byte port map (clk => smclk, D => Data, En => En_LEDR_WR, Q => Q_LEDR);
    LEDR <= Q_LEDR;

    -- Read back the value currently stored in the LEDR latch --
    u_ledr_read : tristate_byte port map (D  => Q_LEDR, OE => En_LEDR_RD, Y  => Data);

  
    -- PORT_HEX0..PORT_HEX5 (0x2004-0x200D): D-latch -> 7-seg encoder --
    u_hex0 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX0_WR, Q => Q_HEX0);
    u_hex1 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX1_WR, Q => Q_HEX1);
    u_hex2 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX2_WR, Q => Q_HEX2);
    u_hex3 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX3_WR, Q => Q_HEX3);
    u_hex4 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX4_WR, Q => Q_HEX4);
    u_hex5 : d_latch_byte port map (clk => smclk, D => Data, En => En_HEX5_WR, Q => Q_HEX5);

    u_enc0 : hex7seg_decoder port map (hex_in => Q_HEX0(3 downto 0), seg => HEX0);
    u_enc1 : hex7seg_decoder port map (hex_in => Q_HEX1(3 downto 0), seg => HEX1);
    u_enc2 : hex7seg_decoder port map (hex_in => Q_HEX2(3 downto 0), seg => HEX2);
    u_enc3 : hex7seg_decoder port map (hex_in => Q_HEX3(3 downto 0), seg => HEX3);
    u_enc4 : hex7seg_decoder port map (hex_in => Q_HEX4(3 downto 0), seg => HEX4);
    u_enc5 : hex7seg_decoder port map (hex_in => Q_HEX5(3 downto 0), seg => HEX5);

    -- Read back the byte stored in each HEX latch --
    u_hex0_read : tristate_byte port map (D  => Q_HEX0, OE => En_HEX0_RD, Y  => Data);
    u_hex1_read : tristate_byte port map (D  => Q_HEX1, OE => En_HEX1_RD, Y  => Data);
    u_hex2_read : tristate_byte port map (D  => Q_HEX2, OE => En_HEX2_RD, Y  => Data);
    u_hex3_read : tristate_byte port map (D  => Q_HEX3, OE => En_HEX3_RD, Y  => Data);
    u_hex4_read : tristate_byte port map (D  => Q_HEX4, OE => En_HEX4_RD, Y  => Data);
    u_hex5_read : tristate_byte port map (D  => Q_HEX5, OE => En_HEX5_RD, Y  => Data);

    -- read back the informtion store in sw byte --
    u_sw : tristate_byte port map (D  => SW, OE => En_SW_RD, Y  => Data);

end architecture structural;
