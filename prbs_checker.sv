module prbs_checker #(
    parameter int WIDTH     = 32,
    parameter int OUT_WIDTH = 16
)(
    input   logic                   clk_32,
    input   logic                   clk_16,
    
    input   logic                   rst_n,
    input   logic                   enable,
    
    input   logic                   loadseed,
    input   logic [OUT_WIDTH-1:0]   prbs_in,
    
    output  logic [OUT_WIDTH-1:0]   error_cnt,
    output  logic                   error
);

    logic                 loadseed_d1,loadseed_d2;
    logic                 loadseed_pulse;
    logic [OUT_WIDTH-1:0] prbs_in_prev;

    logic [WIDTH-1:0] seed_comb;
    logic [WIDTH-1:0] lfsr;
    logic [WIDTH-1:0] temp;
    logic [WIDTH-1:0] prbs_next_rx;
    logic             aligned;
    int               i;

    always_comb begin
        temp         = lfsr;
        prbs_next_rx = '0;
        if (enable) begin
            for (i = 0; i < WIDTH; i++) begin
                temp                   = {temp[30:0], temp[31] ^ temp[28]};
                prbs_next_rx[WIDTH-1-i] = temp[0];
            end
        end
    end

    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n) begin
            prbs_in_prev <= '0;
        end else if (enable) begin
            prbs_in_prev <= prbs_in;
        end
    end

    always_ff @(posedge clk_32 or negedge rst_n) begin
        if (!rst_n) begin
            seed_comb     <= '0;
            loadseed_d1   <= 1'b0;
            loadseed_d2   <= 1'b0;
        end else begin
            seed_comb     <= {prbs_in_prev, prbs_in};
            loadseed_d1   <= loadseed;
            loadseed_d2   <= loadseed_d1;
        end
    end

    assign loadseed_pulse = loadseed_d1 & ~loadseed_d2;

    always_ff @(posedge clk_32 or negedge rst_n) begin
        if (!rst_n) begin
            lfsr    <= '0;
            aligned <= 1'b0;
        end else if (loadseed_pulse) begin
            lfsr    <= seed_comb;
            aligned <= 1'b1;
        end else if (enable && aligned) begin
            lfsr    <= temp;
        end
    end

    always_ff @(posedge clk_32 or negedge rst_n) begin
        if (!rst_n) begin
            error     <= 1'b0;
            error_cnt <= '0;
        end else if (enable && aligned) begin
            if (seed_comb != prbs_next_rx) begin
                error     <= 1'b1;
                error_cnt <= error_cnt + 1'b1;
            end else begin
                error <= 1'b0;
            end
        end
    end

endmodule
