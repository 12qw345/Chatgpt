module prbs_tb;

    localparam int WIDTH     = 32;
    localparam int OUT_WIDTH = 16;

    // --- Clocks & Reset ---
    logic clk_ser, clk_2,clk_4, clk_8, clk_16, clk_32, rst_n;

    // --- Control ---
    logic gen_enable, chk_enable, serdes_enable, loadseed;
    logic [WIDTH-1:0] seed;

    // --- DUT I/O ---
    logic [OUT_WIDTH-1:0] prbs16_out;
    logic valid_out;
    logic [OUT_WIDTH-1:0] prbs_in;
    logic [OUT_WIDTH-1:0] error_cnt;
    logic error;

    // --- Internal ---
    logic [OUT_WIDTH-1:0] prbs_corrupted;
    logic [OUT_WIDTH-1:0] prbs_data_in;
    logic [OUT_WIDTH-1:0] prbs_data_out;
    logic d_serial_valid_out;
    logic inject_error;
    int error_bit;

    // --- Clock generation (FIXED BUG) ---
    initial begin 
        clk_ser = 0; 
        #50; 
        forever #2.5 clk_ser = ~clk_ser; 
    end

    initial clk_2  = 0; always @(posedge clk_ser) clk_2  = ~clk_2;
    initial clk_4  = 0; always @(posedge clk_2)   clk_4  = ~clk_4;
    initial clk_8  = 0; always @(posedge clk_4)   clk_8  = ~clk_8;
    initial clk_16 = 0; always @(posedge clk_8)   clk_16 = ~clk_16;
    initial clk_32 = 0; always @(posedge clk_16)  clk_32 = ~clk_32;

    // --- DUT ---
    prbs_top #(
        .WIDTH(WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut (
        .clk_32(clk_32),
        .clk_16(clk_16),
        .clk_ser(clk_ser),
        .rst_n(rst_n),

        .gen_enable(gen_enable),
        .chk_enable(chk_enable),
        .serdes_enable(serdes_enable),
        .loadseed(loadseed),
        .seed(seed),

        .prbs_corrupted(prbs_corrupted),

        .s_serial_valid(s_serial_valid),
        .serial_out(serial_out),

        .d_serial_valid_out(d_serial_valid_out),
        .prbs16_out(prbs16_out),
        .prbs_in(prbs_in),
        .prbs_data_out(prbs_data_out),
        .prbs_data_in(prbs_data_in),
        .valid_out(valid_out),
        .valid_in(valid_in),
        .error_cnt(error_cnt),
        .error(error)
    );

    // --- Shift Logic (UNCHANGED) ---
    logic [5:0]             shift_amt;
    logic [WIDTH-1:0]       prbs_window;
    logic [WIDTH-1:0]       prbs_shifted;
    logic [OUT_WIDTH-1:0]   prbs16_out_prev;

    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n)
            prbs16_out_prev <= '0;
        else
            prbs16_out_prev <= prbs_data_out;
    end

    always_ff @(posedge clk_16 or negedge rst_n) begin
        if (!rst_n)
            prbs_window <= '0;
        else if (valid_out)
            prbs_window <= {prbs16_out_prev, prbs_data_out};
    end

    assign prbs_shifted = prbs_window << shift_amt;
    assign prbs_in      = prbs_shifted[31:16];

    assign prbs_corrupted = inject_error ?
                            (prbs_in ^ (16'h1 << error_bit)) :
                            prbs_in;
    // --- Tasks -------------------------------------------------------------

    task automatic do_reset();
        rst_n      = 1'b0;
        gen_enable = 1'b0;
        chk_enable = 1'b0;
        serdes_enable = 1'b0;
        loadseed   = 1'b0;
        inject_error = 0;
        
        repeat(5) @(posedge clk_16);
        rst_n = 1'b1;
        repeat(3) @(posedge clk_16);
    endtask

    task automatic do_align();
        repeat(8) @(posedge clk_16);
        @(posedge clk_16); loadseed = 1'b1;
        repeat(3) @(posedge clk_16);
        loadseed = 1'b1;
        repeat(10) @(posedge clk_16);
    endtask

    task automatic run_and_check(input int cycles, input string label);
        logic [OUT_WIDTH-1:0] err_before;
        err_before = error_cnt;
        repeat(cycles) @(posedge clk_16);
        if (error_cnt == err_before)
            $display("  [PASS] %-26s | shift=%0d bits | 0 errors in %0d cycles",
                     label, shift_amt, cycles);
        else
            $display("  [FAIL] %-26s | shift=%0d bits | %0d word errors in %0d cycles",
                     label, shift_amt, (error_cnt - err_before), cycles);
    endtask

    task automatic do_inject_error(input int bit_pos, input int duration, input string label);
        error_bit    = bit_pos;
        inject_error = 1'b1;
        $display("  [INJ ] %-26s | shift=%0d bits | bit=%0d | injecting for %0d cycles",
                 label, shift_amt, bit_pos, duration);
        repeat(duration) @(posedge clk_16);
        inject_error = 1'b0;
    endtask


    // --- Main test sequence -------------------------------------------------
    initial begin
        seed      = 32'hFFFFFFFF;
        shift_amt = 6'd0;

        // -- Test 1: No shift ----------------------------------------------
        $display("\n=== Test 1: No shift (shift_amt=0) ===");
        do_reset();
        #33;
        @(posedge clk_32)
        gen_enable = 1'b1;  
        #320; //#40;
        @(posedge clk_16)
        chk_enable = 1'b1;
        #400;
        @(posedge clk_ser)
        serdes_enable = 1'b1;

        shift_amt  = 6'd0;
        do_align();
        run_and_check(300, "NoShift");

        // -- Test 2: Small shift 1?15 bits ---------------------------------
        $display("\n=== Test 2: Small shift (1?15 bits) ===");
        do_reset();
        @(posedge clk_32) gen_enable = 1'b1;  @(posedge clk_16)chk_enable = 1'b1;@(posedge clk_ser) serdes_enable = 1'b1;
        shift_amt  = $urandom_range(0, 15);
        $display("  shift_amt = %0d", shift_amt);
        do_align();
        run_and_check(300, "SmallShift");

        // -- Test 3: Medium shift 16?31 bits -------------------------------
        $display("\n=== Test 3: Medium shift (16?31 bits) ===");
        do_reset();
         @(posedge clk_32)gen_enable = 1'b1;  @(posedge clk_16)chk_enable = 1'b1;
        shift_amt  = $urandom_range(10, 15);@(posedge clk_ser) serdes_enable = 1'b1;
        $display("  shift_amt = %0d", shift_amt);
        do_align();
        run_and_check(300, "MediumShift");

        // -- Test 4: Large shift 32?47 bits --------------------------------
        $display("\n=== Test 4: Large shift (32?47 bits) ===");
        do_reset();
         @(posedge clk_32)gen_enable = 1'b1;@(posedge clk_16)  chk_enable = 1'b1;@(posedge clk_ser) serdes_enable = 1'b1;
        shift_amt  = $urandom_range(1, 10);
        $display("  shift_amt = %0d", shift_amt);
        do_align();
        run_and_check(300, "LargeShift");

        // -- Test 5: 5? randomised seed + shift ----------------------------
        $display("\n=== Test 5: Random seed + random shift (5 runs) ===");
        repeat(5) begin
            do_reset();
            seed       = $urandom();
             @(posedge clk_32)gen_enable = 1'b1;@(posedge clk_16)  chk_enable = 1'b1; @(posedge clk_ser) serdes_enable = 1'b1;
            shift_amt  = $urandom_range(1, 16);
            $display("  seed=0x%08X  shift_amt=%0d", seed, shift_amt);
            do_align();
            run_and_check(300, "RandSeedShift");
        end

        // -- Test 6: Single-bit flip, 1-cycle burst, no shift --------------
        $display("\n=== Test 6: Inject error bit=7 | 1 cycle | shift=0 ===");
        do_reset();
         @(posedge clk_32)gen_enable = 1'b1;@(posedge clk_16)  chk_enable = 1'b1; @(posedge clk_ser) serdes_enable = 1'b1;
        shift_amt  = 6'd0;
        do_align();
        do_inject_error(7, 1, "T6-bit7-1cyc");
        run_and_check(100, "T6-PostInject");
    
        #100;
        // -- Test 7: Random bit flip, 5-cycle burst, small shift -----------
        $display("\n=== Test 7: Inject random bit | 5 cycles | small shift ===");
        do_reset();
         @(posedge clk_32)gen_enable = 1'b1; @(posedge clk_16) chk_enable = 1'b1; @(posedge clk_ser) serdes_enable = 1'b1;
        shift_amt  = $urandom_range(1, 10);
        $display("  shift_amt = %0d", shift_amt);
        do_align();
        do_inject_error($urandom_range(0,15), 5, "T7-randbit-5cyc");
        run_and_check(100, "T7-PostInject");

        #200;
        // -- Test 8: LSB flip, 20-cycle burst, medium shift ----------------
        $display("\n=== Test 8: Inject error bit=0 | 20 cycles | medium shift ===");
        do_reset();
         @(posedge clk_32)gen_enable = 1'b1;@(posedge clk_16)  chk_enable = 1'b1; @(posedge clk_ser) serdes_enable = 1'b1;
        shift_amt  = $urandom_range(1, 15);
        $display("  shift_amt = %0d", shift_amt);
        do_align();
        do_inject_error(0, 20, "T8-bit0-20cyc");
        run_and_check(150, "T8-PostInject");

        $display("\n=== All tests complete ===");
        $finish;
    end

    initial begin #5_000_000; $display("TIMEOUT"); $finish; end

endmodule
