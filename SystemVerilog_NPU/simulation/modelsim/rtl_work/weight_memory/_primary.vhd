library verilog;
use verilog.vl_types.all;
entity weight_memory is
    generic(
        num_weight      : integer := 784;
        data_width      : integer := 16;
        address_width   : integer := 10;
        weight_file     : string  := "C:/VHDL_training/Neural/w_1_15.mif"
    );
    port(
        clk             : in     vl_logic;
        ren             : in     vl_logic;
        radd            : in     vl_logic_vector;
        wout            : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of num_weight : constant is 2;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of address_width : constant is 2;
    attribute mti_svvh_generic_type of weight_file : constant is 1;
end weight_memory;
