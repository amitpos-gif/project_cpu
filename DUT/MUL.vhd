--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- MUL module - 16-bit multiplier using four 8-bit partial products
-- #RV32IM task: implements mul rd, rs1, rs2
-- Multiplies lower 16-bit of rs1 and rs2, result is 32-bit written to rd
-- Algorithm (Figure 6):
--   Stage 1: P0=A_low*B_low, P1=A_low*B_high, P2=A_high*B_low, P3=A_high*B_high
--   Stage 2: M=P1+P2, RESULT=P0+(M<<8)+(P3<<16)
-- MULOp_i: enable signal from CONTROL, when 0 output is zeroed
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY MUL IS
    GENERIC(
        DATA_BUS_WIDTH : integer := 32
    );
    PORT(
        -- Inputs: lower 16-bit of rs1 and rs2
        ain_i       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);  -- lower 16-bit of rs1
        bin_i       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);  -- lower 16-bit of rs2
        -- #RV32IM task: enable from CONTROL, active only when MUL instruction detected
        MULOp_i     : IN  STD_LOGIC;
        -- Output: 32-bit multiplication result
        mul_res_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
    );
END MUL;

ARCHITECTURE behavior OF MUL IS
    -- Stage 1: four 8-bit partial products
    SIGNAL P0_w : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_low  x B_low
    SIGNAL P1_w : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_low  x B_high
    SIGNAL P2_w : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_high x B_low
    SIGNAL P3_w : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- A_high x B_high
    -- Stage 2: intermediate sum and final result
    SIGNAL M_w        : STD_LOGIC_VECTOR(16 DOWNTO 0);  -- P1 + P2
    SIGNAL mul_res_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN
    -- Stage 1: compute four 8-bit partial products
    P0_w <= ain_i(7 DOWNTO 0) * bin_i(7 DOWNTO 0);   -- A_low  x B_low
    P1_w <= ain_i(7 DOWNTO 0) * bin_i(15 DOWNTO 8);  -- A_low  x B_high
    P2_w <= ain_i(15 DOWNTO 8) * bin_i(7 DOWNTO 0);  -- A_high x B_low
    P3_w <= ain_i(15 DOWNTO 8) * bin_i(15 DOWNTO 8); -- A_high x B_high

    -- Stage 2: combine partial products
    M_w <= ('0' & P1_w) + ('0' & P2_w);  -- M = P1 + P2

    -- RESULT = P0 + (M << 8) + (P3 << 16)
    mul_res_w <= (x"0000" & P0_w)
               + (x"00" & M_w(15 DOWNTO 0) & x"00")
               + (P3_w & x"0000");

    -- #RV32IM task: gate output with MULOp enable - zero when not a MUL instruction
    mul_res_o <= mul_res_w WHEN MULOp_i = '1' ELSE (others => '0');

END behavior;
