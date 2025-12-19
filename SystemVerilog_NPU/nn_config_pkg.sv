package nn_config_pkg;
	//Global Settings
	parameter bit pretrained = 1'b1;
	parameter bit sim_read_file = 1'b1;
	parameter int num_layers = 5;
	parameter int data_width = 16;
	parameter int weight_int_width = 1;
	parameter int sig_size = 10;
	//First Layer
	parameter int num_neuron_layer1 = 30;
	parameter int num_weight_layer1 = 784;
	parameter string layer1_act_type = "sigmoid";
	//Sceond Layer
	parameter int num_neuron_layer2 = 30;
	parameter int num_weight_layer2 = 30;
	parameter string layer2_act_type = "sigmoid";	
	//Third Layer
	parameter int num_neuron_layer3 = 10;
	parameter int num_weight_layer3 = 30;
	parameter string layer3_act_type = "sigmoid";	
	//4th Layer
	parameter int num_neuron_layer4 = 10;
	parameter int num_weight_layer4 = 10;
	parameter string layer4_act_type = "sigmoid";	
	//5th Layer
	parameter int num_neuron_layer5 = 10;
	parameter int num_weight_layer5 = 10;
	parameter string layer5_act_type = "hardmax";	
	//define locaton of value	
	parameter string base_direction = "C:/SystemVerilog_NPU/";
   parameter string L1_BIAS_FILE [0:29] = '{
	 "b_1_0.mif", "b_1_1.mif", "b_1_2.mif", "b_1_3.mif", "b_1_4.mif",
	 "b_1_5.mif", "b_1_6.mif", "b_1_7.mif", "b_1_8.mif", "b_1_9.mif",
	 "b_1_10.mif","b_1_11.mif","b_1_12.mif","b_1_13.mif","b_1_14.mif",
	 "b_1_15.mif","b_1_16.mif","b_1_17.mif","b_1_18.mif","b_1_19.mif",
	 "b_1_20.mif","b_1_21.mif","b_1_22.mif","b_1_23.mif","b_1_24.mif",
	 "b_1_25.mif","b_1_26.mif","b_1_27.mif","b_1_28.mif","b_1_29.mif"
	};

   parameter string L1_WEIGHT_FILE [0:29] = '{
    "w_1_0.mif", "w_1_1.mif", "w_1_2.mif", "w_1_3.mif", "w_1_4.mif",
    "w_1_5.mif", "w_1_6.mif", "w_1_7.mif", "w_1_8.mif", "w_1_9.mif",
    "w_1_10.mif","w_1_11.mif","w_1_12.mif","w_1_13.mif","w_1_14.mif",
    "w_1_15.mif","w_1_16.mif","w_1_17.mif","w_1_18.mif","w_1_19.mif",
    "w_1_20.mif","w_1_21.mif","w_1_22.mif","w_1_23.mif","w_1_24.mif",
    "w_1_25.mif","w_1_26.mif","w_1_27.mif","w_1_28.mif","w_1_29.mif"
	};
	
	parameter string L2_BIAS_FILE [0:29] = '{
    "b_2_0.mif", "b_2_1.mif", "b_2_2.mif", "b_2_3.mif", "b_2_4.mif",
    "b_2_5.mif", "b_2_6.mif", "b_2_7.mif", "b_2_8.mif", "b_2_9.mif",
    "b_2_10.mif","b_2_11.mif","b_2_12.mif","b_2_13.mif","b_2_14.mif",
    "b_2_15.mif","b_2_16.mif","b_2_17.mif","b_2_18.mif","b_2_19.mif",
    "b_2_20.mif","b_2_21.mif","b_2_22.mif","b_2_23.mif","b_2_24.mif",
    "b_2_25.mif","b_2_26.mif","b_2_27.mif","b_2_28.mif","b_2_29.mif"
  };

  parameter string L2_WEIGHT_FILE [0:29] = '{
    "w_2_0.mif", "w_2_1.mif", "w_2_2.mif", "w_2_3.mif", "w_2_4.mif",
    "w_2_5.mif", "w_2_6.mif", "w_2_7.mif", "w_2_8.mif", "w_2_9.mif",
    "w_2_10.mif","w_2_11.mif","w_2_12.mif","w_2_13.mif","w_2_14.mif",
    "w_2_15.mif","w_2_16.mif","w_2_17.mif","w_2_18.mif","w_2_19.mif",
    "w_2_20.mif","w_2_21.mif","w_2_22.mif","w_2_23.mif","w_2_24.mif",
    "w_2_25.mif","w_2_26.mif","w_2_27.mif","w_2_28.mif","w_2_29.mif"
  };
  
  parameter string L3_BIAS_FILE [0:9] = '{
    "b_3_0.mif", "b_3_1.mif", "b_3_2.mif", "b_3_3.mif", "b_3_4.mif",
    "b_3_5.mif", "b_3_6.mif", "b_3_7.mif", "b_3_8.mif", "b_3_9.mif"
  };

  parameter string L3_WEIGHT_FILE [0:9] = '{
    "w_3_0.mif", "w_3_1.mif", "w_3_2.mif", "w_3_3.mif", "w_3_4.mif",
    "w_3_5.mif", "w_3_6.mif", "w_3_7.mif", "w_3_8.mif", "w_3_9.mif"
  };
  
  parameter string L4_BIAS_FILE [0:9] = '{
    "b_4_0.mif", "b_4_1.mif", "b_4_2.mif", "b_4_3.mif", "b_4_4.mif",
    "b_4_5.mif", "b_4_6.mif", "b_4_7.mif", "b_4_8.mif", "b_4_9.mif"
  };

  parameter string L4_WEIGHT_FILE [0:9] = '{
    "w_4_0.mif", "w_4_1.mif", "w_4_2.mif", "w_4_3.mif", "w_4_4.mif",
    "w_4_5.mif", "w_4_6.mif", "w_4_7.mif", "w_4_8.mif", "w_4_9.mif"
  };

endpackage: nn_config_pkg