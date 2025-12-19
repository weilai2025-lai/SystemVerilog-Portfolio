import nn_config_pkg::*;
module weight_memory
	#(	
		parameter int num_weight = 784,
		parameter int data_width = 16,
		parameter int address_width = 10,
		parameter weight_file = "C:/VHDL_training/Neural/w_1_15.mif"
	)(
		input logic clk,		
		input logic ren,
		input logic [address_width-1:0] radd,
		output logic [data_width-1:0] wout
	);
	
	//define memory array
	logic [data_width-1:0] mem[0:num_weight-1];
	//initialize memory
	initial begin
		$readmemb(weight_file, mem);//read memory's binary value
	end
	//Synchronus read
	always_ff @(posedge clk) begin
		if (ren) begin
			wout <= mem[radd];
		end
	end 		
endmodule