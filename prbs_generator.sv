module prbs_generator #(
    parameter int WIDTH     = 32,
    parameter int OUT_WIDTH = 16
)(
    input   logic                   clk_32,
    input   logic                   clk_16,

    input   logic                   rst_n,
    input   logic                   enable,
    
    input   logic [WIDTH-1:0]       seed,

    output  logic [OUT_WIDTH-1:0]   prbs16_out,
    output  logic                   valid_out
);

    logic [WIDTH:0] lfsr;
    logic [WIDTH:0] prbs_next;
    logic [WIDTH:0] temp;

    int i;

    always_comb begin
        temp      = lfsr;
        prbs_next = '0;
            for (i = 0; i < WIDTH; i++) begin
                temp = {temp[30:0], temp[31] ^ temp[28]};
                prbs_next[WIDTH-1-i] = temp[0];
            end
    end

    always_ff @(posedge clk_32 or negedge rst_n) begin
        if (!rst_n) begin
            lfsr   <= seed;
        end else if (enable) begin
            lfsr   <= temp;
        end
    end

    logic [WIDTH:0] prbs32_reg;
    logic        half_sel;

    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n) begin
            prbs32_reg  <= '0;
            half_sel    <=  0;
            prbs16_out  <= '0;
            valid_out   <=  0;
        end else if(enable) begin
                valid_out   <= 0;
                prbs32_reg  <= prbs_next;
                half_sel    <= ~half_sel;

            if (half_sel == 0) begin
                prbs16_out  <= prbs32_reg[15:0];
                valid_out   <= 1;
            end else begin
                prbs16_out  <= prbs32_reg[31:16];
                valid_out   <= 1;
            end
        end
    end

endmodule
