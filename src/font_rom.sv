module font_rom (
    input  logic [4:0] char,    // Character index (0–19)
    input  logic [2:0] row,     // Row within character

    output logic [3:0] bitmap   // 4-pixel row, MSB = leftmost pixel
);

// Index = {char[4:0], row[2:0]} — each character occupies 8 slots (rows 0–5 used)
//
// Char map:
//   0–9  : '0'–'9'   (reaction time digits)
//   10   : 'P'
//   11   : 'T'
//   12   : 'I'
//   13   : 'E'
//   14   : 'W'
//   15   : 'N'
//   16   : 'A'
//   17   : 'R'
//   18   : 'L'
//   19   : 'Y'

always_comb begin
    case ({char, row})
        // --- 0: '0' ---
        8'h00: bitmap = 4'hE;   
        8'h01: bitmap = 4'hA;  
        8'h02: bitmap = 4'hA;
        8'h03: bitmap = 4'hA;
        8'h04: bitmap = 4'hA;
        8'h05: bitmap = 4'hE;   

        // --- 1: '1' ---
        8'h08: bitmap = 4'h4;   
        8'h09: bitmap = 4'hC; 
        8'h0A: bitmap = 4'h4;
        8'h0B: bitmap = 4'h4;
        8'h0C: bitmap = 4'h4;
        8'h0D: bitmap = 4'hE;   

        // --- 2: '2' ---
        8'h10: bitmap = 4'hE;
        8'h11: bitmap = 4'h2;   
        8'h12: bitmap = 4'h2;
        8'h13: bitmap = 4'hE;
        8'h14: bitmap = 4'h8;   
        8'h15: bitmap = 4'hE;

        // --- 3: '3' ---
        8'h18: bitmap = 4'hE;
        8'h19: bitmap = 4'h2;
        8'h1A: bitmap = 4'h6;   
        8'h1B: bitmap = 4'h2;
        8'h1C: bitmap = 4'h2;
        8'h1D: bitmap = 4'hE;

        // --- 4: '4' ---
        8'h20: bitmap = 4'hA;
        8'h21: bitmap = 4'hA;
        8'h22: bitmap = 4'hE;
        8'h23: bitmap = 4'h2;
        8'h24: bitmap = 4'h2;
        8'h25: bitmap = 4'h2;

        // --- 5: '5' ---
        8'h28: bitmap = 4'hE;
        8'h29: bitmap = 4'h8;
        8'h2A: bitmap = 4'hE;
        8'h2B: bitmap = 4'h2;
        8'h2C: bitmap = 4'h2;
        8'h2D: bitmap = 4'hE;

        // --- 6: '6' ---
        8'h30: bitmap = 4'hE;
        8'h31: bitmap = 4'h8;
        8'h32: bitmap = 4'hE;
        8'h33: bitmap = 4'hA;
        8'h34: bitmap = 4'hA;
        8'h35: bitmap = 4'hE;

        // --- 7: '7' ---
        8'h38: bitmap = 4'hE;
        8'h39: bitmap = 4'h2;
        8'h3A: bitmap = 4'h2;
        8'h3B: bitmap = 4'h4;
        8'h3C: bitmap = 4'h4;
        8'h3D: bitmap = 4'h4;

        // --- 8: '8' ---
        8'h40: bitmap = 4'hE;
        8'h41: bitmap = 4'hA;
        8'h42: bitmap = 4'hE;
        8'h43: bitmap = 4'hA;
        8'h44: bitmap = 4'hA;
        8'h45: bitmap = 4'hE;

        // --- 9: '9' ---
        8'h48: bitmap = 4'hE;
        8'h49: bitmap = 4'hA;
        8'h4A: bitmap = 4'hE;
        8'h4B: bitmap = 4'h2;
        8'h4C: bitmap = 4'h2;
        8'h4D: bitmap = 4'hE;

        // --- 10 (0xA): 'P' ---
        8'h50: bitmap = 4'hE;
        8'h51: bitmap = 4'hA;
        8'h52: bitmap = 4'hE;
        8'h53: bitmap = 4'h8;
        8'h54: bitmap = 4'h8;
        8'h55: bitmap = 4'h8;

        // --- 11 (0xB): 'T' ---
        8'h58: bitmap = 4'hE;
        8'h59: bitmap = 4'h4;
        8'h5A: bitmap = 4'h4;
        8'h5B: bitmap = 4'h4;
        8'h5C: bitmap = 4'h4;
        8'h5D: bitmap = 4'h4;

        // --- 12 (0xC): 'I' ---
        8'h60: bitmap = 4'hE;
        8'h61: bitmap = 4'h4;
        8'h62: bitmap = 4'h4;
        8'h63: bitmap = 4'h4;
        8'h64: bitmap = 4'h4;
        8'h65: bitmap = 4'hE;

        // --- 13 (0xD): 'E' ---
        8'h68: bitmap = 4'hE;
        8'h69: bitmap = 4'h8;
        8'h6A: bitmap = 4'hE;
        8'h6B: bitmap = 4'h8;
        8'h6C: bitmap = 4'h8;
        8'h6D: bitmap = 4'hE;

        // --- 14 (0xE): 'W' ---
        8'h70: bitmap = 4'hA;
        8'h71: bitmap = 4'hA;
        8'h72: bitmap = 4'hA;
        8'h73: bitmap = 4'hF;
        8'h74: bitmap = 4'h6;
        8'h75: bitmap = 4'h6;

        // --- 15 (0xF): 'N' ---
        8'h78: bitmap = 4'h9;
        8'h79: bitmap = 4'hD;
        8'h7A: bitmap = 4'hD;
        8'h7B: bitmap = 4'hB;
        8'h7C: bitmap = 4'hB;
        8'h7D: bitmap = 4'h9;

        // --- 16 (0x10): 'A' ---
        8'h80: bitmap = 4'h6;
        8'h81: bitmap = 4'h9;
        8'h82: bitmap = 4'h9;
        8'h83: bitmap = 4'hF;
        8'h84: bitmap = 4'h9;
        8'h85: bitmap = 4'h9;

        // --- 17 (0x11): 'R' ---
        8'h88: bitmap = 4'hE;
        8'h89: bitmap = 4'hA;
        8'h8A: bitmap = 4'hE;
        8'h8B: bitmap = 4'hC;
        8'h8C: bitmap = 4'hA;
        8'h8D: bitmap = 4'hA;

        // --- 18 (0x12): 'L' ---
        8'h90: bitmap = 4'h8;
        8'h91: bitmap = 4'h8;
        8'h92: bitmap = 4'h8;
        8'h93: bitmap = 4'h8;
        8'h94: bitmap = 4'h8;
        8'h95: bitmap = 4'hE;

        // --- 19 (0x13): 'Y' ---
        8'h98: bitmap = 4'hA;
        8'h99: bitmap = 4'hA;
        8'h9A: bitmap = 4'h6;
        8'h9B: bitmap = 4'h4;
        8'h9C: bitmap = 4'h4;
        8'h9D: bitmap = 4'h4;

        // --- 20 (0x14): 'C' ---
        8'hA0: bitmap = 4'h6;   
        8'hA1: bitmap = 4'h8;   
        8'hA2: bitmap = 4'h8;
        8'hA3: bitmap = 4'h8;
        8'hA4: bitmap = 4'h8;
        8'hA5: bitmap = 4'h6;   

        // --- 21 (0x15): 'S' ---
        8'hA8: bitmap = 4'h6;   
        8'hA9: bitmap = 4'h8;   
        8'hAA: bitmap = 4'h6;   
        8'hAB: bitmap = 4'h1;   
        8'hAC: bitmap = 4'h1;   
        8'hAD: bitmap = 4'hE;   

        // --- 22 (0x16): 'G' ---
        8'hB0: bitmap = 4'h6;   
        8'hB1: bitmap = 4'h8;   
        8'hB2: bitmap = 4'h8;   
        8'hB3: bitmap = 4'hB;   
        8'hB4: bitmap = 4'h9;   
        8'hB5: bitmap = 4'h7;   

        default: bitmap = 4'h0;
    endcase
end

endmodule
