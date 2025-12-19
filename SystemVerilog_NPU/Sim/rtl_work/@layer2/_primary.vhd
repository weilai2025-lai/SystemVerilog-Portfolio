library verilog;
use verilog.vl_types.all;
entity Layer2 is
    generic(
        nn              : integer := 30;
        num_weight      : integer := 784;
        data_width      : integer := 16;
        layer_num       : integer := 1;
        sigmoid_size    : integer := 10;
        base_dir        : string
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        x_valid         : in     vl_logic;
        x_in            : in     vl_logic_vector;
        o_valid         : out    vl_logic_vector;
        x_out_flat      : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of nn : constant is 2;
    attribute mti_svvh_generic_type of num_weight : constant is 2;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of layer_num : constant is 2;
    attribute mti_svvh_generic_type of sigmoid_size : constant is 2;
    attribute mti_svvh_generic_type of base_dir : constant is 4;
end Layer2;
