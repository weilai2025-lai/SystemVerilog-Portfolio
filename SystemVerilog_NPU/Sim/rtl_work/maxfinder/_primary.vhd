library verilog;
use verilog.vl_types.all;
entity maxfinder is
    generic(
        num_input       : integer := 10;
        input_width     : integer := 16
    );
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        i_data          : in     vl_logic_vector;
        i_valid         : in     vl_logic;
        o_data          : out    vl_logic_vector(3 downto 0);
        o_data_valid    : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of num_input : constant is 2;
    attribute mti_svvh_generic_type of input_width : constant is 2;
end maxfinder;
