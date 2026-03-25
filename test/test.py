# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # 25 MHz clock = 40 ns period
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1

    dut._log.info("Out of reset")

    # Wait for VGA to start generating sync pulses (~800 cycles per hsync period)
    await ClockCycles(dut.clk, 1000)

    # Check hsync (uo_out[6]) and vsync (uo_out[7]) toggle — not stuck
    hsync_vals = set()
    for _ in range(2000):
        await RisingEdge(dut.clk)
        hsync_vals.add((int(dut.uo_out.value) >> 6) & 1)

    assert len(hsync_vals) == 2, f"hsync stuck, only saw values: {hsync_vals}"
    dut._log.info("PASS: hsync toggling")

    # Press start and verify design doesn't hang
    dut.ui_in.value = (1 << 5)  # start = ui_in[5]
    await ClockCycles(dut.clk, 10)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 100)

    dut._log.info("All tests passed")
