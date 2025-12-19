library verilog;
use verilog.vl_types.all;
entity tb_neuron is
    generic(
        num_weight      : integer := 784;
        data_width      : integer := 16;
        sigmoid_size    : integer := 10;
        test_file       : string  := "C:/SystemVerilog_NPU/test_data/test_data_0000.txt"
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of num_weight : constant is 2;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of sigmoid_size : constant is 2;
    attribute mti_svvh_generic_type of test_file : constant is 1;
end tb_neuron;
