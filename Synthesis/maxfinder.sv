import nn_config_pkg::*;

module maxfinder
	#(
		parameter int num_input = 10,
		parameter int input_width = 16
	)(
		input logic clk,
		input logic rst,
		input logic [num_input*input_width-1:0] i_data,
		input logic i_valid,
		output logic [3:0] o_data, //label:0~9
		output logic o_data_valid
	);
	
	logic [num_input-1:0][input_width-1:0] in_data_array;
	logic [num_input*input_width-1:0] in_data_buffer;
	
	logic [input_width-1:0] max_value;
	logic [3:0] o_data_r;
	logic o_data_valid_r;
	
	//limit bit usage for counter
	localparam int counter_width = $clog2(num_input);
	logic [counter_width-1:0] counter;
	//connect to output//
	assign o_data = o_data_r;
	assign o_data_valid = o_data_valid_r;
	
	//Mapping, this would help us mapping flatten signal to 2D array easily
	assign in_data_array = in_data_buffer;
	
  always_ff @(posedge clk) begin
	if (rst) begin
		counter <= 0;
		o_data_r <= '0;
		o_data_valid_r <= '0;
		max_value <= '0;
		in_data_buffer <= '0;
	end 
	else begin
		o_data_valid_r <= 1'b0;
		if (i_valid) begin
			in_data_buffer <= i_data;		
			max_value <= i_data[input_width-1:0];
			o_data_r <= 4'b0;
			counter <= 1;	
		end 
		else if (counter == num_input) begin
			o_data_valid_r <= 1'b1;
			counter <= 0;
		end 
		else if (counter != 0) begin
			if (in_data_array[counter] > max_value) begin
				max_value <= in_data_array[counter];
				o_data_r <= counter[3:0];
			end
			counter <= counter + 1;
		end
	end
  end
	
endmodule