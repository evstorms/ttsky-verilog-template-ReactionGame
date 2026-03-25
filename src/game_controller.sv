module game_controller (
    input  logic       clk,          // Core clock 25 MHz
    input  logic       rst_n,        // Synchronous reset
    input  logic       start,        // Start button pressed (1-cycle pulse from button_sync)
    input  logic [3:0] btn_in,       // Reaction button pressed (one-hot, 1-cycle pulse)
    input  logic       mode_target,  // Game mode switch (0=Classic, 1=Target Match)
    input  logic       mode_player,  // Player count switch (0=1P, 1=2P)
    input  logic       resp_correct, // From Response Checker
    input  logic       dly_done,     // From Core Timer

    output logic       rxn_en,       // To Core Timer: enable reaction counter
    output logic       rxn_clr,      // To Core Timer: clear reaction counter
    output logic       dly_load,     // To Core Timer: load delay seed (1-cycle pulse)
    output logic       dly_en,       // To Core Timer: enable delay countdown
    output logic       lfsr_en,      // To LFSR16: advance LFSR
    output logic       target_latch, // To Response Checker: latch quadrant (1-cycle pulse)
    output logic       p1_save,      // To Score Store: latch P1 result (1-cycle pulse)
    output logic       result_valid, // To Score Store & VGA: result is correct
    output logic       p2_turn,      // To VGA: P2 is currently active
    output logic [2:0] disp_mode    // To VGA Controller: display mode encoding
);

    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        WAIT_RANDOM = 3'd1,
        STIMULUS    = 3'd2,
        RESULT      = 3'd3,
        FALSE_START = 3'd4,
        IDLE_2P     = 3'd5,
        COMPARE     = 3'd6,
        SHOW_WINNER = 3'd7
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    logic p2_turn_r;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            p2_turn_r <= 0;
        end else if (state == RESULT && start && mode_player && !p2_turn_r) begin
            p2_turn_r <= 1;
        end else if (state == SHOW_WINNER && start)begin
            p2_turn_r <= 0;
        end
    end

    logic result_valid_r;
    logic any_btn_rise;
    assign any_btn_rise = |btn_in;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            result_valid_r <= 0;
        end else if (state == WAIT_RANDOM && any_btn_rise) begin
            result_valid_r <= 0;  
        end else if (state == STIMULUS && any_btn_rise) begin
            result_valid_r <= !mode_target || resp_correct;
        end
    end

    always_comb begin
        next_state = state; 
        case (state)
            IDLE:        if (start)                                    next_state = WAIT_RANDOM;
            WAIT_RANDOM: if (any_btn_rise)                             next_state = FALSE_START;
                    else if (dly_done)                                 next_state = STIMULUS;
            STIMULUS:    if (any_btn_rise && mode_player && p2_turn_r)  next_state = COMPARE;
                    else if (any_btn_rise)                             next_state = RESULT;
            FALSE_START: if (start)                                    next_state = RESULT;
            RESULT:      if (start && !mode_player)                    next_state = IDLE;
                    else if (start && mode_player && !p2_turn_r)       next_state = IDLE_2P;
                    else if (start && mode_player &&  p2_turn_r)       next_state = COMPARE;
            IDLE_2P:     if (start)                                    next_state = WAIT_RANDOM;
            COMPARE:                                                   next_state = SHOW_WINNER; 
            SHOW_WINNER: if (start)                                    next_state = IDLE;
            default:                                                   next_state = IDLE;
        endcase
    end

    // Pulse output
    assign rxn_clr      = ((state == IDLE) || (state == IDLE_2P)) && start;
    assign dly_load     = ((state == IDLE) || (state == IDLE_2P)) && start;
    assign target_latch = (state == WAIT_RANDOM) && dly_done;
    assign p1_save      = (state == RESULT) && start && mode_player && !p2_turn_r;

    // Steady output
    assign rxn_en       = (state == STIMULUS);
    assign dly_en       = (state == WAIT_RANDOM);
    assign lfsr_en      = (state == IDLE) || (state == IDLE_2P) || (state == WAIT_RANDOM && !dly_done);
    assign p2_turn      = p2_turn_r;
    assign result_valid = result_valid_r;

    // Disp mode
    always_comb begin
        case (state)
            IDLE:        disp_mode = 3'd0;
            WAIT_RANDOM: disp_mode = 3'd1;
            STIMULUS:    disp_mode = 3'd2;
            RESULT:      disp_mode = result_valid_r ? 3'd3 : 3'd4;
            FALSE_START: disp_mode = 3'd5;
            IDLE_2P:     disp_mode = 3'd6;
            COMPARE:     disp_mode = 3'd7;
            SHOW_WINNER: disp_mode = 3'd7;
            default:     disp_mode = 3'd0;
        endcase
    end

endmodule
