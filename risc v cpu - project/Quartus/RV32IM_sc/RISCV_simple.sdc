#**************************************************************
# 					Create Clock
# Constrain clock port clk with a 20-ns requirement
#**************************************************************
create_clock -name clk -period 20 [get_ports {clk_i}]

#**************************************************************
# Automatically apply a generate clock on the output of phase-locked loops (PLLs)
# This command can be safely left in the SDC even if no PLLs exist in the design
#**************************************************************
derive_pll_clocks -create_base_clocks

#**************************************************************
# Set False Path
#**************************************************************
#set_false_path -from [get_clocks {clk}] -to [get_clocks {altera_reserved_tck}]
