import nn_config_pkg::*;

module Layer2
	#(
		parameter int nn = 30,
		parameter int num_weight = 784,
		parameter int data_width = 16,
		parameter int layer_num = 1,
		parameter int sigmoid_size = 10,
		parameter string base_dir = base_direction
	)(
		input logic clk,
		input logic rst,
		
		input logic x_valid,
		input logic [data_width-1:0] x_in,
		output logic[nn-1:0] o_valid,
		output logic [nn*data_width-1:0] x_out_flat
	);
	
	//define each internal neuron output	
	logic [nn-1:0][data_width-1:0] layer_out_internal;
	//generate neurons automatically
	genvar i;
	generate
		for(i = 0; i < nn; i++) begin: gen_neurons
			neuron#(
				.num_weight(num_weight),
				.data_width(data_width),
				.base_dir(base_dir),
				.bias_file(L2_BIAS_FILE[i]),
				.weight_file(L2_WEIGHT_FILE[i])
			)u_neuron(
				.clk(clk),
				.rst(rst),
				.myinput(x_in),
				.myinputvalid(x_valid),
				.output_data(layer_out_internal[i]),
				.outvalid(o_valid[i])
			);
		end
	endgenerate
	
	//flatten output
	always_comb begin
		for (int j = 0; j < nn; j++) begin
			x_out_flat[j*data_width +: data_width]	= layer_out_internal[j];
		end
	end

endmodule