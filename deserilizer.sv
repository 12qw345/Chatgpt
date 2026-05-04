module deserilizer #(
    parameter   int     OUT_WIDTH   =   16
)(
    input   logic                   clk_16,
    input   logic                   clk_ser,

    input   logic                   enable,
    input   logic                   rst_n,

    input   logic                   s_serial_in,
    input   logic                   s_serial_valid,

    output  logic   [OUT_WIDTH-1:0] prbs_data_out,
    output  logic                   d_serial_valid_out
);
    
    logic   [OUT_WIDTH-1:0]         shift_reg;
    logic   [4:0]                   bit_count;
    logic   [OUT_WIDTH-1:0]         data_hold_current;   // Just captured
    logic   [OUT_WIDTH-1:0]         data_hold_current1;    
    logic   [OUT_WIDTH-1:0]         data_hold_stable;    // Previous word (stable for sampling)
    logic                           data_ready_toggle;

    always_ff @(posedge clk_ser or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg                <=      '0;
            bit_count                <=      '0;
            data_hold_current        <=      '0;
            data_hold_current1       <=      '0;
            data_hold_stable         <=      '0;
            data_ready_toggle        <=      1'b0;
        end else begin
            if  (s_serial_valid) begin
                shift_reg            <=      {shift_reg[OUT_WIDTH-2:0], s_serial_in};
                bit_count            <=      bit_count + 1;
                if(bit_count == OUT_WIDTH - 1) begin
                    // Capture new word into current buffer
                    data_hold_current    <=  {shift_reg[OUT_WIDTH-2:0], s_serial_in};
                    // Move previous word to stable buffer (now guaranteed stable for >=16 cycles)
                    data_hold_current1   <=  data_hold_current;
                    data_hold_stable     <=  data_hold_current1;
                    data_ready_toggle    <=  ~data_ready_toggle;
                    bit_count            <=  '0;
                end
            end
        end
    end

    // Cross to slow clock domain using toggle-based handshake
    logic data_ready_sync_ff1, data_ready_sync_ff2, data_ready_sync_prev;
    logic [OUT_WIDTH-1:0] data_captured_sync;
    
    // Two-stage synchronizer for toggle signal
    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n) begin
            data_ready_sync_ff1      <=      1'b0;
            data_ready_sync_ff2      <=      1'b0;
            data_ready_sync_prev     <=      1'b0;
        end else begin
            data_ready_sync_ff1      <=      data_ready_toggle;
            data_ready_sync_ff2      <=      data_ready_sync_ff1;
            data_ready_sync_prev     <=      data_ready_sync_ff2;
        end
    end
    
    // Detect any change in toggle (XOR detects both edges)
    logic valid_pulse;
    assign valid_pulse               =       data_ready_sync_ff2 ^ data_ready_sync_prev;
    
    // Sample data_hold_stable (previous word, guaranteed stable) when valid_pulse fires
    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n) begin
            data_captured_sync       <=      '0;
        end else begin
            if (valid_pulse) begin
                data_captured_sync   <=      data_hold_stable;  // Sample from stable buffer
            end
        end
    end
        
    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n) begin
            prbs_data_out            <=      '0;
            d_serial_valid_out       <=      1'b0;
        end else begin
            if (valid_pulse) begin
                prbs_data_out        <=      data_captured_sync;
                d_serial_valid_out   <=      1'b1;
            end else begin
                d_serial_valid_out   <=      1'b0;
            end
        end
    end

endmodule
