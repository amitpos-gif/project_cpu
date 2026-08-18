create_clock -name INPUT_CLK -period 20.000 [get_ports {clk_i}]
derive_pll_clocks
derive_clock_uncertainty
set_false_path -from [get_ports {rst_i}]