`timescale 1ns/1ps

module tb_game_controller;

    logic       clk;
    logic       rst_n;
    logic       start;
    logic [3:0] btn_in;
    logic       mode_target;
    logic       mode_player;
    logic       resp_correct;
    logic       dly_done;

    logic       rxn_en;
    logic       rxn_clr;
    logic       dly_load;
    logic       dly_en;
    logic       lfsr_en;
    logic       target_latch;
    logic       p1_save;
    logic       result_valid;
    logic       p2_turn;
    logic [2:0] disp_mode;

    game_controller dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .btn_in       (btn_in),
        .mode_target  (mode_target),
        .mode_player  (mode_player),
        .resp_correct (resp_correct),
        .dly_done     (dly_done),
        .rxn_en       (rxn_en),
        .rxn_clr      (rxn_clr),
        .dly_load     (dly_load),
        .dly_en       (dly_en),
        .lfsr_en      (lfsr_en),
        .target_latch (target_latch),
        .p1_save      (p1_save),
        .result_valid (result_valid),
        .p2_turn      (p2_turn),
        .disp_mode    (disp_mode)
    );

    initial clk = 0;
    always #20 clk = ~clk;

    initial begin
        $dumpfile("tb/wave_game_controller.fst");
        $dumpvars(0, tb_game_controller);
    end

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic do_start;
        start = 1; tick; start = 0;
    endtask

    task automatic do_btn(input logic [3:0] btn);
        btn_in = btn; tick; btn_in = 4'b0;
    endtask

    task automatic do_dly_done;
        dly_done = 1; tick; dly_done = 0;
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

    task automatic check_val(input logic [2:0] got, input logic [2:0] exp, input string msg);
        if (got === exp) begin
            $display("  PASS: %s  (got=%0d)", msg, got);
            pass_count++;
        end else begin
            $display("  FAIL: %s  (expected=%0d, got=%0d)", msg, exp, got);
            fail_count++;
        end
    endtask

    task automatic check_state(input logic [2:0] exp, input string msg);
        if (dut.state === exp) begin
            $display("  PASS: %s  (state=%0d)", msg, dut.state);
            pass_count++;
        end else begin
            $display("  FAIL: %s  (expected state=%0d, got=%0d)", msg, exp, dut.state);
            fail_count++;
        end
    endtask

    initial begin
        rst_n        = 0;
        start        = 0;
        btn_in       = 4'b0;
        mode_target  = 0;
        mode_player  = 0;
        resp_correct = 0;
        dly_done     = 0;

        $display("\n--- TEST 1: Reset ---");
        repeat(2) tick;
        check_state(3'd0, "state=IDLE during reset");
        check(rxn_en,      1'b0, "rxn_en=0 during reset");
        check(dly_en,      1'b0, "dly_en=0 during reset");
        check(result_valid,1'b0, "result_valid=0 during reset");

        rst_n = 1; tick;
        check_state(3'd0, "state=IDLE after reset");

        // Test 2
        $display("\n--- TEST 2: 1P Classic happy path ---");
        mode_player = 0; mode_target = 0;

        // IDLE → WAIT_RANDOM 
        check(rxn_clr,  1'b0, "rxn_clr=0 before start");
        check(dly_load, 1'b0, "dly_load=0 before start");
        start = 1;
        #1;
        check(rxn_clr,  1'b1, "rxn_clr=1 on start pulse (IDLE&&start)");
        check(dly_load, 1'b1, "dly_load=1 on start pulse (IDLE&&start)");
        tick; start = 0; tick;
        check_state(3'd1, "state=WAIT_RANDOM after start");
        check(dly_en,   1'b1, "dly_en=1 in WAIT_RANDOM");
        check(lfsr_en,  1'b1, "lfsr_en=1 in WAIT_RANDOM");
        check(rxn_en,   1'b0, "rxn_en=0 in WAIT_RANDOM");
        check(rxn_clr,  1'b0, "rxn_clr=0 one cycle after start");
        check(dly_load, 1'b0, "dly_load=0 one cycle after start");

        // WAIT_RANDOM → STIMULUS on dly_done; target_latch fires same cycle
        dly_done = 1;
        #1;
        check(target_latch, 1'b1, "target_latch=1 on dly_done in WAIT_RANDOM");
        tick; dly_done = 0; tick;
        check_state(3'd2, "state=STIMULUS after dly_done");
        check(rxn_en,       1'b1, "rxn_en=1 in STIMULUS");
        check(dly_en,       1'b0, "dly_en=0 in STIMULUS");
        check(target_latch, 1'b0, "target_latch=0 one cycle after dly_done");

        // STIMULUS → RESULT on button press 
        do_btn(4'b0001);
        tick;
        check_state(3'd3, "state=RESULT after btn press");
        check(result_valid, 1'b1, "result_valid=1 Classic mode");
        check_val(disp_mode, 3'd3, "disp_mode=3 (valid result)");
        check(rxn_en, 1'b0, "rxn_en=0 in RESULT");

        // RESULT → IDLE on start 
        do_start; tick;
        check_state(3'd0, "state=IDLE after start in RESULT (1P)");

        // Test 3 - 1P correct & wrong button
        $display("\n--- TEST 3: 1P Target Match ---");
        mode_target = 1;

        // Correct button path
        do_start; tick;                  // IDLE → WAIT_RANDOM
        do_dly_done; tick;               // WAIT_RANDOM → STIMULUS
        resp_correct = 1;
        do_btn(4'b0001); tick;
        check(result_valid, 1'b1, "result_valid=1 Target Match, correct btn");
        check_val(disp_mode, 3'd3, "disp_mode=3 correct result");
        do_start; tick;                  // back to IDLE

        // Wrong button path
        do_start; tick;
        do_dly_done; tick;
        resp_correct = 0;
        do_btn(4'b0001); tick;
        check(result_valid, 1'b0, "result_valid=0 Target Match, wrong btn");
        check_val(disp_mode, 3'd4, "disp_mode=4 incorrect result");
        do_start; tick;

        // Test 4
        $display("\n--- TEST 4: False start ---");
        mode_target = 0;

        do_start; tick;                  // IDLE → WAIT_RANDOM
        check_state(3'd1, "state=WAIT_RANDOM");

        do_btn(4'b0001); tick;           // button during delay → FALSE_START
        check_state(3'd4, "state=FALSE_START after btn during delay");
        check(rxn_en,   1'b0, "rxn_en=0 in FALSE_START");
        check_val(disp_mode, 3'd5, "disp_mode=5 in FALSE_START");

        do_start; tick;                  // FALSE_START → RESULT
        check_state(3'd3, "state=RESULT after start in FALSE_START");
        do_start; tick;                  // back to IDLE

        // Test 5 - 2P 
        $display("\n--- TEST 5: 2P full flow ---");
        mode_player = 1; mode_target = 0; resp_correct = 1;

        // P1 round
        do_start; tick;                  // IDLE → WAIT_RANDOM
        do_dly_done; tick;               // WAIT_RANDOM → STIMULUS
        do_btn(4'b0001); tick;           // STIMULUS → RESULT (p2_turn_r=0)
        check_state(3'd3, "state=RESULT after P1 btn");
        check(p2_turn, 1'b0, "p2_turn=0 during P1 result");

        // Save P1 score and go to IDLE_2P
        start = 1;
        #1;
        check(p1_save, 1'b1, "p1_save=1 on start in RESULT (2P, P1 turn)");
        tick; start = 0; tick;
        check_state(3'd5, "state=IDLE_2P");
        check(p2_turn,   1'b1, "p2_turn=1 in IDLE_2P");
        check_val(disp_mode, 3'd6, "disp_mode=6 in IDLE_2P");
        check(p1_save,   1'b0, "p1_save=0 one cycle after start");

        // P2 round
        do_start; tick;                  // IDLE_2P → WAIT_RANDOM
        check_state(3'd1, "state=WAIT_RANDOM for P2");
        do_dly_done; tick;               // WAIT_RANDOM → STIMULUS
        do_btn(4'b0001);                 // STIMULUS → COMPARE (p2_turn_r=1)
        check_state(3'd6, "state=COMPARE after P2 btn");

        tick;                            // COMPARE → SHOW_WINNER (automatic)
        check_state(3'd7, "state=SHOW_WINNER");

        do_start; tick;                  // SHOW_WINNER → IDLE
        check_state(3'd0, "state=IDLE after show winner");
        check(p2_turn, 1'b0, "p2_turn=0 reset after game");

        // Test 6
        $display("\n--- TEST 6: Output pulse widths ---");
        mode_player = 0; mode_target = 0;

        start = 1; #1;
        check(rxn_clr,  1'b1, "rxn_clr HIGH on start cycle");
        check(dly_load, 1'b1, "dly_load HIGH on start cycle");
        @(posedge clk); start = 0; #1;
        check(rxn_clr,  1'b0, "rxn_clr LOW next cycle");
        check(dly_load, 1'b0, "dly_load LOW next cycle");

        dly_done = 1; #1;
        check(target_latch, 1'b1, "target_latch HIGH on dly_done cycle");
        @(posedge clk); dly_done = 0; #1;
        check(target_latch, 1'b0, "target_latch LOW next cycle");



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
