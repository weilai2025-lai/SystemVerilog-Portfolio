#create 100Mhz clock

create_clock -name clk -period 10.000 [get_ports {clk}]

#automatically solve uncertainty

derive_pll_clocks
derive_clock_uncertainty