onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider "TESTBENCH"
add wave -label clk           sim:/tb_RV32I/clk_i
add wave -label rst           sim:/tb_RV32I/rst_i
add wave -hex -label BPADDR   sim:/tb_RV32I/BPADDR_i

add wave -divider "PIPELINE PC / INSTR"
add wave -hex sim:/tb_RV32I/IFpc_o   sim:/tb_RV32I/IFinstruction_o
add wave -hex sim:/tb_RV32I/IDpc_o   sim:/tb_RV32I/IDinstruction_o
add wave -hex sim:/tb_RV32I/EXpc_o   sim:/tb_RV32I/EXinstruction_o
add wave -hex sim:/tb_RV32I/MEMpc_o  sim:/tb_RV32I/MEMinstruction_o
add wave -hex sim:/tb_RV32I/WBpc_o   sim:/tb_RV32I/WBinstruction_o

add wave -divider "HAZARD / IPC"
add wave -label STRIGGER          sim:/tb_RV32I/STRIGGER_o
add wave -unsigned -label STCNT   sim:/tb_RV32I/STCNT_o
add wave -unsigned -label FHCNT   sim:/tb_RV32I/FHCNT_o
add wave -unsigned -label CLKCNT  sim:/tb_RV32I/CLKCNT_o

add wave -divider "STAGE INTERNALS"
add wave -group IFETCH   -r -hex sim:/tb_RV32I/CORE/IFETCH_inst/*
add wave -group IF_ID    -r -hex sim:/tb_RV32I/CORE/IF_ID_inst/*
add wave -group CONTROL  -r -hex sim:/tb_RV32I/CORE/CONTROL_inst/*
add wave -group IDECODE  -r -hex sim:/tb_RV32I/CORE/IDECODE_inst/*
add wave -group ID_EX    -r -hex sim:/tb_RV32I/CORE/ID_EX_inst/*
add wave -group EXECUTE  -r -hex sim:/tb_RV32I/CORE/EXECUTE_inst/*
add wave -group MUL1     -r -hex sim:/tb_RV32I/CORE/MUL1_inst/*
add wave -group EX_MEM   -r -hex sim:/tb_RV32I/CORE/EX_MEM_inst/*
add wave -group DMEM     -r -hex sim:/tb_RV32I/CORE/DMEM_inst/*
add wave -group MEM_WB   -r -hex sim:/tb_RV32I/CORE/MEM_WB_inst/*
add wave -group WB_MUX   -r -hex sim:/tb_RV32I/CORE/WB_MUX_inst/*
add wave -group FORWARD  -r -hex sim:/tb_RV32I/CORE/FWD_inst/*
add wave -group STALL    -r -hex sim:/tb_RV32I/CORE/STALL_inst/*
add wave -group FLUSH    -r -hex sim:/tb_RV32I/CORE/FLUSH_inst/*

configure wave -namecolwidth 280
configure wave -valuecolwidth 120
configure wave -timelineunits ns
update
