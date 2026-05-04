module serializer #(
    parameter int OUT_WIDTH = 16
)(
    input   logic                   clk_16,
    input   logic                   clk_ser,

    input   logic                   enable,
    input   logic                   rst_n,
    
    input   logic                   valid_in,

    input   logic [OUT_WIDTH-1:0]  prbs_data_in,

    output  logic                   serial_out,
    output  logic                   s_serial_valid
);
    
    logic                           load_flag;
    logic                           load_flag_sync_ff1;
    logic                           load_flag_sync_ff2;
    
    logic   [OUT_WIDTH-1:0]         shift_reg;
    logic   [4:0]                   bit_cnt;
    
    always_ff @(posedge clk_16 or negedge rst_n) begin
       if (!rst_n) begin
            load_flag                   <=  0;
       end else begin
            if(valid_in) begin
                load_flag               <=  ~load_flag;
            end
        end
    end

    always_ff @(posedge clk_ser or negedge rst_n) begin
       if (!rst_n) begin
            load_flag_sync_ff1               <=  0;
            load_flag_sync_ff2               <=  0;
       end else begin
            load_flag_sync_ff1               <=  load_flag;
            load_flag_sync_ff2               <=  load_flag_sync_ff1;
       end
    end

    logic   load_flag_sync_prev;
    logic   load_pulse;

    always_ff @(posedge clk_ser or negedge rst_n) begin
       if (!rst_n) begin
            load_flag_sync_prev             <=  0;
       end else begin
            load_flag_sync_prev             <=  load_flag_sync_ff2;
       end
    end

    assign  load_pulse                      =  load_flag_sync_ff2  ^  load_flag_sync_prev;

    always_ff @(posedge clk_ser or negedge rst_n) begin
       if (!rst_n) begin
            shift_reg                       <=  '0;
            bit_cnt                         <=  '0;
            serial_out                      <=  '0;
            s_serial_valid                    <=  1'b0;
        end else begin
            if (load_pulse) begin
                shift_reg                   <=  prbs_data_in;
                bit_cnt                     <=  5'd0;
                serial_out                  <=  prbs_data_in[OUT_WIDTH-1];
                s_serial_valid                <=  1;
            end else if (s_serial_valid) begin 
                if (bit_cnt < OUT_WIDTH-1) begin
                    shift_reg               <=  {shift_reg[OUT_WIDTH-2:0],1'b0};  
                    serial_out              <=  shift_reg[OUT_WIDTH-2];
                    bit_cnt                 <=  bit_cnt + 1'b1;
                end else begin
                    s_serial_valid            <=  '0;
                    bit_cnt                 <=  '0;
                end
            end
        end
    end

endmodule
