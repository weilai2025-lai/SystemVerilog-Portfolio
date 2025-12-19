library verilog;
use verilog.vl_types.all;
entity tb_dnn is
    generic(
        data_width      : integer := 16;
        file_path       : string  := "C:/SystemVerilog_NPU/test_data/test_data_0015.txt"
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of data_width : constant is 2;
    attribute mti_svvh_generic_type of file_path : constant is 2;
end tb_dnn;
