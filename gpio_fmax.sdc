# Standalone timing constraint for gpio_peripherals.
# Start with a 100 MHz SMCLK target; TimeQuest Fmax Summary reports the
# maximum achievable frequency after a full fit.
create_clock -name SMCLK -period 10.000 [get_ports {smclk_i}]

derive_clock_uncertainty
