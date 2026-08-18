library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity bit_Timer is
    generic (
        n : integer := 32
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        ena       : in  std_logic;
        EQUY      : in std_logic;
        timer_val : out std_logic_vector(n-1 downto 0)
    );
end entity bit_Timer;
---------------------------------------------------------  
architecture rtl of bit_Timer is
    signal count_q : std_logic_vector (n-1 downto 0):= (others => '0'); 
begin
    process (clk,rst)
    begin
        if (rst = '1') then
            count_q <= (others => '0');
        elsif (rising_edge(clk)) then
           if ena = '1' then
                if EQUY = '1' then
                    count_q <= (others => '0');
                else  
		            count_q <= count_q + 1;
                end if;
           end if;
	     end if;
    end process;
	
    timer_val <= count_q;
end rtl;
