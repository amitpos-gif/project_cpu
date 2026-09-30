
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY Mul_Stage1 IS
    GENERIC (
        DATA_BUS_WIDTH : integer := 32
    );
    PORT (
        --Inputs
        Ain  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        Bin  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        -- Width matches the opcode field (7 bits, instruction[6:0]) as a placeholder
    
        MULOP : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);

        --Outputs: four 8x8 partial products
        P0_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_low  x B_low
        P1_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_low  x B_high
        P2_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_high x B_low
        P3_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)   -- A_high x B_high
    );
END Mul_Stage1;


ARCHITECTURE struct OF Mul_Stage1 IS
BEGIN

    -- A_low=Ain[7:0], A_high=Ain[15:8]
    -- B_low=Bin[7:0], B_high=Bin[15:8]
    P0_o <= std_logic_vector(unsigned(Ain(7  DOWNTO 0)) * unsigned(Bin(7  DOWNTO 0))) WHEN MULOP /= "0000000" ELSE (OTHERS => '0');
    P1_o <= std_logic_vector(unsigned(Ain(7  DOWNTO 0)) * unsigned(Bin(15 DOWNTO 8))) WHEN MULOP /= "0000000" ELSE (OTHERS => '0');
    P2_o <= std_logic_vector(unsigned(Ain(15 DOWNTO 8)) * unsigned(Bin(7  DOWNTO 0))) WHEN MULOP /= "0000000" ELSE (OTHERS => '0');
    P3_o <= std_logic_vector(unsigned(Ain(15 DOWNTO 8)) * unsigned(Bin(15 DOWNTO 8))) WHEN MULOP /= "0000000" ELSE (OTHERS => '0');

END struct;