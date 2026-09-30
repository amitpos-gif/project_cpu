# RV32IM saved waveform layout.
# Load this macro only after work.tb_mcu_top has been compiled and started.

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider "CLOCKS AND RESET"
add wave /tb_mcu_top/clk_i
add wave /tb_mcu_top/smclk_i
add wave /tb_mcu_top/divclk_i
add wave /tb_mcu_top/rst_i

add wave -divider "CPU"
add wave -radix hex /tb_mcu_top/DUT/pc_w
add wave -radix hex /tb_mcu_top/DUT/instruction_w
add wave /tb_mcu_top/DUT/reg_write_w
add wave /tb_mcu_top/DUT/mem_read_w
add wave /tb_mcu_top/DUT/mem_write_w
add wave -radix hex /tb_mcu_top/DUT/alu_res_w

add wave -divider "PERIPHERAL BUS"
add wave -radix hex /tb_mcu_top/DUT/io_address_w
add wave -radix hex /tb_mcu_top/DUT/io_data_w

add wave -divider "INTERRUPTS"
add wave -radix binary /tb_mcu_top/DUT/key_irq_w
add wave /tb_mcu_top/DUT/btifg_w
add wave /tb_mcu_top/DUT/intr_w
add wave /tb_mcu_top/DUT/inta_w
add wave /tb_mcu_top/DUT/gie_w

add wave -divider "BOARD INPUTS AND OUTPUTS"
add wave -radix binary /tb_mcu_top/KEY1
add wave -radix binary /tb_mcu_top/KEY2
add wave -radix binary /tb_mcu_top/KEY3
add wave -radix hex /tb_mcu_top/SW
add wave -radix hex /tb_mcu_top/LEDR
add wave /tb_mcu_top/PWM
add wave -radix binary /tb_mcu_top/HEX0
add wave -radix binary /tb_mcu_top/HEX1
add wave -radix binary /tb_mcu_top/HEX2
add wave -radix binary /tb_mcu_top/HEX3
add wave -radix binary /tb_mcu_top/HEX4
add wave -radix binary /tb_mcu_top/HEX5

TreeUpdate [SetDefaultTree]
update
wave zoom full
