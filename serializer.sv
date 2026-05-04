module serializer #(
    parameter int OUT_WIDTH = 16
) (
    input  logic                 clk_16_i,
    input  logic                 clk_ser_i,
    input  logic                 enable_i,
    input  logic                 rst_n_i,
    input  logic                 valid_in_i,
    input  logic [OUT_WIDTH-1:0] prbs_data_in_i,
    output logic                 serial_out_o,
    output logic                 s_serial_valid_o
);

    logic                 load_flag_q;
    logic                 load_flag_sync_ff1_q;
    logic                 load_flag_sync_ff2_q;
    logic                 load_flag_sync_prev_q;
    logic                 load_pulse;
    logic [OUT_WIDTH-1:0] shift_reg_q;
    logic [4:0]           bit_cnt_q;

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            load_flag_q <= 1'b0;
        end else begin
            if (enable_i && valid_in_i) begin
                load_flag_q <= ~load_flag_q;
            end
        end
    end

    always_ff @(posedge clk_ser_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            load_flag_sync_ff1_q <= 1'b0;
            load_flag_sync_ff2_q <= 1'b0;
        end else begin
            load_flag_sync_ff1_q <= load_flag_q;
            load_flag_sync_ff2_q <= load_flag_sync_ff1_q;
        end
    end

    always_ff @(posedge clk_ser_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            load_flag_sync_prev_q <= 1'b0;
        end else begin
            load_flag_sync_prev_q <= load_flag_sync_ff2_q;
        end
    end

    assign load_pulse = load_flag_sync_ff2_q ^ load_flag_sync_prev_q;

    always_ff @(posedge clk_ser_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            shift_reg_q      <= '0;
            bit_cnt_q        <= '0;
            serial_out_o     <= 1'b0;
            s_serial_valid_o <= 1'b0;
        end else begin
            if (load_pulse) begin
                shift_reg_q      <= prbs_data_in_i;
                bit_cnt_q        <= 5'd0;
                serial_out_o     <= prbs_data_in_i[OUT_WIDTH-1];
                s_serial_valid_o <= 1'b1;
            end else if (s_serial_valid_o) begin
                if (bit_cnt_q < OUT_WIDTH - 1) begin
                    shift_reg_q  <= {shift_reg_q[OUT_WIDTH-2:0], 1'b0};
                    serial_out_o <= shift_reg_q[OUT_WIDTH-2];
                    bit_cnt_q    <= bit_cnt_q + 1'b1;
                end else begin
                    s_serial_valid_o <= 1'b0;
                    bit_cnt_q        <= '0;
                end
            end
        end
    end

endmodule
