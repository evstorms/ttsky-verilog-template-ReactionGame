module vga_controller (
    input  logic        clk,          // Core clock 25 MHz
    input  logic        rst_n,        // Synchronous reset
    input  logic        clk_1ms,      // 1ms pulse from core_timer
    input  logic [2:0]  disp_mode,    // From Game Controller: display mode encoding
    input  logic [1:0]  lfsr_in,      // From Response Checker: quadrant select
    input  logic [13:0] rxn_time,     // From Core Timer: reaction time in milliseconds
    input  logic [13:0] p1_time,      // From Score Store: stored P1 reaction time
    input  logic        p1_valid,     // From Score Store: stored P1 result validity
    input  logic [1:0]  winner,       // From Score Store: 01=P1, 10=P2, 11=Tie
    input  logic        p2_turn,      // From Game Controller: P2 is currently active
    input  logic        result_valid, // From Game Controller: result is correct
    input  logic        mode_target,  // From top: 0=Classic, 1=Target Match
    input  logic        mode_player,  // From top: 0=1P, 1=2P

    output logic [1:0]  vga_r,        // Red channel (2-bit)
    output logic [1:0]  vga_g,        // Green channel (2-bit)
    output logic [1:0]  vga_b,        // Blue channel (2-bit)
    output logic        vga_hsync,    // Horizontal sync
    output logic        vga_vsync     // Vertical sync
);

// VGA sync generator
logic [9:0] hcount, vcount;
logic active;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        hcount <= '0;
        vcount <= '0;
    end else if (hcount == 10'd799) begin
        hcount <= '0;
        vcount <= (vcount == 10'd524) ? '0 : vcount + 10'd1;
    end else begin
        hcount <= hcount + 10'd1;
    end
end

assign active    = (hcount < 10'd640) && (vcount < 10'd480);
assign vga_hsync = ~((hcount >= 10'd656) && (hcount < 10'd752));
assign vga_vsync = ~((vcount >= 10'd490) && (vcount < 10'd492));

//Region Decode
typedef enum logic [2:0] {
    BACKGROUND  = 3'd0,
    QUAD_TOP    = 3'd1,
    QUAD_LEFT   = 3'd2,
    QUAD_CENTER = 3'd3,
    QUAD_RIGHT  = 3'd4,
    STATUS_BAR  = 3'd5,
    TIME_DISP   = 3'd6
} region_t;

region_t region;

logic [4:0] htile, vtile;
assign htile = hcount[9:5];   
assign vtile = vcount[9:5];   

always_comb begin
    if (!active)
        region = BACKGROUND;
    else if (htile >= 5'd6  && htile < 5'd14 && vtile >= 5'd1  && vtile < 5'd6)
        region = QUAD_TOP;
    else if (htile >= 5'd1  && htile < 5'd6  && vtile >= 5'd6  && vtile < 5'd11)
        region = QUAD_LEFT;
    else if (htile >= 5'd6  && htile < 5'd14 && vtile >= 5'd6  && vtile < 5'd11)
        region = QUAD_CENTER;
    else if (htile >= 5'd14 && htile < 5'd19 && vtile >= 5'd6  && vtile < 5'd11)
        region = QUAD_RIGHT;
    else if (htile >= 5'd1  && htile < 5'd19 && vtile >= 5'd11 && vtile < 5'd13)
        region = STATUS_BAR;
    else if (htile >= 5'd5  && htile < 5'd15 && vtile >= 5'd13 && vtile < 5'd15)
        region = TIME_DISP;
    else
        region = BACKGROUND;
end


logic is_quad_region, is_target_quad;
assign is_quad_region = (region == QUAD_TOP) || (region == QUAD_LEFT) || (region == QUAD_CENTER) || (region == QUAD_RIGHT);
assign is_target_quad = is_quad_region && (~mode_target || (region[1:0] == lfsr_in + 2'd1));

// BCD conversion
function automatic [15:0] bin2bcd(input [13:0] b);
    logic [29:0] scratch; 
    integer      i;
    scratch        = '0;
    scratch[13:0]  = b;
    for (i = 0; i < 14; i++) begin
        if (scratch[17:14] >= 4'd5) scratch[17:14] = scratch[17:14] + 4'd3;
        if (scratch[21:18] >= 4'd5) scratch[21:18] = scratch[21:18] + 4'd3;
        if (scratch[25:22] >= 4'd5) scratch[25:22] = scratch[25:22] + 4'd3;
        if (scratch[29:26] >= 4'd5) scratch[29:26] = scratch[29:26] + 4'd3;
        scratch = scratch << 1;
    end
    bin2bcd = scratch[29:14];
endfunction

// Slow counter for SHOW_WINNER
logic [1:0] phase;
logic [9:0] ms_cnt;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        ms_cnt <= '0;
        phase  <= '0;
    end else if (clk_1ms) begin
        if (ms_cnt == 10'd669) begin
            ms_cnt <= '0;
            phase  <= phase + 2'd1;
        end else begin
            ms_cnt <= ms_cnt + 10'd1;
        end
    end
end

// Shared BCD converter
logic [13:0] bcd_mux_in;
logic [15:0] bcd_disp;
assign bcd_mux_in = (disp_mode == 3'd7 && phase == 2'b00) ? p1_time : rxn_time;
assign bcd_disp   = bin2bcd(bcd_mux_in);

// Digit Display (TIME_DISP region)
logic in_digit_block;
assign in_digit_block = (hcount >= 10'd280) && (hcount < 10'd360) &&
                        (vcount >= 10'd436) && (vcount < 10'd460);

logic [1:0] digit_slot;       // 0=thousands … 3=ones
logic [9:0] digit_slot_start; // pixel x of current slot's left edge
logic [9:0] digit_col_offset; // 0–19 within current slot
logic [2:0] digit_col;        // 0–3 = font column, 4 = gap
logic [2:0] digit_row;        // 0–5 font row
logic [3:0] digit_char_4b;    // raw BCD nibble
logic [4:0] dig_char_5b;      // character index sent to font_rom
logic [3:0] dig_bitmap;
logic       dig_pixel;

always_comb begin
    digit_slot       = 2'd0;
    digit_slot_start = 10'd280;
    digit_char_4b    = 4'd0;
    dig_char_5b      = 5'd31; // blank

    if      (hcount < 10'd300) begin digit_slot = 2'd0; digit_slot_start = 10'd280; end
    else if (hcount < 10'd320) begin digit_slot = 2'd1; digit_slot_start = 10'd300; end
    else if (hcount < 10'd340) begin digit_slot = 2'd2; digit_slot_start = 10'd320; end
    else                       begin digit_slot = 2'd3; digit_slot_start = 10'd340; end

    digit_col_offset = hcount - digit_slot_start; // 0–19
    digit_col        = digit_col_offset[4:2];      // >>2: 0-3=char, 4=gap
    digit_row        = (vcount - 10'd436) >> 2;    // 0–5 (truncated to [2:0])

    // Select BCD nibble (MSB = thousands)
    case (digit_slot)
        2'd0:    digit_char_4b = bcd_disp[15:12]; // thousands
        2'd1:    digit_char_4b = bcd_disp[11:8];  // hundreds
        2'd2:    digit_char_4b = bcd_disp[7:4];   // tens
        default: digit_char_4b = bcd_disp[3:0];   // ones
    endcase

    // Leading zero suppression
    if (digit_col >= 3'd4) begin
        dig_char_5b = 5'd31; // gap → blank
    end else if (digit_slot == 2'd0 && bcd_disp[15:12] == 4'd0) begin
        dig_char_5b = 5'd31; // suppress leading thousands
    end else if (digit_slot == 2'd1 && bcd_disp[15:8] == 8'd0) begin
        dig_char_5b = 5'd31; // suppress hundreds when thousands also 0
    end else begin
        dig_char_5b = {1'b0, digit_char_4b}; // digit char index 0–9
    end
end

font_rom dig_rom (
    .char   (dig_char_5b),
    .row    (digit_row[2:0]),
    .bitmap (dig_bitmap)
);

assign dig_pixel = (digit_col < 3'd4) && dig_bitmap[3 - digit_col[1:0]];

// Status Text (STATUS_BAR region)
logic in_stat_block;
assign in_stat_block = (hcount >= 10'd250) && (hcount < 10'd390) &&
                       (vcount >= 10'd364) && (vcount < 10'd388);

logic [2:0] stat_slot;        // character slot 0–6
logic [9:0] stat_slot_start;  // pixel x of current slot's left edge
logic [9:0] stat_col_offset;  // 0–19 within current slot
logic [2:0] stat_col;         // 0–3 = font column, 4 = gap
logic [2:0] stat_row;         // 0–5 font row
logic [4:0] stat_char_5b;     // character index to font_rom
logic [3:0] stat_bitmap;
logic       stat_pixel;

always_comb begin
    stat_slot       = 3'd6;
    stat_slot_start = 10'd370;
    if      (hcount < 10'd270) begin stat_slot = 3'd0; stat_slot_start = 10'd250; end
    else if (hcount < 10'd290) begin stat_slot = 3'd1; stat_slot_start = 10'd270; end
    else if (hcount < 10'd310) begin stat_slot = 3'd2; stat_slot_start = 10'd290; end
    else if (hcount < 10'd330) begin stat_slot = 3'd3; stat_slot_start = 10'd310; end
    else if (hcount < 10'd350) begin stat_slot = 3'd4; stat_slot_start = 10'd330; end
    else if (hcount < 10'd370) begin stat_slot = 3'd5; stat_slot_start = 10'd350; end

    stat_col_offset = hcount - stat_slot_start; // 0–19
    stat_col        = stat_col_offset[4:2];      // 0-3=char, 4=gap
    stat_row        = (vcount - 10'd364) >> 2;   // 0–5 (truncated to [2:0])
end

// String ROM: char indices 0-9='0'-'9', 10=P, 11=T, 12=I, 13=E,
//             14=W, 15=N, 16=A, 17=R, 18=L, 19=Y, 31=blank
function automatic [4:0] str_rom_f(input [2:0] mode, input [2:0] slot);
    case ({mode, slot})
        {3'd0,3'd0}: str_rom_f=5'd10; {3'd0,3'd1}: str_rom_f=5'd1;  // P1 PLAY
        {3'd0,3'd2}: str_rom_f=5'd31; {3'd0,3'd3}: str_rom_f=5'd10;
        {3'd0,3'd4}: str_rom_f=5'd18; {3'd0,3'd5}: str_rom_f=5'd16;
        {3'd0,3'd6}: str_rom_f=5'd19;
        {3'd5,3'd0}: str_rom_f=5'd31; {3'd5,3'd1}: str_rom_f=5'd13; // EARLY (+1 blank)
        {3'd5,3'd2}: str_rom_f=5'd16; {3'd5,3'd3}: str_rom_f=5'd17;
        {3'd5,3'd4}: str_rom_f=5'd18; {3'd5,3'd5}: str_rom_f=5'd19;
        {3'd6,3'd0}: str_rom_f=5'd10; {3'd6,3'd1}: str_rom_f=5'd2;  // P2 PLAY
        {3'd6,3'd2}: str_rom_f=5'd31; {3'd6,3'd3}: str_rom_f=5'd10;
        {3'd6,3'd4}: str_rom_f=5'd18; {3'd6,3'd5}: str_rom_f=5'd16;
        {3'd6,3'd6}: str_rom_f=5'd19;
        default:     str_rom_f=5'd31;
    endcase
endfunction

function automatic [4:0] win_rom_f(input [1:0] win, input [2:0] slot);
    case ({win, slot})
        {2'b01,3'd0}: win_rom_f=5'd31; {2'b01,3'd1}: win_rom_f=5'd10; // P1 WIN (+1 blank)
        {2'b01,3'd2}: win_rom_f=5'd1;  {2'b01,3'd3}: win_rom_f=5'd31;
        {2'b01,3'd4}: win_rom_f=5'd14; {2'b01,3'd5}: win_rom_f=5'd12;
        {2'b01,3'd6}: win_rom_f=5'd15;
        {2'b10,3'd0}: win_rom_f=5'd31; {2'b10,3'd1}: win_rom_f=5'd10; // P2 WIN (+1 blank)
        {2'b10,3'd2}: win_rom_f=5'd2;  {2'b10,3'd3}: win_rom_f=5'd31;
        {2'b10,3'd4}: win_rom_f=5'd14; {2'b10,3'd5}: win_rom_f=5'd12;
        {2'b10,3'd6}: win_rom_f=5'd15;
        {2'b11,3'd0}: win_rom_f=5'd31; {2'b11,3'd1}: win_rom_f=5'd31; // TIE (+2 blanks)
        {2'b11,3'd2}: win_rom_f=5'd11; {2'b11,3'd3}: win_rom_f=5'd12;
        {2'b11,3'd4}: win_rom_f=5'd13;
        default:      win_rom_f=5'd31;
    endcase
endfunction

always_comb begin
    stat_char_5b = 5'd31;
    if (in_stat_block && stat_col < 3'd4) begin
        if (disp_mode == 3'd7 && phase >= 2'b10)
            stat_char_5b = win_rom_f(winner, stat_slot);
        else
            stat_char_5b = str_rom_f(disp_mode, stat_slot);
    end
end

font_rom stat_rom (
    .char   (stat_char_5b),
    .row    (stat_row[2:0]),
    .bitmap (stat_bitmap)
);

assign stat_pixel = (stat_col < 3'd4) && stat_bitmap[3 - stat_col[1:0]];

// Info Panels
logic in_mode_block, in_player_block;
assign in_mode_block   = (hcount >= 10'd26)  && (hcount < 10'd166) &&
                         (vcount >= 10'd100) && (vcount < 10'd124);
assign in_player_block = (hcount >= 10'd524) && (hcount < 10'd564) &&
                         (vcount >= 10'd100) && (vcount < 10'd124);

// --- Mode label (left panel) ---
logic [2:0] mode_slot;
logic [9:0] mode_slot_start;
logic [9:0] mode_col_offset;
logic [2:0] mode_col, mode_row;
logic [4:0] mode_char_5b;
logic [3:0] mode_bitmap;
logic       mode_pixel;

always_comb begin
    mode_slot       = 3'd6;
    mode_slot_start = 10'd146;
    if      (hcount < 10'd46)  begin mode_slot = 3'd0; mode_slot_start = 10'd26;  end
    else if (hcount < 10'd66)  begin mode_slot = 3'd1; mode_slot_start = 10'd46;  end
    else if (hcount < 10'd86)  begin mode_slot = 3'd2; mode_slot_start = 10'd66;  end
    else if (hcount < 10'd106) begin mode_slot = 3'd3; mode_slot_start = 10'd86;  end
    else if (hcount < 10'd126) begin mode_slot = 3'd4; mode_slot_start = 10'd106; end
    else if (hcount < 10'd146) begin mode_slot = 3'd5; mode_slot_start = 10'd126; end

    mode_col_offset = hcount - mode_slot_start;
    mode_col        = mode_col_offset[4:2];
    mode_row        = (vcount - 10'd100) >> 2;

    mode_char_5b = 5'd31;
    if (in_mode_block && mode_col < 3'd4) begin
        if (!mode_target) begin
            case (mode_slot) // C L A S S I C
                3'd0: mode_char_5b = 5'd20;
                3'd1: mode_char_5b = 5'd18;
                3'd2: mode_char_5b = 5'd16;
                3'd3: mode_char_5b = 5'd21;
                3'd4: mode_char_5b = 5'd21;
                3'd5: mode_char_5b = 5'd12;
                3'd6: mode_char_5b = 5'd20;
            endcase
        end else begin
            case (mode_slot) // (blank) T A R G E T
                3'd0: mode_char_5b = 5'd31;
                3'd1: mode_char_5b = 5'd11;
                3'd2: mode_char_5b = 5'd16;
                3'd3: mode_char_5b = 5'd17;
                3'd4: mode_char_5b = 5'd22;
                3'd5: mode_char_5b = 5'd13;
                3'd6: mode_char_5b = 5'd11;
            endcase
        end
    end
end

font_rom mode_rom (
    .char   (mode_char_5b),
    .row    (mode_row[2:0]),
    .bitmap (mode_bitmap)
);
assign mode_pixel = (mode_col < 3'd4) && mode_bitmap[3 - mode_col[1:0]];

// --- Player label (right panel) ---
logic [9:0] player_slot_start;
logic [9:0] player_col_offset;
logic [2:0] player_col, player_row;
logic [4:0] player_char_5b;
logic [3:0] player_bitmap;
logic       player_pixel;

always_comb begin
    player_slot_start = (hcount < 10'd544) ? 10'd524 : 10'd544;

    player_col_offset = hcount - player_slot_start;
    player_col        = player_col_offset[4:2];
    player_row        = (vcount - 10'd100) >> 2;

    player_char_5b = 5'd31;
    if (in_player_block && player_col < 3'd4) begin
        // slot 0 (hcount<544) = '1'/'2', slot 1 = 'P'
        if (hcount < 10'd544)
            player_char_5b = mode_player ? 5'd2 : 5'd1;
        else
            player_char_5b = 5'd10; // P
    end
end

font_rom player_rom (
    .char   (player_char_5b),
    .row    (player_row[2:0]),
    .bitmap (player_bitmap)
);
assign player_pixel = (player_col < 3'd4) && player_bitmap[3 - player_col[1:0]];

// ============================================================
// 6. Pixel Color Mux
//    6-bit color: {R[1:0], G[1:0], B[1:0]}
// ============================================================
localparam [5:0] COL_BLACK       = 6'b00_00_00;
localparam [5:0] COL_DARK_GRAY  = 6'b01_01_01;
localparam [5:0] COL_MEDIUM_GRAY = 6'b10_10_10;
localparam [5:0] COL_WHITE       = 6'b11_11_11;
localparam [5:0] COL_RED         = 6'b11_00_00;
localparam [5:0] COL_GREEN       = 6'b00_11_00;
localparam [5:0] COL_YELLOW      = 6'b11_11_00;

// 2-pixel white border around each quad (pixel-level boundary check)
// Quad pixel ranges (shifted +32 vertically to center content):
//   TOP    h=[192,448) v=[32,192)   LEFT  h=[32,192)  v=[192,352)
//   CENTER h=[192,448) v=[192,352)  RIGHT h=[448,608) v=[192,352)
logic is_quad_border;
always_comb begin
    is_quad_border = 1'b0;
    case (region)
        QUAD_TOP:    is_quad_border = (hcount < 194) || (hcount >= 446) ||
                                      (vcount <  34) || (vcount >= 190);
        QUAD_LEFT:   is_quad_border = (hcount <  34) || (hcount >= 190) ||
                                      (vcount < 194) || (vcount >= 350);
        QUAD_CENTER: is_quad_border = (hcount < 194) || (hcount >= 446) ||
                                      (vcount < 194) || (vcount >= 350);
        QUAD_RIGHT:  is_quad_border = (hcount < 450) || (hcount >= 606) ||
                                      (vcount < 194) || (vcount >= 350);
        default:     is_quad_border = 1'b0;
    endcase
end

logic is_target_border;
assign is_target_border = is_quad_border && (disp_mode == 3'd2) && is_target_quad;

logic [5:0] pixel_color;

always_comb begin
    pixel_color = COL_BLACK; // default: inactive or background

    if (active) begin
        case (region)
            QUAD_TOP, QUAD_LEFT, QUAD_CENTER, QUAD_RIGHT: begin
                if (is_quad_border) begin
                    pixel_color = is_target_border ? COL_YELLOW : COL_WHITE;
                end else begin
                    case (disp_mode)
                        3'd0:    pixel_color = COL_MEDIUM_GRAY;           // IDLE: quads
                        3'd1:    pixel_color = COL_BLACK;                 // WAIT_RANDOM: black
                        3'd2:    pixel_color = is_target_quad ? COL_GREEN // STIMULUS: target green
                                                              : COL_MEDIUM_GRAY;
                        3'd4:    pixel_color = COL_MEDIUM_GRAY;           // RESULT_ERR: quads
                        3'd5:    pixel_color = COL_RED;                   // FALSE_START: all red
                        default: pixel_color = COL_MEDIUM_GRAY;
                    endcase
                end
            end

            TIME_DISP: begin
                if (in_digit_block && dig_pixel) begin
                    case (disp_mode)
                        3'd2, 3'd3: pixel_color = COL_GREEN; // valid result
                        3'd4:       pixel_color = COL_RED;   // false-start error
                        3'd7:       pixel_color = COL_WHITE; // winner display
                        default:    pixel_color = COL_GREEN;
                    endcase
                end else begin
                    pixel_color = COL_BLACK;
                end
            end

            STATUS_BAR: begin
                if (stat_pixel) begin
                    case (disp_mode)
                        3'd0, 3'd6: pixel_color = COL_GREEN;  // P1/P2 PLAY
                        3'd5:       pixel_color = COL_RED;    // EARLY
                        3'd7:       pixel_color = COL_WHITE;  // winner display
                        default:    pixel_color = COL_WHITE;
                    endcase
                end else begin
                    pixel_color = COL_BLACK;
                end
            end

            default: begin // BACKGROUND
                if      (in_mode_block   && mode_pixel)   pixel_color = COL_WHITE;
                else if (in_player_block && player_pixel) pixel_color = COL_WHITE;
                else                                       pixel_color = COL_BLACK;
            end
        endcase
    end
end

assign {vga_r, vga_g, vga_b} = pixel_color;

endmodule
