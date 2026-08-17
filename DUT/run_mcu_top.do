# run_mcu_top.do
# ModelSim compile + simulate script for mcu_top / tb_mcu_top.
# Run from within this folder: at the ModelSim prompt, "do run_mcu_top.do"

if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vcom -2008 cond_compilation_package.vhd
vcom -2008 const_package.vhd
vcom -2008 aux_package.vhd
vcom -2008 IFETCH.VHD
vcom -2008 IDECODE.VHD
vcom -2008 EXECUTE.VHD
vcom -2008 CONTROL.VHD
vcom -2008 DMEMORY.VHD
vcom -2008 MUL.vhd
vcom -2008 sync.vhd
vcom -2008 divider_accelerator.vhd
vcom -2008 RV32I_CORE.vhd
vcom -2008 gpio_pkg.vhd
vcom -2008 addr_decoder_gpio.vhd
vcom -2008 d_latch_byte.vhd
vcom -2008 tristate_byte.vhd
vcom -2008 hex7seg_decoder.vhd
vcom -2008 gpio_peripherals.vhd
vcom -2008 BidirPin.vhd
vcom -2008 mcu_top.vhd
vcom -2008 tb_mcu_top.vhd

vsim -voptargs=+acc work.tb_mcu_top

add wave -divider "Clock / Reset"
add wave -radix binary /tb_mcu_top/clk_i
add wave -radix binary /tb_mcu_top/rst_i

add wave -divider "CPU core"
add wave -radix hex    /tb_mcu_top/DUT/CORE/pc_w
add wave -radix hex    /tb_mcu_top/DUT/CORE/instruction_w
add wave -radix hex    /tb_mcu_top/DUT/CORE/alu_res_w
add wave -radix binary /tb_mcu_top/DUT/CORE/reg_write_w
add wave -radix binary /tb_mcu_top/DUT/mem_write_w
add wave -radix binary /tb_mcu_top/DUT/mem_read_w

add wave -divider "Peripheral bus (BidirPin)"
add wave -radix hex    /tb_mcu_top/DUT/io_address_w
add wave -radix hex    /tb_mcu_top/DUT/io_data_w

add wave -divider "GPIO outputs"
add wave -radix hex /tb_mcu_top/LEDR
add wave -radix hex /tb_mcu_top/HEX0
add wave -radix hex /tb_mcu_top/HEX1
add wave -radix hex /tb_mcu_top/HEX2
add wave -radix hex /tb_mcu_top/HEX3
add wave -radix hex /tb_mcu_top/HEX4
add wave -radix hex /tb_mcu_top/HEX5

add wave -divider "GPIO input"
add wave -radix hex /tb_mcu_top/SW

run 5000 ns

wave zoom full
