# SystemVerilog Fixed-Point NPU (MNIST Accelerator)

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![ASIC-Flow](https://img.shields.io/badge/Flow-ASIC%20Design-green.svg)]()
[![Backend-Ready](https://img.shields.io/badge/Status-GDSII%20Ready-orange.svg)]()

This repository features a **refactored, high-performance NPU (Neural Processing Unit)** for MNIST digit recognition. The primary goal of this project was to leverage modern **SystemVerilog** features to enhance code modularity, readability, and hardware efficiency compared to traditional HDL implementations.

## 🎨 Physical Implementation Showcase

The logic implemented in SystemVerilog has been fully validated through a complete RTL-to-GDSII flow using **Cadence Innovus**. 

<p align="center">
  <img src="https://github.com/user-attachments/assets/35d83fc6-dd9d-4fc9-8118-a104b72f59bf" width="600" title="ASIC Layout View">
  <br>
  <i>Final GDSII Layout: Realized from SystemVerilog RTL</i>
</p>

## 🛠 SystemVerilog Modernization Highlights

This refactored version moves away from flat port lists to a highly modular architecture:

- **Hardware Modularity**: Extensively used **Interfaces** and **Structs** to encapsulate complex signals, drastically reducing wiring errors and top-level clutter.
- **Architectural Enhancements**:
  - **4-Layer MLP Architecture**: 784 (Input) → 30 → 30 → 10 → 10 (Output).
  - **Precision**: Q1.15 fixed-point arithmetic with saturating logic to prevent numerical overflow.
  - **Activations**: High-speed LUT-based Sigmoid function implementation.
- **Memory Subsystem**: BRAM-friendly memory organization for efficient weight and activation management.

## 📊 Performance & Sign-off Metrics

Based on the Cadence Innovus backend flow, the design achieved aggressive timing closure:

| Category | Result |
| --- | --- |
| **Technology Node** | 45 nm |
| **Cell Count** | ~248,000 cells |
| **Core Area** | ~358,800 μm² |
| **Clock Frequency** | 100 MHz (Design) / **~238 MHz (Post-Route Max)** |
| **Timing Margin** | WNS: 5.80 ns (2.3x performance margin) |
| **Physical Integrity**| 0 DRC / Antenna Violations |

## 📂 Repository Structure

- `SystemVerilog_NPU/`: Core RTL source code using modern SystemVerilog constructs.
- `Synthesis/`: Logic synthesis scripts (Cadence Genus) and gate-level netlists.
- `backend/`: Physical design database (Innovus), including Floorplan, CTS, and Routing files.

---
© 2026 Wei-In Lai. All rights reserved.
