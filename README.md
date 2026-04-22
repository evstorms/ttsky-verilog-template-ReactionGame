# Reaction Time Game — tt_um_peterhan_ReactionGame

A multiplayer reaction time game with VGA display output, implemented in SystemVerilog for Tiny Tapeout Sky26a.

[Full documentation](docs/info.md)

## Overview

Players press a button as quickly as possible after a stimulus appears on screen. The design supports two game modes and one or two players:

- **Classic Mode**: Any button press after the stimulus is valid.
- **Target Match Mode**: Only the button matching the highlighted quadrant scores — wrong button counts as a loss.
- **1-Player**: Single round with reaction time displayed in milliseconds.
- **2-Player**: P1 and P2 each play a round; the faster (valid) player wins. A winner screen cycles through both times before announcing the result.

## External Hardware

- VGA monitor (640×480 @ 60 Hz)
- VGA resistor DAC (270 Ω / 560 Ω per channel)
- 5 momentary buttons + 2 mode switches
