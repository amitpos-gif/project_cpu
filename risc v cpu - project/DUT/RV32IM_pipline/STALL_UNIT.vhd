
-- Detects two hazard types that require a pipeline stall:
--
--  1. Load-Use Hazard:
--     The instruction in EX is a LOAD (ID/EX.MemRead = 1).
--     The instruction in ID reads a register that the load writes.
--     Fix: stall 1 cycle, then MEM/WB forwarding handles it.
--
--  2. MUL-Use Hazard:
--     The instruction in EX is a MUL (ID/EX.MULOp = 1).
--     The instruction in ID reads a register that the MUL writes.
--     Reason: MUL is a 2-cycle operation (EX + MEM), so the result is
--     only ready at MEM/WB. After 1 stall cycle the dependent instruction
--     reaches EX when MUL's result is in MEM/WB, allowing forwarding.
--
-- When Stall_o = '1':
--   - PC register is frozen (stall_i to IFETCH_P)
--   - IF/ID register is frozen (stall_i to IFID_REG)
--   - ID/EX register is cleared next cycle (flush_nop_o to IDEX_REG),
--     inserting a NOP bubble into the EX stage.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY STALL_UNIT IS
    PORT(
        -- From ID/EX register (instruction currently in EX stage)
        MemRead_i       : IN  STD_LOGIC;
        MULOp_i         : IN  STD_LOGIC;
        idex_rd_i            : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        -- From IF/ID register (instruction currently in ID stage)
        ifid_rs1_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        ifid_rs2_i      : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        -- Output
        Stall_o         : OUT STD_LOGIC
    );
END STALL_UNIT;

ARCHITECTURE behavior OF STALL_UNIT IS
    SIGNAL rd_nonzero_w    : STD_LOGIC;
    SIGNAL rs1_match_w     : STD_LOGIC;
    SIGNAL rs2_match_w     : STD_LOGIC;
    SIGNAL load_use_w      : STD_LOGIC;
    SIGNAL mul_use_w       : STD_LOGIC;
BEGIN
    -- rd must be non-zero (x0 writes are discarded, never a hazard)
    rd_nonzero_w <= '1' WHEN idex_rd_i /= "00000" ELSE '0';

    rs1_match_w  <= '1' WHEN idex_rd_i = ifid_rs1_i ELSE '0';
    rs2_match_w  <= '1' WHEN idex_rd_i = ifid_rs2_i ELSE '0';

    -- Load-use hazard: load in EX, dependent instruction in ID
    load_use_w   <= MemRead_i AND rd_nonzero_w AND (rs1_match_w OR rs2_match_w);

    -- MUL-use hazard: mul in EX, dependent instruction in ID
    mul_use_w    <= MULOp_i   AND rd_nonzero_w AND (rs1_match_w OR rs2_match_w);

    Stall_o      <= load_use_w OR mul_use_w;

END behavior;
