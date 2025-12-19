library verilog;
use verilog.vl_types.all;
entity sig_rom is
    generic(
        in_width        : integer := 10;
        data_width      : integer := 16;
        base_dir        : string  := "C:/SystemVerilog_NPU/";
        sigmoid_file    : string  := "sigContent.mif";
        sigmoid_file_abs: vl_notype
    );
    port(
        clk             : in     vl_logic;
        x               : in     vl_logic_vector;
        output_data     : out    vl_logic_vector
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of in_width : constant is 2;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of base_dir : constant is 1;
    attribute mti_svvh_generic_type of sigmoid_file : constant is 1;
    attribute mti_svvh_generic_type of sigmoid_file_abs : constant is 3;
end sig_rom;
