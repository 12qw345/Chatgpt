module deserilizer #(
    parameter int OUT_WIDTH = 16
) (
    input  logic                 clk_16_i,
    input  logic                 clk_ser_i,
    input  logic                 enable_i,
    input  logic                 rst_n_i,
    input  logic                 s_serial_in_i,
    input  logic                 s_serial_valid_i,
    output logic [OUT_WIDTH-1:0] prbs_data_out_o,
    output logic                 d_serial_valid_out_o
);

    logic [OUT_WIDTH-1:0] shift_reg_q;
    logic [4:0]           bit_count_q;
    logic [OUT_WIDTH-1:0] data_hold_current_q;
    logic [OUT_WIDTH-1:0] data_hold_current1_q;
    logic [OUT_WIDTH-1:0] data_hold_stable_q;
    logic                 data_ready_toggle_q;
    logic                 data_ready_sync_ff1_q;
    logic                 data_ready_sync_ff2_q;
    logic                 data_ready_sync_prev_q;
    logic                 valid_pulse;
    logic [OUT_WIDTH-1:0] data_captured_sync_q;

    always_ff @(posedge clk_ser_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            shift_reg_q         <= '0;
            bit_count_q         <= '0;
            data_hold_current_q <= '0;
            data_hold_current1_q <= '0;
            data_hold_stable_q  <= '0;
            data_ready_toggle_q <= 1'b0;
        end else begin
            if (enable_i && s_serial_valid_i) begin
                shift_reg_q <= {shift_reg_q[OUT_WIDTH-2:0], s_serial_in_i};
                bit_count_q <= bit_count_q + 1'b1;
                if (bit_count_q == OUT_WIDTH - 1) begin
                    data_hold_current_q  <= {shift_reg_q[OUT_WIDTH-2:0], s_serial_in_i};
                    data_hold_current1_q <= data_hold_current_q;
                    data_hold_stable_q   <= data_hold_current1_q;
                    data_ready_toggle_q  <= ~data_ready_toggle_q;
                    bit_count_q          <= '0;
                end
            end
        end
    end

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            data_ready_sync_ff1_q  <= 1'b0;
            data_ready_sync_ff2_q  <= 1'b0;
            data_ready_sync_prev_q <= 1'b0;
        end else begin
            data_ready_sync_ff1_q  <= data_ready_toggle_q;
            data_ready_sync_ff2_q  <= data_ready_sync_ff1_q;
            data_ready_sync_prev_q <= data_ready_sync_ff2_q;
        end
    end

    assign valid_pulse = data_ready_sync_ff2_q ^ data_ready_sync_prev_q;

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            data_captured_sync_q <= '0;
        end else begin
            if (valid_pulse) begin
                data_captured_sync_q <= data_hold_stable_q;
            end
        end
    end

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            prbs_data_out_o      <= '0;
            d_serial_valid_out_o <= 1'b0;
        end else begin
            if (valid_pulse) begin
                prbs_data_out_o      <= data_captured_sync_q;
                d_serial_valid_out_o <= 1'b1;
            end else begin
                d_serial_valid_out_o <= 1'b0;
            end
        end
    end

endmodule
