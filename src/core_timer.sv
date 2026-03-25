module core_timer (
    input  logic        clk,        // Core clock 25 MHz
    input  logic        rst_n,      // Synchronous reset
    input  logic        rxn_en,     // Enable reaction counter (asserted in STIMULUS)
    input  logic        rxn_clr,    // Clear reaction counter
    input  logic        dly_en,     // Enable delay countdown (held through WAIT_RANDOM)
    input  logic        dly_load,   // Load delay seed into counter (1-cycle pulse on WAIT_RANDOM entry)
    input  logic [11:0] dly_seed,   // Random delay seed from lfsr16 val[11:0]

    output logic        clk_1ms,    // Single-cycle 1ms pulse (shared system-wide)
    output logic [13:0] rxn_time,   // Reaction time in milliseconds
    output logic        dly_done    // Single-cycle pulse when delay countdown hits zero
);

    logic [14:0] prescalar; // counts 0→24999, resets, pulses tick_1ms at terminal count
    logic [13:0] rxn_counter; // increments on (rxn_en & tick_1ms), clears on rxn_clr
    logic [12:0] dly_counter; //loads (dly_seed + 13'd1000) on dly_load decrements on (dly_en & tick_1ms) pulses dly_done when hits zero

    // prescalar timer
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            prescalar <= 0;
            clk_1ms <= 0;
        end else begin
            if (prescalar == 24999) begin
                prescalar <= 0;
                clk_1ms <= 1;
            end else begin
                prescalar <= prescalar+1;
                clk_1ms <= 0;
            end
        end
    end
    
    // reaction timer
    always_ff @(posedge clk) begin
        if (~rst_n || rxn_clr) begin
            rxn_counter <= 0;
        end else begin
            if (rxn_en && clk_1ms) begin
                rxn_counter <= (rxn_counter == 14'd9999) ? 14'd9999: rxn_counter+1;
            end 
        end
    end

    assign rxn_time = rxn_counter;

    // delay counter
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            dly_counter <= 0;
            dly_done <= 0;
        end else begin
            if (dly_load) begin
                dly_counter <= 13'd1000 + dly_seed;
                dly_done <= 0;
            end else begin
                if (dly_en && clk_1ms && (dly_counter == 0)) begin
                    dly_done <= 1;
                end else if (dly_en && clk_1ms) begin
                    dly_counter <= dly_counter -1;
                end
            end
        end
    end

endmodule
