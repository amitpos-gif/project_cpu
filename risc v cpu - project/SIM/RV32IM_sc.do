onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider "TESTBENCH"
add wave -label clk  sim:/tb_RV32I_SC/clk_i
add wave -label rst  sim:/tb_RV32I_SC/rst_i

add wave -divider "CORE OUTPUTS"
add wave -hex -label pc           sim:/tb_RV32I_SC/pc_o
add wave -hex -label instruction  sim:/tb_RV32I_SC/instruction_o
add wave -hex -label alu_res      sim:/tb_RV32I_SC/alu_res_o
add wave -hex -label write_data   sim:/tb_RV32I_SC/write_data_o
add wave -hex -label read_data1   sim:/tb_RV32I_SC/read_data1_o
add wave -hex -label read_data2   sim:/tb_RV32I_SC/read_data2_o
add wave       -label RegWrite    sim:/tb_RV32I_SC/RegWrite_ctrl_o
add wave       -label MemWrite    sim:/tb_RV32I_SC/MemWrite_ctrl_o
add wave       -label Branch      sim:/tb_RV32I_SC/Branch_ctrl_o
add wave       -label brTaken     sim:/tb_RV32I_SC/brTaken_o
add wave -hex -label dtcm_addr    sim:/tb_RV32I_SC/dtcm_addr_o
add wave -hex -label dtcm_wr      sim:/tb_RV32I_SC/dtcm_data_wr_o
add wave -hex -label dtcm_rd      sim:/tb_RV32I_SC/dtcm_data_rd_o
add wave -unsigned -label CLKCNT  sim:/tb_RV32I_SC/mclk_cnt_o

add wave -divider "STAGE INTERNALS"
add wave -group IFETCH   -r -hex sim:/tb_RV32I_SC/CORE/IFE/*
add wave -group IDECODE  -r -hex sim:/tb_RV32I_SC/CORE/ID/*
add wave -group CONTROL  -r -hex sim:/tb_RV32I_SC/CORE/CTL/*
add wave -group EXECUTE  -r -hex sim:/tb_RV32I_SC/CORE/EXE/*
add wave -group MUL      -r -hex sim:/tb_RV32I_SC/CORE/MUL_INST/*
add wave -group DMEM     -r -hex sim:/tb_RV32I_SC/CORE/MEM/*

configure wave -namecolwidth 280
configure wave -valuecolwidth 120
configure wave -timelineunits ns
update
