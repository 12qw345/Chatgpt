module prbs_top #(
    parameter WIDTH     = 32,
    parameter OUT_WIDTH = 16
)(
    input  logic                    clk_32,
    input  logic                    clk_16,
    input  logic                    clk_ser,
    input  logic                    rst_n,

    input  logic                    gen_enable,
    input  logic                    chk_enable,
    input  logic                    serdes_enable,

    input  logic  [OUT_WIDTH-1:0]  prbs_corrupted,

    input  logic                    loadseed,
    input  logic [WIDTH-1:0]        seed,

    input  logic [OUT_WIDTH-1:0]    prbs_in,

    input  logic                    valid_in,
    input  logic [OUT_WIDTH-1:0]    prbs_data_in,

    output logic                    serial_out,
    output logic                    s_serial_valid,

    output logic [OUT_WIDTH-1:0]    prbs16_out,
    output logic [OUT_WIDTH-1:0]    prbs_data_out,
    output logic                    d_serial_valid_out,
    output logic                    valid_out,
    output logic [OUT_WIDTH-1:0]    error_cnt,
    output logic                    error
);

    // --- Generator ---
    prbs_generator #(
        .WIDTH(WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_gen (
        .clk_32             (clk_32),
        .clk_16             (clk_16),
        .rst_n              (rst_n),
        .enable             (gen_enable),
        .seed               (seed),
        .prbs16_out         (prbs16_out),
        .valid_out          (valid_out)
    );

    // --- Checker ---
    prbs_checker #(
        .WIDTH(WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_chk (
        .clk_32             (clk_32),
        .clk_16             (clk_16),
        .rst_n              (rst_n),
        .enable             (chk_enable),
        .loadseed           (loadseed),
        .prbs_in            (prbs_corrupted),
        .error_cnt          (error_cnt),
        .error              (error)
    );

    // ---Serializer---
    serializer  #(
        .OUT_WIDTH(OUT_WIDTH)
    ) u_ser (
        .clk_16             (clk_16),
        .clk_ser            (clk_ser),
        .enable             (serdes_enable),
        .rst_n              (rst_n),
        .valid_in           (valid_out),
        .prbs_data_in       (prbs16_out),
        .serial_out         (serial_out),
        .s_serial_valid     (s_serial_valid)
    );

    deserilizer  #(
        .OUT_WIDTH(OUT_WIDTH)
    ) u_deser (
        .clk_16             (clk_16),
        .clk_ser            (clk_ser),
        .enable             (serdes_enable),
        .rst_n              (rst_n),
        .s_serial_in        (serial_out),
        .s_serial_valid     (s_serial_valid),
        .prbs_data_out      (prbs_data_out),
        .d_serial_valid_out (d_serial_valid_out)
    );

        
endmodule
