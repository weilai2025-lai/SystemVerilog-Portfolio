import nn_config_pkg::*;
`timescale 1ns/1ps;

module tb_dnn;
	
	parameter int data_width = 16;
	parameter string file_path = "C:/SystemVerilog_NPU/test_data/test_data_0015.txt";
	localparam int class_width = $clog2(sig_size);
	
	logic clk;
	logic rst;
	logic [data_width-1:0] x_data;
	logic x_valid;
	logic [class_width-1:0] class_id;
	logic class_valid;
	logic [data_width-1:0] test_mem[0:num_weight_layer1];//include truth label
	logic [data_width-1:0] expect_label;
	
	//DNN Initialization
	dnn u_dnn(
		.clk(clk),
		.rst(rst),
		.x_data(x_data),
		.x_valid(x_valid),
		.class_id(class_id),
		.class_valid(class_valid)
	);
	
	//Initialize testmemory
	initial begin
		$readmemb(file_path, test_mem);
		expect_label = test_mem[num_weight_layer1];
	end
	
	//create clock signal
	initial begin
		clk = 0;
		forever #10 clk = ~clk; 
	end
	
	//Simulation
	initial begin
		$display("Starting simulation: Initialization first");
		rst = 1'b1;
		x_valid = 1'b0;
		x_data = '0;
		
		#50;
		@(posedge clk);
		rst = 1'b0;
		$display("Inject data");
		for(int i = 0; i < num_weight_layer1; i++) begin
			@(posedge clk);
			x_data <= test_mem[i];
			x_valid <= 1'b1;
		end
		@(posedge clk);
		$display("Finishing inject data, waiting for result");
		x_valid <= 1'b0;
		x_data <= '0;
		wait(class_valid == 1'b1);
		
		if (expect_label == class_id) begin
			$display("Classficiation result is correct: class_id =%d, expect_label =%d", class_id, expect_label);
		end else begin
			$display("Classficiation result isn't correct: class_id =%d, expect_label =%d", class_id, expect_label);
		end
		#20;
		$stop;
	end
endmodule