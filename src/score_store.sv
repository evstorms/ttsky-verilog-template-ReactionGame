module score_store (
    input  logic        clk,        // Core clock 25 MHz
    input  logic        rst_n,      // Synchronous reset
    input  logic        p1_save,    // Latch current result as P1 (1-cycle pulse)
    input  logic        full_reset, // Clear all stored results
    input  logic [13:0] cur_time,   // Current rxn_time from Core Timer
    input  logic        cur_valid,  // Current result_valid from Game Controller

    output logic [13:0] p1_time,    // Stored P1 reaction time
    output logic        p1_valid,   // Stored P1 result validity
    output logic [1:0]  winner      // 01=P1, 10=P2, 11=Tie
);

    logic [13:0] p1_time_reg;
    logic p1_valid_reg;

    // store player 1 score
    always_ff @(posedge clk) begin
        if (~rst_n || full_reset) begin
            p1_time_reg <= 0;
            p1_valid_reg <= 0;
        end else begin
            if (p1_save) begin
                p1_time_reg <= cur_time;
                p1_valid_reg <= cur_valid;
            end
        end
    end

    // identify winner
    always_comb begin
        p1_time = p1_time_reg;
        p1_valid = p1_valid_reg;

        if ( p1_valid_reg &&  cur_valid) winner = (p1_time_reg < cur_time) ? 2'b01 : (cur_time < p1_time_reg) ? 2'b10 : 2'b11;
        else if ( p1_valid_reg && !cur_valid) winner = 2'b01;
        else if (!p1_valid_reg &&  cur_valid) winner = 2'b10;
        else                             winner = 2'b11;
    end

endmodule
