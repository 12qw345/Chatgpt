module prbs_top #(
    parameter int WIDTH = 32,
    parameter int OUT_WIDTH = 16
) (
    input  logic                 clk_32_i,
    input  logic                 clk_16_i,
    input  logic                 clk_ser_i,
    input  logic                 rst_n_i,
    input  logic                 gen_enable_i,
    input  logic                 chk_enable_i,
    input  logic                 serdes_enable_i,
    input  logic [OUT_WIDTH-1:0] prbs_corrupted_i,
    input  logic                 loadseed_i,
    input  logic [WIDTH-1:0]     seed_i,
    input  logic [OUT_WIDTH-1:0] prbs_in_i,
    input  logic                 valid_in_i,
    input  logic [OUT_WIDTH-1:0] prbs_data_in_i,
    output logic                 serial_out_o,
    output logic                 s_serial_valid_o,
    output logic [OUT_WIDTH-1:0] prbs16_out_o,
    output logic [OUT_WIDTH-1:0] prbs_data_out_o,
    output logic                 d_serial_valid_out_o,
    output logic                 valid_out_o,
    output logic [OUT_WIDTH-1:0] error_cnt_o,
    output logic                 error_o
);

    prbs_generator #(.WIDTH(WIDTH), .OUT_WIDTH(OUT_WIDTH)) u_gen (
        .clk_32_i(clk_32_i),
        .clk_16_i(clk_16_i),
        .rst_n_i(rst_n_i),
        .enable_i(gen_enable_i),
        .seed_i(seed_i),
        .prbs16_out_o(prbs16_out_o),
        .valid_out_o(valid_out_o)
    );

    prbs_checker #(.WIDTH(WIDTH), .OUT_WIDTH(OUT_WIDTH)) u_chk (
        .clk_32_i(clk_32_i),
        .clk_16_i(clk_16_i),
        .rst_n_i(rst_n_i),
        .enable_i(chk_enable_i),
        .loadseed_i(loadseed_i),
        .prbs_in_i(prbs_corrupted_i),
        .error_cnt_o(error_cnt_o),
        .error_o(error_o)
    );

    serializer #(.OUT_WIDTH(OUT_WIDTH)) u_ser (
        .clk_16_i(clk_16_i),
        .clk_ser_i(clk_ser_i),
        .enable_i(serdes_enable_i),
        .rst_n_i(rst_n_i),
        .valid_in_i(valid_out_o),
        .prbs_data_in_i(prbs16_out_o),
        .serial_out_o(serial_out_o),
        .s_serial_valid_o(s_serial_valid_o)
    );

    deserilizer #(.OUT_WIDTH(OUT_WIDTH)) u_deser (
        .clk_16_i(clk_16_i),
        .clk_ser_i(clk_ser_i),
        .enable_i(serdes_enable_i),
        .rst_n_i(rst_n_i),
        .s_serial_in_i(serial_out_o),
        .s_serial_valid_i(s_serial_valid_o),
        .prbs_data_out_o(prbs_data_out_o),
        .d_serial_valid_out_o(d_serial_valid_out_o)
    );

endmodule
