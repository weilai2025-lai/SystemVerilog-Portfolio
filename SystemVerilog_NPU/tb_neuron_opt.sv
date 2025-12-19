`timescale 1ns/1ps
import nn_config_pkg::*;

module tb_neuron_opt;
	// 1. 定義參數，記得加上 parallelism
	parameter int num_weight = 784;
	parameter int data_width = 16;
	parameter int sigmoid_size = 10;
	parameter int parallelism = 4; // [重要] 平行度參數
	
	// 請確保你的路徑指向正確的測試檔案
	parameter test_file = "C:/SystemVerilog_NPU/test_data/test_data_0000.txt";
	
	// 2. 宣告訊號
	logic clk;
	logic rst;
	
	// [重要] 輸入訊號變成 packed array (二維陣列)
	logic [parallelism-1:0][data_width-1:0] myinput;
	logic myinputvalid;
	
	logic [data_width-1:0] output_data;
	logic outvalid;
	
	// 測試資料記憶體 (跟原本一樣，還是讀原本的 txt)
	logic [data_width-1:0] test_mem[0:num_weight]; // 0~783 data, 784 = label
	logic [data_width-1:0] expect_label;
	
	// 3. 實例化 neuron_opt
	neuron_opt#(
		.num_weight(num_weight),
		.data_width(data_width),
		.sigmoid_size(sigmoid_size),
		.parallelism(parallelism) // 傳入參數
	) u_neuron_opt (
		.clk(clk),
		.rst(rst),
		.myinput(myinput),
		.myinputvalid(myinputvalid),
		.output_data(output_data),
		.outvalid(outvalid)
	);
	
	// 4. 產生時脈
	initial begin
		clk = 0;
		forever #10 clk = ~clk;
	end
	
	// 5. 測試流程
	initial begin
		rst = 1;
		myinput = '0;
		myinputvalid = 0;
		
		// 讀取測試資料
		$readmemb(test_file, test_mem);
		expect_label = test_mem[num_weight]; // 最後一行是 Label
		
		$display("--------------------------------------------");
		$display("Testing Parallel Neuron (P=%0d)", parallelism);
		$display("Loading Data from: %s", test_file);
		$display("Image Label (ROW 785): %0d", expect_label);
		$display("--------------------------------------------");
		
		// 解除 Reset
		#100;
		@(posedge clk);
		rst = 0;
		#20;
		$display("Starting to stream data in parallel...");
		
		// [關鍵修改] 迴圈次數變成 784 / 4 = 196 次
		for (int i = 0; i < num_weight / parallelism; i++) begin
			@(posedge clk);
			
			// [關鍵修改] 在同一個 cycle 內，把 4 筆資料打包進去
			for (int p = 0; p < parallelism; p++) begin
				// test_mem 是平的一維陣列，我們要自己算索引值
				// 例如 i=0 時，抓 0, 1, 2, 3
				// 例如 i=1 時，抓 4, 5, 6, 7
				myinput[p] <= test_mem[i * parallelism + p];
			end
			
			myinputvalid <= 1'b1;
		end
		
		// 餵完之後拉低 valid
		@(posedge clk);
		myinputvalid <= 1'b0;
		myinput <= '0;
		
		$display("Input stream finished. Waiting for output...");
		
		// 等待結果
		fork 
			begin
				wait(outvalid);
				$display("\n>>> Simulation Success! Output Valid Detected. <<<");
				$display("Parallel Output: %h (Hex) / %0d (Unsigned Decimal)", output_data, output_data);
                // 這裡你可以手動跟舊版的結果比對
			end
			begin
				// 設定超時保護，因為 cycle 變少了，可以設短一點
				#10000; 
				$display("\n [Error] Time out - No output received.");
			end
		join_any;
		
		#100;
		$stop;
	end
endmodule