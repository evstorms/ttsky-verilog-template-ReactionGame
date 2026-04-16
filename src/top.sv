module top (
    input  logic        clk,         // Core clock 25 MHz
    input  logic        rst_btn,     // Reset button (active-high when pressed)
    input  logic        button_0,    // Button 0 (raw)
    input  logic        button_1,    // Button 1 (raw)
    input  logic        button_2,    // Button 2 (raw)
    input  logic        button_3,    // Button 3 (raw)
    input  logic        start,       // Start button (raw)
    input  logic        mode_game,   // Mode switch (0=Classic, 1=Target Match)
    input  logic        mode_player, // Mode switch (0=1P, 1=2P)

    output logic [1:0]  vga_r,       // Red channel (2-bit)
    output logic [1:0]  vga_g,       // Green channel (2-bit)
    output logic [1:0]  vga_b,       // Blue channel (2-bit)
    output logic        vga_hsync,   // VGA horizontal sync
    output logic        vga_vsync    // VGA vertical sync
);

    // Reset 
    logic rst_sync, rst_n;
    always_ff @(posedge clk) begin
        rst_sync <= ~rst_btn;
        rst_n    <= rst_sync;
    end

    // Internal wires
    logic        start_clean;
    logic [3:0]  btn_clean;
    logic [15:0] lfsr_out;
    logic        clk_1ms;
    logic        full_reset;
    logic        rxn_en, rxn_clr, dly_load, dly_en, lfsr_en;
    logic        target_latch, p1_save, result_valid, p2_turn;
    logic [2:0]  disp_mode;
    logic        resp_correct;
    logic        dly_done;
    logic [13:0] rxn_time;
    logic [13:0] p1_time;
    logic        p1_valid;
    logic [1:0]  winner;

    // Button synchronizers
    button_sync u_btn_start (.clk, .rst_n, .raw(start),    .clean(start_clean));
    button_sync u_btn0      (.clk, .rst_n, .raw(button_0), .clean(btn_clean[0]));
    button_sync u_btn1      (.clk, .rst_n, .raw(button_1), .clean(btn_clean[1]));
    button_sync u_btn2      (.clk, .rst_n, .raw(button_2), .clean(btn_clean[2]));
    button_sync u_btn3      (.clk, .rst_n, .raw(button_3), .clean(btn_clean[3]));

    // Bits[15:14] → 2-bit quadrant; bits[11:0] → 12-bit delay seed
    lfsr16 u_lfsr (.clk, .rst_n, .en(lfsr_en), .out(lfsr_out));

    // Game controller (FSM)
    game_controller u_gc (
        .clk, .rst_n,
        .start(start_clean),
        .btn_in(btn_clean),
        .mode_target(mode_game),
        .mode_player,
        .resp_correct, .dly_done,
        .rxn_en, .rxn_clr, .dly_load, .dly_en, .lfsr_en,
        .target_latch, .p1_save, .result_valid, .p2_turn,
        .disp_mode
    );

    // Response checker
    response_checker u_rc (
        .clk, .rst_n,
        .target_latch,
        .lfsr_in(lfsr_out[15:14]),
        .mode_target(mode_game),
        .btn_in(btn_clean),
        .resp_correct
    );

    // Core timer
    core_timer u_ct (
        .clk, .rst_n,
        .rxn_en, .rxn_clr,
        .dly_en, .dly_load,
        .dly_seed(lfsr_out[11:0]),
        .clk_1ms,
        .rxn_time, .dly_done
    );

    assign full_reset = start_clean && (disp_mode == 3'd7);

    // Score store
    score_store u_ss (
        .clk, .rst_n,
        .p1_save,
        .full_reset,
        .cur_time(rxn_time),
        .cur_valid(result_valid),
        .p1_time, .p1_valid, .winner
    );

    // VGA controller
    vga_controller u_vga (
        .clk, .rst_n,
        .clk_1ms,
        .disp_mode,
        .lfsr_in(lfsr_out[15:14]),
        .rxn_time, .p1_time, .p1_valid,
        .winner, .p2_turn, .result_valid,
        .mode_target(mode_game),
        .mode_player,
        .vga_r, .vga_g, .vga_b,
        .vga_hsync, .vga_vsync
    );

endmodule
