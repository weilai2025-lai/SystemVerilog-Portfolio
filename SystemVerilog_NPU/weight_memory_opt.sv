import nn_config_pkg::*;
module weight_memory_opt
	#(	
		parameter int num_weight_lines = 196,
		parameter int data_width = 64, 
		parameter int parallelism = 4,
		parameter int address_width = 10,
		parameter weight_file = "C:/VHDL_training/Neural/w_1_15.mif"
	)(
		input logic clk,		
		input logic ren,
		input logic [address_width-1:0] radd,
		output logic [data_width-1:0] wout
	);
	
	localparam int element_width = data_width / parallelism;
	localparam int file_depth = num_weight_lines * parallelism;

	
	//define memory array
	logic [element_width-1:0] mem[0:file_depth-1];
	//initialize memory
	initial begin
		$readmemb(weight_file, mem);//read memory's binary value
	end
	//Synchronus read
	always_ff @(posedge clk) begin
		if (ren) begin
			for (int i = 0; i < parallelism; i++) begin
				wout[i*element_width +: element_width] <= mem[radd * parallelism + i];
			end
		end
	end 		
endmodule