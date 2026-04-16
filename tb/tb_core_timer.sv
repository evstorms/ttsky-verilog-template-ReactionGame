`timescale 1ns/1ps

module tb_core_timer;

    logic        clk;
    logic        rst_n;
    logic        rxn_en;
    logic        rxn_clr;
    logic        dly_en;
    logic        dly_load;
    logic [11:0] dly_seed;

    logic        clk_1ms;
    logic [13:0] rxn_time;
    logic        dly_done;

    core_timer dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rxn_en   (rxn_en),
        .rxn_clr  (rxn_clr),
        .dly_en   (dly_en),
        .dly_load (dly_load),
        .dly_seed (dly_seed),
        .clk_1ms  (clk_1ms),
        .rxn_time (rxn_time),
        .dly_done (dly_done)
    );

    initial clk = 0;
    always #20 clk = ~clk;

    initial begin
        $dumpfile("tb/wave_core_timer.fst");
        $dumpvars(0, tb_core_timer);
    end

    // Advance one full clock cycle; sample outputs 1 ns after rising edge
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    // Force a single 1ms tick without waiting 25,000 prescaler cycles
    task automatic inject_1ms;
        force dut.clk_1ms = 1;
        @(posedge clk); #1;
        force dut.clk_1ms = 0;
        @(posedge clk); #1;
    endtask

    // Release clk_1ms so the prescaler drives it normally
    task automatic release_1ms;
        release dut.clk_1ms;
    endtask

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input logic got, input logic exp, input string msg);
        if (got === exp) begin
            $display("  PASS: %s  (got=%0b)", msg, got);
            pass_count++;
        end else begin
            $display("  FAIL: %s  (expected=%0b, got=%0b)", msg, exp, got);
            fail_count++;
        end
    endtask

    task automatic check_val(input logic [13:0] got, input logic [13:0] exp, input string msg);
        if (got === exp) begin
            $display("  PASS: %s  (got=%0d)", msg, got);
            pass_count++;
        end else begin
            $display("  FAIL: %s  (expected=%0d, got=%0d)", msg, exp, got);
            fail_count++;
        end
    endtask

    initial begin
        rst_n    = 0;
        rxn_en   = 0;
        rxn_clr  = 0;
        dly_en   = 0;
        dly_load = 0;
        dly_seed = 12'd0;

        $display("\n--- TEST 1: Reset ---");
        repeat(2) tick;
        check(clk_1ms,       1'b0, "clk_1ms=0 during reset");
        check(dly_done,      1'b0, "dly_done=0 during reset");
        check_val(rxn_time, 14'd0, "rxn_time=0 during reset");

        rst_n = 1;
        tick;
        check(clk_1ms,       1'b0, "clk_1ms=0 one cycle after reset release");
        check_val(rxn_time, 14'd0, "rxn_time=0 after reset");

        $display("\n--- TEST 2: Prescaler / clk_1ms ---");
        begin
            int pulse_count;
            int i;
            pulse_count = 0;

            fork
                begin
                    repeat(50000) @(posedge clk);
                end
                begin
                    forever begin
                        @(posedge clk);
                        if (clk_1ms) pulse_count++;
                    end
                end
            join_any
            disable fork;

            if (pulse_count == 2)
                $display("  PASS: clk_1ms pulsed %0d times in 50000 cycles (expected 2)", pulse_count);
            else begin
                $display("  FAIL: clk_1ms pulsed %0d times in 50000 cycles (expected 2)", pulse_count);
                fail_count++;
            end
            pass_count += (pulse_count == 2) ? 1 : 0;
        end

        force dut.clk_1ms = 0;  // switch to injected ticks for counter tests

        $display("\n--- TEST 3: Reaction timer ---");
        rxn_clr = 1; tick; rxn_clr = 0; tick;
        check_val(rxn_time, 14'd0, "rxn_time=0 after rxn_clr");

        rxn_en = 1;
        inject_1ms; check_val(rxn_time, 14'd1, "rxn_time=1 after 1 tick");
        inject_1ms; check_val(rxn_time, 14'd2, "rxn_time=2 after 2 ticks");
        inject_1ms; check_val(rxn_time, 14'd3, "rxn_time=3 after 3 ticks");

        rxn_en = 0;
        inject_1ms; check_val(rxn_time, 14'd3, "rxn_time holds at 3 when rxn_en=0");

        rxn_en = 1;
        inject_1ms; inject_1ms;
        rxn_clr = 1; tick; rxn_clr = 0; tick;
        check_val(rxn_time, 14'd0, "rxn_time=0 after mid-count rxn_clr");

        $display("\n--- TEST 4: Reaction timer saturation ---");
        force dut.rxn_counter = 14'd9998;   // seed near ceiling
        rxn_en = 1;
        inject_1ms; check_val(rxn_time, 14'd9999, "rxn_time=9999 at ceiling");
        inject_1ms; check_val(rxn_time, 14'd9999, "rxn_time stays 9999 (saturated)");
        release dut.rxn_counter;
        rxn_clr = 1; tick; rxn_clr = 0;

        $display("\n--- TEST 5: Delay counter ---");
        dly_seed = 12'd0;
        dly_load = 1; tick; dly_load = 0; tick;
        check_val(dut.dly_counter, 13'd1000, "dly_counter=1000 after load (seed=0)");
        check(dly_done, 1'b0, "dly_done=0 right after load");

        dly_seed = 12'd5;
        dly_load = 1; tick; dly_load = 0; tick;
        check_val(dut.dly_counter, 13'd1005, "dly_counter=1005 after load (seed=5)");

        dly_en = 1;
        inject_1ms; check_val(dut.dly_counter, 13'd1004, "dly_counter decrements to 1004");
        inject_1ms; check_val(dut.dly_counter, 13'd1003, "dly_counter decrements to 1003");
        check(dly_done, 1'b0, "dly_done=0 while counting");

        dly_en = 0;
        inject_1ms; check_val(dut.dly_counter, 13'd1003, "dly_counter holds when dly_en=0");

        dly_en = 1;
        force dut.dly_counter = 13'd1;  // skip to last step
        inject_1ms; check_val(dut.dly_counter, 13'd0, "dly_counter=0 after last decrement");
        inject_1ms; check(dly_done, 1'b1, "dly_done=1 when counter=0 and dly_en=1");
        release dut.dly_counter;

        dly_seed = 12'd0;
        dly_load = 1; tick; dly_load = 0; tick;
        check(dly_done, 1'b0, "dly_done=0 after reload");

        release_1ms;

        $display("\n==========================================");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("==========================================\n");

        $finish;
    end

endmodule
