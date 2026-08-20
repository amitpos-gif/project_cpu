library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_unsigned.all; 
USE work.aux_package.all;
------------------------------------
ENTITY OUTPUT_UNIT is
      GENERIC (n : INTEGER := 32
	); 
  PORT 
  (  
	      y_i           : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
          x_i           : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
		  timer_i       : IN  STD_LOGIC_VECTOR(n-1 DOWNTO 0);
          ena_i         : in  STD_LOGIC;
          clk_i         : in  std_logic;
          rst_i         : in  std_logic;
          pwm_mode_i    : in  std_logic;
          pwm_out       : out std_logic;
          equy_out      : out std_logic;
          equx_out      : out std_logic
          
            
  ); 
END OUTPUT_UNIT;
----------------------------------------------------------------
Architecture struct of OUTPUT_UNIT is
    signal equ_btcl0_w : std_logic;
    signal equ_btcl1_w : std_logic;
    signal pwm_out_w : std_logic := '0';
   
---------------------------------------------------------------
begin

    equ_btcl0_w <= '1' when (timer_i = Y_i) else '0';
    equ_btcl1_w <= '1' when (timer_i = X_i) else '0';
    equy_out <= equ_btcl0_w;
    equx_out <= equ_btcl1_w;

    process(clk_i, rst_i)
        begin
            if rst_i = '1' then
                pwm_out_w <= '0';
            elsif (rising_edge(clk_i)) then
                if (ena_i = '1') then
                    case pwm_mode_i is
                        --mode 0 
                        when '0' => 
                            if (equ_btcl0_w ='1') then
                                pwm_out_w <= '0';
                            elsif equ_btcl1_w = '1' then
                                pwm_out_w <= '1';
                            end if;
                            --mode 1
                        when '1' => 
                            if (equ_btcl0_w ='1') then
                                pwm_out_w <= '1';
                            elsif equ_btcl1_w = '1' then
                                pwm_out_w <= '0';  
                            end if; 
                    
                        when others => null;
                    end case;
                end if;
            end if;
        end process;
pwm_out <= pwm_out_w;
end struct;
