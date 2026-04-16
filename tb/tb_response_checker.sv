`timescale 1ns/1ps

module tb_response_checker;

    logic       clk;
    logic       rst_n;
    logic       target_latch;
    logic [1:0] lfsr_in;
    logic       mode_target;
    logic [3:0] btn_in;
    logic       resp_correct;

    response_checker dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .target_latch (target_latch),
        .lfsr_in      (lfsr_in),
        .mode_target  (mode_target),
        .btn_in       (btn_in),
        .resp_correct (resp_correct)
    );

    initial clk = 0;
    always #20 clk = ~clk;

    initial begin
        $dumpfile("tb/wave_response_checker.fst");
        $dumpvars(0, tb_response_checker);
    end

    // Advance one full clock cycle; sample outputs 1 ns after rising edge
    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    // Pulse target_latch for exactly one cycle, loading quadrant q
    task automatic do_latch(input logic [1:0] q);
        lfsr_in      = q;
        target_latch = 1;
        tick;
        target_latch = 0;
    endtask

    // Checker
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

    initial begin
        rst_n        = 0;
        target_latch = 0;
        lfsr_in      = 2'b00;
        mode_target  = 0;
        btn_in       = 4'b0000;

        $display("\n--- TEST 1: Reset ---");
        repeat(2) tick;
        rst_n = 1;
        tick;
        check(resp_correct, 1'b0, "after reset, no button, Classic → resp_correct=0");

        $display("\n--- TEST 2: Classic mode ---");
        mode_target = 0;

        btn_in = 4'b0000;
        #1;
        check(resp_correct, 1'b0, "no button → resp_correct=0");

        btn_in = 4'b0001; #1; check(resp_correct, 1'b1, "btn[0] → resp_correct=1");
        btn_in = 4'b0010; #1; check(resp_correct, 1'b1, "btn[1] → resp_correct=1");
        btn_in = 4'b0100; #1; check(resp_correct, 1'b1, "btn[2] → resp_correct=1");
        btn_in = 4'b1000; #1; check(resp_correct, 1'b1, "btn[3] → resp_correct=1");
        btn_in = 4'b0000;

        $display("\n--- TEST 3: Target Match, correct button ---");
        mode_target = 1;
        begin
            int q;
            for (q = 0; q < 4; q++) begin
                do_latch(q[1:0]);
                btn_in = 4'b0001 << q;
                #1;
                check(resp_correct, 1'b1,
                      $sformatf("quadrant=%0d, correct btn → resp_correct=1", q));
                btn_in = 4'b0000;
            end
        end

        $display("\n--- TEST 4: Target Match, wrong button ---");
        mode_target = 1;
        begin
            int q;
            for (q = 0; q < 4; q++) begin
                do_latch(q[1:0]);
                btn_in = 4'b0001 << ((q + 1) % 4);
                #1;
                check(resp_correct, 1'b0,
                      $sformatf("quadrant=%0d, wrong btn → resp_correct=0", q));
                btn_in = 4'b0000;
            end
        end

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
