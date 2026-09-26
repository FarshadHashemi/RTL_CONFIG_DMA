# config_DMA

A VHDL AXI4-Lite DMA configuration controller for Xilinx AXI DMA IP. It receives a start command over an AXI4-Stream slave port, programs the DMA's S2MM (receive) or MM2S (transmit) registers over AXI4-Lite, triggers the transfer, waits for completion, and repeats until the programmed address reaches the requested total length.

---

## Overview

The module sits between a higher-level controller (which issues start commands) and the Xilinx AXI DMA IP's configuration interface. It:

1. Accepts a 40-bit configuration word on an AXI4-Stream slave port.
2. Reads the direction bit to decide between **S2MM** (device → memory) and **MM2S** (memory → device).
3. Programs the DMA's `DMASR`, address, `DMACR`, and `LENGTH` registers over AXI4-Lite, one write at a time.
4. Pulses the `m_axis_start` output to launch the transfer.
5. Waits for the corresponding interrupt (`s2mm_interrupt` or `mm2s_interrupt`).
6. Advances the source/destination address by a fixed packet size and repeats until the total programmed length is reached.
