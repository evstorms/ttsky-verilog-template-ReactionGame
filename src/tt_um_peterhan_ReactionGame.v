/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_peterhan_ReactionGame (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock (25 MHz)
    input  wire       rst_n     // reset_n - low to reset
);

  wire [1:0] vga_r, vga_g, vga_b;
  wire       vga_hsync, vga_vsync;

  top u_top (
    .clk         (clk),
    .rst_btn     (~rst_n),       // TT rst_n is active-low; top expects active-high rst_btn
    .button_0    (ui_in[1]),
    .button_1    (ui_in[2]),
    .button_2    (ui_in[3]),
    .button_3    (ui_in[4]),
    .start       (ui_in[5]),
    .mode_game   (ui_in[6]),
    .mode_player (ui_in[7]),
    .vga_r       (vga_r),
    .vga_g       (vga_g),
    .vga_b       (vga_b),
    .vga_hsync   (vga_hsync),
    .vga_vsync   (vga_vsync)
  );

  // uo_out: VGA signals
  assign uo_out  = {vga_vsync, vga_hsync, vga_b, vga_g, vga_r};

  // uio unused
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  // Suppress unused input warnings
  wire _unused = &{ena, uio_in, ui_in[0], 1'b0};

endmodule
