module prbs_generator #(
    parameter int WIDTH = 32,
    parameter int OUT_WIDTH = 16
) (
    input  logic                 clk_32_i,
    input  logic                 clk_16_i,
    input  logic                 rst_n_i,
    input  logic                 enable_i,
    input  logic [WIDTH-1:0]     seed_i,
    output logic [OUT_WIDTH-1:0] prbs16_out_o,
    output logic                 valid_out_o
);

    logic [WIDTH-1:0] lfsr_q;
    logic [WIDTH-1:0] prbs_next;
    logic [WIDTH-1:0] temp;
    logic [WIDTH-1:0] prbs32_reg_q;
    logic             half_sel_q;
    int               i;

    always_comb begin
        temp      = lfsr_q;
        prbs_next = '0;
        for (i = 0; i < WIDTH; i++) begin
            temp = {temp[30:0], temp[31] ^ temp[28]};
            prbs_next[WIDTH-1-i] = temp[0];
        end
    end

    always_ff @(posedge clk_32_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            lfsr_q <= seed_i;
        end else begin
            if (enable_i) begin
                lfsr_q <= temp;
            end
        end
    end

    always_ff @(posedge clk_16_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            prbs32_reg_q  <= '0;
            half_sel_q    <= 1'b0;
            prbs16_out_o  <= '0;
            valid_out_o   <= 1'b0;
        end else begin
            if (enable_i) begin
                valid_out_o  <= 1'b0;
                prbs32_reg_q <= prbs_next;
                half_sel_q   <= ~half_sel_q;
                if (!half_sel_q) begin
                    prbs16_out_o <= prbs32_reg_q[15:0];
                    valid_out_o  <= 1'b1;
                end else begin
                    prbs16_out_o <= prbs32_reg_q[31:16];
                    valid_out_o  <= 1'b1;
                end
            end
        end
    end

endmodule
