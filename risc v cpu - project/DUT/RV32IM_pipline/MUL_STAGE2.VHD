LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;


ENTITY MUL_STAGE2 IS
   GENERIC(
      DATA_WIDTH : integer := 32
   );
   PORT (
    p0_i : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    p1_i : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    p2_i : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    p3_i : IN STD_LOGIC_VECTOR(15 DOWNTO 0);

    mulop_i : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    mul_stage1_res_o : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0)

   );

end MUL_STAGE2;

ARCHITECTURE behavior OF MUL_STAGE2 IS

   SIGNAL m_w            : unsigned(16 DOWNTO 0);
   SIGNAL mul_stage1_res_w : unsigned(31 DOWNTO 0);

BEGIN 

   m_w <= ('0' & unsigned(p1_i)) + ('0' & unsigned(p2_i));
   
   mul_stage1_res_w <= ("0000000000000000" & unsigned(p0_i)) + 
                        ("0000000" & m_w & "00000000") + 
                        ( unsigned(p3_i) & "0000000000000000");

mul_stage1_res_o <= std_logic_vector(mul_stage1_res_w) when mulop_i /= "0000000" else (others => '0');        

END behavior;

