module prbs_checker #(
    parameter int WIDTH = 32,
    parameter int OUT_WIDTH = 16
) (
    input  logic                 clk_32_i,
    input  logic                 clk_16_i,
    input  logic                 rst_n_i,
    input  logic                 enable_i,
    input  logic                 loadseed_i,
    input  logic [OUT_WIDTH-1:0] prbs_in_i,
    output logic [OUT_WIDTH-1:0] error_cnt_o,
    output logic                 error_o
);

    logic                 loadseed_d1_q;
    logic                 loadseed_d2_q;
    logic                 loadseed_pulse;
    logic [OUT_WIDTH-1:0] prbs_in_prev_q;
    logic [WIDTH-1:0]     seed_comb_q;
    logic [WIDTH-1:0]     lfsr_q;
    logic [WIDTH-1:0]     temp;
    logic [WIDTH-1:0]     prbs_next_rx;
    logic                 aligned_q;
    int                   i;

    always_comb begin
        temp         = lfsr_q;
        prbs_next_rx = '0;
        if (enable_i) begin
            for (i = 0; i < WIDTH; i++) begin
                temp = {temp[30:0], temp[31] ^ temp[28]};
                prbs_next_rx[WIDTH-1-i] = temp[0];
            end
        end
    end

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            prbs_in_prev_q <= '0;
        end else begin
            if (enable_i) begin
                prbs_in_prev_q <= prbs_in_i;
            end
        end
    end

    always_ff @(posedge clk_32_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            seed_comb_q   <= '0;
            loadseed_d1_q <= 1'b0;
            loadseed_d2_q <= 1'b0;
        end else begin
            seed_comb_q   <= {prbs_in_prev_q, prbs_in_i};
            loadseed_d1_q <= loadseed_i;
            loadseed_d2_q <= loadseed_d1_q;
        end
    end

    assign loadseed_pulse = loadseed_d1_q & ~loadseed_d2_q;

    always_ff @(posedge clk_32_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            lfsr_q    <= '0;
            aligned_q <= 1'b0;
        end else begin
            if (loadseed_pulse) begin
                lfsr_q    <= seed_comb_q;
                aligned_q <= 1'b1;
            end else if (enable_i && aligned_q) begin
                lfsr_q <= temp;
            end
        end
    end

    always_ff @(posedge clk_32_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            error_o     <= 1'b0;
            error_cnt_o <= '0;
        end else begin
            if (enable_i && aligned_q) begin
                if (seed_comb_q != prbs_next_rx) begin
                    error_o     <= 1'b1;
                    error_cnt_o <= error_cnt_o + 1'b1;
                end else begin
                    error_o <= 1'b0;
                end
            end
        end
    end

endmodule
