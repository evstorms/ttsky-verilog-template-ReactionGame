module button_sync (
    input  logic clk,   // Core clock 25 MHz
    input  logic rst_n, // Synchronous reset
    input  logic raw,   // Asynchronous input

    output logic clean  // Synchronous output: single-cycle rising-edge pulse
);

    logic ff1, ff2, ff3;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            ff1 <= 0;
            ff2 <= 0;
            ff3 <= 0;
        end else begin
            ff1 <= raw;
            ff2 <= ff1;
            ff3 <= ff2;
        end
    end

    assign clean = ff2 & ~ff3; 
endmodule
