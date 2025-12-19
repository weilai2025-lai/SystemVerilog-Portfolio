library verilog;
use verilog.vl_types.all;
entity neuron is
    generic(
        num_weight      : integer := 784;
        data_width      : integer := 16;
        sigmoid_size    : integer := 10;
        base_dir        : string  := "C:/SystemVerilog_NPU/";
        bias_file       : string  := "b_1_0.mif";
        weight_file     : string  := "w_1_0.mif";
        bias_file_abs   : vl_notype;
        weight_file_abs : vl_notype
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        myinput         : in     vl_logic_vector;
        myinputvalid    : in     vl_logic;
        output_data     : out    vl_logic_vector;
        outvalid        : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of num_weight : constant is 2;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of sigmoid_size : constant is 2;
    attribute mti_svvh_generic_type of base_dir : constant is 1;
    attribute mti_svvh_generic_type of bias_file : constant is 1;
    attribute mti_svvh_generic_type of weight_file : constant is 1;
    attribute mti_svvh_generic_type of bias_file_abs : constant is 3;
    attribute mti_svvh_generic_type of weight_file_abs : constant is 3;
end neuron;
