# Llama 3.2 1B Int4 Quantization Model - Weekly Report

## 1. Progress: Model Download

✅ **Downloaded Model**: `unsloth/Llama-3.2-1B-Instruct-bnb-4bit`
- 📊 File Size: ~1.03 GB
- 🔢 Parameters: 1 Billion (1B)
- 🎯 Precision: 4-bit quantization

---

## 2. C Reference Code Status

### Available Resource: runq.c

The project includes an **int8 quantization** reference implementation `runq.c` (~1,200 lines of pure C code), but it **does not support int4 version**.

### Quantization Precision Comparison

| Precision | Weight Size (1B Model) | Quantization Range | Notes |
|-----------|------------------------|-------------------|-------|
| int8 | 1.06 GB | -128 ~ 127 | Already implemented in runq.c |
| **int4** | **0.53 GB** | **-8 ~ 7** | **Requires code modification** |

To implement int4, modifications to quantization formulas and bit-packing logic in runq.c are needed.

---

## 3. Int4 Quantization Principles

### 3.1 Quantization Formulas

**Forward Quantization**:
```
1. Find maximum absolute value in each group:
   wmax = max(|w₁|, |w₂|, ..., |w₁₂₈|)

2. Calculate scaling factor:
   scale = wmax / 7.0    (int4 range: -8~7)

3. Quantize:
   int4_value = round(float_value / scale)
```

**Dequantization**:
```
float_value = int4_value × scale
```

**Important**: After dequantization, values are converted to **float32** for computation because:
- GPU/CPU matrix operations require floating-point numbers
- int4 is only used for **storage** to save memory
- Computation **must use float32**

### 3.2 Example

Given a weight group: `[0.1, 0.5, 1.2, 2.8, -0.3]`

```
wmax = 2.8
scale = 2.8 / 7 = 0.4

Quantization:
  0.1  → round(0.1/0.4) = 0
  0.5  → round(0.5/0.4) = 1
  1.2  → round(1.2/0.4) = 3
  2.8  → round(2.8/0.4) = 7
 -0.3  → round(-0.3/0.4) = -1

Storage: [0, 1, 3, 7, -1] + scale(0.4)

Dequantization:
  0 × 0.4 = 0.0   (error: 0.1)
  1 × 0.4 = 0.4   (error: 0.1)
  3 × 0.4 = 1.2   (error: 0.0)
  7 × 0.4 = 2.8   (error: 0.0)
 -1 × 0.4 = -0.4  (error: 0.1)
```

### 3.3 Bit Packing

Int4 requires packing 2 values into 1 byte:
```c
uint8_t packed = (val1 & 0x0F) | ((val2 & 0x0F) << 4);
```

### 3.4 NF4 vs Traditional Int4 Comparison

**Traditional Int4**: Uses 16 **uniformly spaced** values (-8 to 7), scaled by a single factor.

**NF4 (NormalFloat 4-bit)**: Uses 16 **non-uniformly spaced** values from a lookup table, optimized for normally-distributed weights (more values near 0, fewer at extremes).

#### Lookup Table Comparison

```
Traditional Int4 (after scaling by absmax/7):
  indices: -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7
  → uniformly spaced

NF4 (approximate normalized values from quant_map):
  indices:  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
  values: -1.0, -0.69, -0.52, -0.39, -0.28, -0.18, -0.09, -0.03,
           0.03,  0.09,  0.18,  0.28,  0.39,  0.52,  0.69,  1.0
  → denser near 0, sparser at extremes
```

#### Example: Same Weights `[0.1, 0.5, 1.2, 2.8, -0.3]`

```
absmax = 2.8

=== Traditional Int4 ===
Normalize:     0.1/2.8=0.036   0.5/2.8=0.179   1.2/2.8=0.429   2.8/2.8=1.0   -0.3/2.8=-0.107
Scale to -8~7: ×7 → 0.25       1.25             3.0              7.0           -0.75
Round:              0            1                3                7             -1
Dequant:       0×0.4=0.0       1×0.4=0.4        3×0.4=1.2        7×0.4=2.8     -1×0.4=-0.4
Error:              0.1          0.1              0.0              0.0            0.1

=== NF4 ===
Normalize:     0.036            0.179            0.429            1.0           -0.107
Find nearest:  0.03(idx=7)      0.18(idx=9)      0.39(idx=12)     1.0(idx=15)   -0.09(idx=6)
Dequant:       0.03×2.8=0.084   0.18×2.8=0.504   0.39×2.8=1.092   1.0×2.8=2.8  -0.09×2.8=-0.252
Error:              0.016        0.004            0.108            0.0            0.048
```

#### Error Comparison

| Weight | Int4 Error | NF4 Error | Winner |
|--------|-----------|-----------|--------|
| 0.1    | 0.100     | **0.016** | NF4 |
| 0.5    | 0.100     | **0.004** | NF4 |
| 1.2    | **0.000** | 0.108     | Int4 |
| 2.8    | 0.000     | 0.000     | Tie |
| -0.3   | 0.100     | **0.048** | NF4 |

> [!NOTE]
> NF4 wins on **small values near 0** (which are the majority in neural networks), while Int4 can be more accurate for values that happen to land on its uniform grid. Overall, NF4 produces lower average error for normally-distributed weights.

---

## 4. Memory Analysis (1GB DDR4 Constraint)

### 4.1 Model Parameters (Verified from Safetensors)

**Actual parameter breakdown** (inspected from `model.safetensors`):

| Component | Parameters | Percentage |
|-----------|-----------|------------|
| Embedding (`embed_tokens`) | 128,256 × 2,048 = 262,668,288 | 21.3% |
| 16 Transformer Layers | 973,144,064 | 78.7% |
| Final LayerNorm | 2,048 | ~0% |
| **Total** | **1,235,814,400 (1.236B)** | **100%** |

> [!IMPORTANT]
> `tie_word_embeddings = true` in config.json — `lm_head` and `embed_tokens` **share the same weights**. No separate `lm_head` tensor exists in the safetensors file.

> [!WARNING]
> The current bnb-4bit model stores embedding in **bfloat16** (0.525 GB, NOT quantized). Only linear layers are quantized to nf4.

### 4.2 Baseline Memory Breakdown

#### On-Disk (Safetensors As-Is)

| Category | Format | Contents | Size |
|----------|--------|----------|------|
| Embedding | bfloat16 | `embed_tokens` (128,256 × 2,048) | 0.525 GB |
| LayerNorms | bfloat16 | 32 × `layernorm` + `model.norm` | 0.0001 GB |
| Linear weights | nf4 (4-bit) | `q/k/v/o_proj`, `gate/up/down_proj` × 16 layers | 0.486 GB |
| Quant metadata | mixed | `quant_map`, `absmax`, `nested_absmax`, `quant_state` | 0.016 GB |
| **Total on-disk** | | | **1.028 GB** |

#### Runtime (Additional Memory Needed for Inference)

| Category | Formula | Size |
|----------|---------|------|
| Activation buffers | Reusable vectors (dim=2048, intermediate=8192) | ~1 MB |
| Logits | vocab_size × 4 bytes = 128,256 × 4 | 0.5 MB |
| KV Cache (seq_len=128) | 16 × 2 × 128 × 512 × 4 | 0.008 GB |
| KV Cache (seq_len=256) | 16 × 2 × 256 × 512 × 4 | 0.017 GB |
| KV Cache (seq_len=512) | 16 × 2 × 512 × 512 × 4 | 0.034 GB |
| KV Cache (seq_len=2048) | 16 × 2 × 2048 × 512 × 4 | 0.134 GB |
| System overhead | OS kernel + drivers + tokenizer | ~0.25 GB |

> [!NOTE]
> KV Cache uses `kv_dim = 512` (not 2048) because of **GQA**: `num_key_value_heads = 8` × `head_dim = 64` = 512.

> [!NOTE]
> **NF4 Dequantization** (required at inference — computation must use float):
> ```
> 1. Unpack: each uint8 byte contains 2 × 4-bit indices (0~15)
> 2. Lookup: quant_map[4bit_index] → normalized float value
> 3. Scale:  float_value = quant_map[index] × absmax[group_id]
> ```

### 4.3 FPGA Deployment Scenarios (1 GB DDR4 Constraint)

#### Scenario A: All weights quantized to int4 (including embedding)

Re-quantize everything to uniform int4 for FPGA, discarding the bnb nf4 format:
```
All weights:   1.236B × 4 bits / 8 = 0.618 GB
Scale factors: (1.236B / 128) × 4  ≈ 0.04  GB
Total weights:                      ≈ 0.66  GB
```

| seq_len | Weights | KV Cache | Act. + Logits | System | **Total** | Feasibility |
|---------|---------|----------|---------------|--------|-----------|-------------|
| 512 | 0.66 GB | 0.034 GB | 0.002 GB | 0.25 GB | **0.95 GB** | ✅ Fits |
| 256 | 0.66 GB | 0.017 GB | 0.002 GB | 0.25 GB | **0.93 GB** | ✅ Fits |
| 128 | 0.66 GB | 0.008 GB | 0.002 GB | 0.25 GB | **0.92 GB** | ✅ Fits |

#### Scenario B: Embedding in bfloat16, linear weights in int4

Keep embedding as-is from safetensors (simpler, no re-quantization of embedding):
```
Embedding (bfloat16): 262M × 2 bytes       = 0.525 GB
Linear weights (int4): 973M × 4/8 + scale  ≈ 0.52  GB
Total weights:                              ≈ 1.04  GB  ← already exceeds 1 GB!
```

| seq_len | Weights | KV Cache | Act. + Logits | System | **Total** | Feasibility |
|---------|---------|----------|---------------|--------|-----------|-------------|
| 256 | 1.04 GB | 0.017 GB | 0.002 GB | 0.25 GB | **1.31 GB** | ❌ Exceeds |

---

## 5. 💡 Conclusions and Recommendations

### ✅ Key Corrections from Safetensors Verification

1. **Embedding is part of model weights** — the original report double-counted it as a separate 1.0 GB item
2. **KV cache was 4× overestimated** — `kv_dim = 512` (GQA), not 2048
3. **Activations were overestimated** — token-by-token inference only needs ~1 MB, not 50-100 MB

### 📊 Updated Feasibility

**Scenario A (all int4 including embedding)**:
- seq_len=512: Total **~0.95 GB** → ✅ **Fits in 1 GB DDR4!**
- Headroom is tight (~50 MB), careful memory management required

**Scenario B (embedding in bfloat16)**:
- Total **~1.04-1.3 GB** → ❌ Exceeds 1 GB limit
- Would require 2 GB DDR4 upgrade

### Recommended Path Forward

1. **Primary approach**: Implement int4 quantization for **ALL** weights including embedding
   - Requires custom int4 embedding lookup in C code
   - With seq_len=512, total memory fits within 1 GB
   - Tight margin (~50 MB headroom) — careful memory management required

2. **Fallback**: If int4 embedding is too complex to implement, upgrade to 2 GB DDR4 board

---

## 6. Systolic Array Research for Hardware Acceleration

### 6.1 Background and Motivation

In an LLM inference pipeline, **over 90% of computation** is matrix multiplication (GEMM).
To accelerate this on FPGA, we investigated **Systolic Array** architectures — the same core design used in Google's TPU.

### 6.2 Systolic Array Core Concepts

**What is a Systolic Array?**

A Systolic Array is a 2D grid of Processing Elements (PEs) where data flows rhythmically through the array — like blood pumping through a circulatory system — synchronized to the clock.

**Processing Element (PE):**
Each PE performs one simple operation per clock cycle — **MAC (Multiply-Accumulate)**:
```
output = input * weight + partial_sum
```

**Data Reuse — The Key Advantage:**
In a traditional processor, every multiply requires fetching data from memory. In a Systolic Array, data is read from memory **once** and then passed through multiple PEs in sequence, being reused at each step. This dramatically reduces memory bandwidth requirements.

**Weight Stationary Dataflow:**
In this common dataflow strategy (used in Google TPU and Gemmini):
- **Weights** are pre-loaded into PEs and remain **stationary** (fixed in place)
- **Input activations** flow horizontally (left to right)
- **Partial sums** flow vertically (top to bottom), accumulating results

This is optimal for neural network inference because weights are fixed after training.

**Tiling — Handling Large Matrices:**
Real model matrices (e.g., 4096 x 4096) are far larger than the physical array (e.g., 16 x 16 PEs). The solution is **tiling**: partitioning large matrices into small blocks that fit the array, processing them sequentially. A fast on-chip **Scratchpad Memory (SRAM)** buffers these tiles to minimize slow DRAM access.

When a tile does not evenly divide the matrix, the remainder is **zero-padded** to fill the array. Since `x * 0 = 0`, the padded PEs produce no effect on the result.

### 6.3 Open-Source Platform: UCB Gemmini

**Repository**: [ucb-bar/gemmini](https://github.com/ucb-bar/gemmini)

Gemmini is a **hardware generator** developed at UC Berkeley. It is one of the most widely used academic Systolic Array accelerator platforms.

**Key characteristics:**
- Written in **Chisel** (a hardware construction language based on Scala)
- **Not HLS** — Chisel describes hardware structure directly (like Verilog), but with parameterizable templates
- Generates synthesizable **Verilog/SystemVerilog** from configurable parameters
- Operates as a **co-processor** attached to a RISC-V CPU via the RoCC interface

**Core source files** (in `src/main/scala/gemmini/`):

| File | Role |
|------|------|
| `PE.scala` | Single Processing Element — implements MAC with Weight Stationary / Output Stationary dataflow |
| `Mesh.scala` | Connects PEs into a 2D systolic grid, handles data routing |
| `Gemmini.scala` | Top-level controller — manages Scratchpad, tiling, DMA, and CPU interface |

**PE.scala code walkthrough** — the MAC unit:
```scala
// Core MAC operation: out_d = in_c + (in_a * in_b)
io.out_d := io.in_c.mac(io.in_a, io.in_b)
```

In Weight Stationary mode, the PE behavior is:
```scala
// Weight (c2) stays fixed in register
// Input (a) arrives from left neighbor
// Partial sum (b) arrives from top neighbor
// Result = a * weight + partial_sum -> sent to bottom neighbor (out_b)
mac_unit.io.in_b := c2.asTypeOf(weightType)   // use stored weight
mac_unit.io.in_c := b                          // add incoming partial sum
io.out_b := mac_unit.io.out_d                  // pass result downward
```

### 6.4 SW/HW Task Partitioning for Llama 3.2

Based on our analysis, the following partitioning is proposed for FPGA deployment:

#### ARM CPU (SoC on FPGA) — Control and Irregular Ops

| Task | Reason |
|------|--------|
| Tokenizer (string to token IDs) | Complex string logic, lookup tables |
| Embedding lookup (token ID to vector) | Simple table lookup, small computation |
| RMSNorm | Requires square root, division |
| RoPE (Rotary Position Encoding) | Requires trigonometric functions |
| Softmax | Requires exponentiation, division |
| SiLU activation | Requires exponentiation |
| Flow control | Orchestrating layer-by-layer execution |

#### FPGA Systolic Array — Massive Regular GEMM

| Task | Matrix Dimensions (1B model) |
|------|------------------------------|
| Q/K/V Projections | (seq_len, 2048) x (2048, 2048/256/256) |
| Attention Score (Q * K^T) | (seq_len, 64) x (64, seq_len) per head |
| Attention Output (Score * V) | (seq_len, seq_len) x (seq_len, 64) per head |
| Output Projection | (seq_len, 2048) x (2048, 2048) |
| FFN Gate Projection | (seq_len, 2048) x (2048, 8192) |
| FFN Up Projection | (seq_len, 2048) x (2048, 8192) |
| FFN Down Projection | (seq_len, 8192) x (8192, 2048) |

> [!NOTE]
> The Systolic Array handles **all linear layer multiplications**, which account for over 90% of total computation in the Transformer architecture.

### 6.5 Gemmini Build Environment

Gemmini requires the **Chipyard** framework to generate Verilog output:

```bash
# Clone Chipyard (~20-25 GB total after setup)
git clone https://github.com/ucb-bar/chipyard.git
cd chipyard
./build-setup.sh
source env.sh

# Build Gemmini
cd generators/gemmini
make -C software/libgemmini install
./scripts/setup-paths.sh
```

> [!IMPORTANT]
> Full Chipyard setup requires ~20-25 GB disk space and 1-2 hours of build time. This environment setup is currently **in progress**.

### 6.6 Current Status and Next Steps

**Completed:**
- [x] Studied Systolic Array architecture (PE, Mesh, Dataflow, Tiling)
- [x] Identified Gemmini as a suitable open-source platform
- [x] Analyzed PE.scala source code and verified Weight Stationary dataflow implementation
- [x] Defined SW/HW task partitioning for Llama 3.2

**Next Steps:**
- [ ] Set up Chipyard environment and generate Gemmini Verilog
- [ ] Configure array dimensions (e.g., 16x16) and data width (int8/int4)
- [ ] Synthesize generated Verilog for target FPGA
- [ ] Integrate with ARM CPU for end-to-end inference pipeline
