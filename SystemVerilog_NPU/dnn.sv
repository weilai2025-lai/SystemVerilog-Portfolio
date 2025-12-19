import nn_config_pkg::*;

module dnn
	#(
		parameter string base_dir = base_direction,
		parameter int data_width = 16,
		parameter int sigmoid_size = sig_size
	
	)(
		input logic clk,
		input logic rst,
		//input: image data(mnist)
		input logic [data_width-1:0] x_data,
		input logic x_valid,
		//output: classification of result
		output logic [3:0] class_id,
		output logic class_valid
	);
	
	//---Layer1---//
	logic [num_neuron_layer1-1:0] o1_valid_bus;
	logic [num_neuron_layer1*data_width-1:0] x1_out_flat;
	
	//--P2S Interface (L1 -> L2)--//
	logic [num_neuron_layer1*data_width-1:0] hold_data1;
	logic [data_width-1:0] out_data1;
	logic valid_out1;
	localparam int count_width30 = $clog2(num_neuron_layer1);
	localparam int count_width10 = $clog2(num_neuron_layer3);
	logic [count_width30-1:0] count1;
	enum logic {IDLE1, SEND1} state1;

	//---Layer2---//
	logic [num_neuron_layer2-1:0] o2_valid_bus;
	logic [num_neuron_layer2*data_width-1:0] x2_out_flat;
	
	//--P2S Interface (L2 -> L3)--//
	logic [num_neuron_layer2*data_width-1:0] hold_data2;
	logic [data_width-1:0] out_data2;
	logic valid_out2;
	logic [count_width30-1:0] count2;
	enum logic {IDLE2, SEND2} state2;	
	
	//---Layer3---//
	logic [num_neuron_layer3-1:0] o3_valid_bus;
	logic [num_neuron_layer3*data_width-1:0] x3_out_flat;
	
	//--P2S Interface (L3 -> L4)--//
	logic [num_neuron_layer3*data_width-1:0] hold_data3;
	logic [data_width-1:0] out_data3;
	logic valid_out3;
	logic [count_width10-1:0] count3;
	enum logic {IDLE3, SEND3} state3;	
	
	//---Layer4---//
	logic [num_neuron_layer4-1:0] o4_valid_bus;
	logic [num_neuron_layer4*data_width-1:0] x4_out_flat;
	
	//Layer1 Instantiation
	Layer1#(
		.nn(num_neuron_layer1),
		.num_weight(num_weight_layer1),
		.data_width(data_width),
		.layer_num(1),
		.sigmoid_size(sigmoid_size),
		.base_dir(base_dir)
	)u_layer1(
		.clk(clk),
		.rst(rst),
		.x_valid(x_valid),
		.x_in(x_data),
		.o_valid(o1_valid_bus),
		.x_out_flat(x1_out_flat)
	);
	
	//Layer2 Instantiation
	Layer2#(
		.nn(num_neuron_layer2),
		.num_weight(num_weight_layer2),
		.data_width(data_width),
		.layer_num(2),
		.sigmoid_size(sigmoid_size),
		.base_dir(base_dir)
	)u_layer2(
		.clk(clk),
		.rst(rst),
		.x_valid(valid_out1),
		.x_in(out_data1),
		.o_valid(o2_valid_bus),
		.x_out_flat(x2_out_flat)
	);
	
	//Layer3 Instantiation
	Layer3#(
		.nn(num_neuron_layer3),
		.num_weight(num_weight_layer3),
		.data_width(data_width),
		.layer_num(3),
		.sigmoid_size(sigmoid_size),
		.base_dir(base_dir)
	)u_layer3(
		.clk(clk),
		.rst(rst),
		.x_valid(valid_out2),
		.x_in(out_data2),
		.o_valid(o3_valid_bus),
		.x_out_flat(x3_out_flat)
	);
	
	//Layer4 Instantiation
	Layer4#(
		.nn(num_neuron_layer4),
		.num_weight(num_weight_layer4),
		.data_width(data_width),
		.layer_num(4),
		.sigmoid_size(sigmoid_size),
		.base_dir(base_dir)
	)u_layer4(
		.clk(clk),
		.rst(rst),
		.x_valid(valid_out3),
		.x_in(out_data3),
		.o_valid(o4_valid_bus),
		.x_out_flat(x4_out_flat)
	);
	
	//Maxfinder Instantiation
	maxfinder#(
		.num_input(num_neuron_layer4),
		.input_width(data_width)
	)u_maxfinder(
		.clk(clk),
		.rst(rst),
		.i_data(x4_out_flat),
		.i_valid(o4_valid_bus[0]),
		.o_data(class_id),
		.o_data_valid(class_valid)
	);
	
/////P2S(Layer1 -> Layer2)/////
	always_ff @(posedge clk) begin
		if (rst) begin
			state1 <= IDLE1;
			count1 <= '0;
			valid_out1 <= '0;
			hold_data1 <= '0;
			out_data1 <= '0;
		end
		else begin
			case(state1)
				IDLE1:begin
					count1 <= '0;
					valid_out1 <= 1'b0;
					if (o1_valid_bus[0]) begin
						state1 <= SEND1;
						hold_data1 <= x1_out_flat;
					end
				end
				
				SEND1:begin
					valid_out1 <= 1'b1;
					out_data1 <= hold_data1[data_width-1:0];
					hold_data1 <= hold_data1 >> data_width;
					if (count1 == num_neuron_layer1-1) begin
						state1 <= IDLE1;
					end
					else begin
						count1 <= count1 + 1;
					end
				end			
			endcase
		end
	end

/////P2S(Layer2 -> Layer3)/////
	always_ff @(posedge clk) begin
		if (rst) begin
			state2 <= IDLE2;
			count2 <= '0;
			valid_out2 <= '0;
			hold_data2 <= '0;
			out_data2 <= '0;
		end
		else begin
			case(state2)
				IDLE2:begin
					count2 <= '0;
					valid_out2 <= 1'b0;
					if (o2_valid_bus[0]) begin
						state2 <= SEND2;
						hold_data2 <= x2_out_flat;
					end
				end
				
				SEND2:begin
					valid_out2 <= 1'b1;
					out_data2 <= hold_data2[data_width-1:0];
					hold_data2 <= hold_data2 >> data_width;
					if (count2 == num_neuron_layer2-1) begin
						state2 <= IDLE2;
					end
					else begin
						count2 <= count2 + 1;
					end
				end			
			endcase
		end
	end

/////P2S(Layer3 -> Layer4)/////
	always_ff @(posedge clk) begin
		if (rst) begin
			state3 <= IDLE3;
			count3 <= '0;
			valid_out3 <= '0;
			hold_data3 <= '0;
			out_data3 <= '0;
		end
		else begin
			case(state3)
				IDLE3:begin
					count3 <= '0;
					valid_out3 <= 1'b0;
					if (o3_valid_bus[0]) begin
						state3 <= SEND3;
						hold_data3 <= x3_out_flat;
					end
				end
				
				SEND3:begin
					valid_out3 <= 1'b1;
					out_data3 <= hold_data3[data_width-1:0];
					hold_data3 <= hold_data3 >> data_width;
					if (count3 == num_neuron_layer3-1) begin
						state3 <= IDLE3;
					end
					else begin
						count3 <= count3 + 1;
					end
				end			
			endcase
		end
	end
endmodule