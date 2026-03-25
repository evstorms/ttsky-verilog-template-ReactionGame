module response_checker (
    input  logic       clk,          // Core clock 25 MHz
    input  logic       rst_n,        // Synchronous reset
    input  logic       target_latch, // One-cycle pulse: latch LFSR quadrant bits now
    input  logic [1:0] lfsr_in,      // lfsr16 val[15:14] (quadrant select)
    input  logic       mode_target,  // 0=Classic, 1=Target Match
    input  logic [3:0] btn_in,       // One-hot rising-edge button events

    output logic       resp_correct  // Button press was correct
);

    logic [1:0] lfsr_reg;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            lfsr_reg <= 0;
        end else begin
            if (target_latch) lfsr_reg <= lfsr_in;
        end
    end

    always_comb begin
        if (~mode_target) begin
            resp_correct = |btn_in;
        end else begin
            resp_correct = btn_in[lfsr_reg];
        end
    end
endmodule
