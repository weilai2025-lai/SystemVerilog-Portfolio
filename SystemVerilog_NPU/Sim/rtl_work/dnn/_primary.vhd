library verilog;
use verilog.vl_types.all;
entity dnn is
    generic(
        base_dir        : string;
        data_width      : integer := 16;
        sigmoid_size    : integer := 10
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        x_data          : in     vl_logic_vector;
        x_valid         : in     vl_logic;
        class_id        : out    vl_logic_vector(3 downto 0);
        class_valid     : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of base_dir : constant is 4;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of sigmoid_size : constant is 2;
end dnn;
