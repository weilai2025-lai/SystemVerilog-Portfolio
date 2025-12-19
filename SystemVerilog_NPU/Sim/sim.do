quit -sim
.main clear

vlib work
vlog ../nn_config_pkg.sv
vlog ../sig_rom.sv
vlog ../weight_memory.sv
vlog ../maxfinder.sv
vlog ../neuron.sv
vlog ../Layer1.sv
vlog ../Layer2.sv
vlog ../Layer3.sv
vlog ../Layer4.sv
vlog ../dnn.sv
vlog ../*.sv
