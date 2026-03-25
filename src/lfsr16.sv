module lfsr16 (
    input  logic        clk,        // Core clock 25 MHz
    input  logic        rst_n,      // Synchronous reset
    input  logic        en,         // Advance LFSR

    output logic [15:0] out         // Current LFSR value
);
    logic feedback;
    logic [15:0] lfsr;

    always_ff @(posedge clk) begin
        if(~rst_n) begin
            lfsr <= 16'hACE1;
        end else begin
            if (en) begin
                lfsr <= {lfsr[14:0], feedback};
            end
        end
    end

    assign out = lfsr;
    assign feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
endmodule
