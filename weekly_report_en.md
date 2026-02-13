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

### 4.2 Storage Format Breakdown (Current Safetensors)

| Format | Which Parameters | Count | Params | Disk Size |
|--------|-----------------|-------|--------|-----------|
| **bfloat16** (native float) | `embed_tokens`, all `layernorm`, `model.norm` | 34 tensors | ~262.7M | ~0.526 GB |
| **nf4** (bitsandbytes 4-bit) | All linear layers: `q/k/v/o_proj`, `gate/up/down_proj` | 112 tensors | ~973M | ~0.486 GB |
| Traditional int4 | **None** | 0 | 0 | 0 |
| Quant metadata | `quant_map`, `absmax`, `nested_absmax`, `quant_state` | 560 tensors | — | ~0.016 GB |

> [!NOTE]
> **NF4 Dequantization** (required at inference — computation must use float):
> ```
> 1. Unpack: each uint8 byte contains 2 × 4-bit indices (0~15)
> 2. Lookup: quant_map[4bit_index] → normalized float value
> 3. Scale:  float_value = quant_map[index] × absmax[group_id]
> ```
> Unlike uniform int4 (-8~7), NF4 uses a **non-uniform lookup table** optimized for normally-distributed weights.

### 4.3 Model Weights for FPGA Deployment (Int4 Storage)

**Scenario A: All weights quantized to int4 (including embedding)**
```
Weight Size = 1.236B × 4 bits / 8 = 0.618 GB

Scale factors (group_size=128, float32):
  (1.236B / 128) × 4 bytes ≈ 0.04 GB

Total weights (int4): ~0.66 GB
```

**Scenario B: Embedding kept in bfloat16 (like current bnb model)**
```
Embedding (bfloat16): 262M × 2 bytes = 0.525 GB
Other weights (int4): 973M × 4/8 + scale ≈ 0.52 GB
Total: ~1.04 GB (already exceeds 1 GB!)
```

### 4.4 KV Cache

> [!WARNING]
> **Correction**: This model uses **GQA (Grouped Query Attention)** with `num_key_value_heads = 8` and `head_dim = 64`, so `kv_dim = 8 × 64 = 512` (NOT 2048).

**Formula**:
```
KV_Cache = n_layers × 2 × seq_len × kv_dim × sizeof(float)
         = 16 × 2 × seq_len × 512 × 4
```

| seq_len | KV Cache Size |
|---------|---------------|
| 2048 | 16 × 2 × 2048 × 512 × 4 = **0.134 GB** |
| 512  | 16 × 2 × 512 × 512 × 4 = **0.034 GB** |
| 256  | 16 × 2 × 256 × 512 × 4 = **0.017 GB** |
| 128  | 16 × 2 × 128 × 512 × 4 = **0.008 GB** |

### 4.5 Activations

For token-by-token inference (no batching), buffers are reused across layers:
```
- Reusable buffers (x, xb, q, k, v, hb, etc.):
  dim=2048 and intermediate_size=8192 vectors
  ~100 KB (reused across layers)
- Attention scores: num_heads × seq_len × 4 bytes
  (32 × 256 × 4 = 32 KB per layer)
- Total activation buffers: ~1 MB
```

### 4.6 Logits

```
vocab_size × 4 bytes = 128,256 × 4 = 0.5 MB
```

### 4.7 System Overhead

```
- OS kernel + drivers: ~150-200 MB
- Tokenizer (program + vocabulary): ~30-40 MB
- Total: ~200-250 MB
```

### 4.8 Total Memory Requirements (Int4 Version)

**Scenario A: All weights in int4 (including embedding)**

| Context Length | Weights (int4) | KV Cache | Act. | System | **Total** | Feasibility |
|---------------|---------------|----------|------|--------|-----------|-------------|
| seq_len=512 | 0.66 GB | 0.034 GB | 0.001 GB | 0.25 GB | **0.95 GB** | ✅ Fits |
| seq_len=256 | 0.66 GB | 0.017 GB | 0.001 GB | 0.25 GB | **0.93 GB** | ✅ Fits |
| seq_len=128 | 0.66 GB | 0.008 GB | 0.001 GB | 0.25 GB | **0.92 GB** | ✅ Fits |

**Scenario B: Embedding in bfloat16, rest in int4**

| Context Length | Weights | KV Cache | Act. | System | **Total** | Feasibility |
|---------------|---------|----------|------|--------|-----------|-------------|
| seq_len=256 | 1.04 GB | 0.017 GB | 0.001 GB | 0.25 GB | **1.31 GB** | ❌ Exceeds |

---

## 5. 💡 Conclusions and Recommendations

### ✅ Key Corrections from Safetensors Verification

1. **Embedding is part of model weights** — the original report double-counted it as a separate 1.0 GB item
2. **KV cache was 4× overestimated** — `kv_dim = 512` (GQA), not 2048
3. **Activations were overestimated** — token-by-token inference only needs ~1 MB, not 50-100 MB

### 📊 Updated Feasibility

**If embedding is quantized to int4** (requires custom C implementation):
- seq_len=512: Total **~0.95 GB** → ✅ **Fits in 1 GB DDR4!**
- Headroom is tight (~50 MB), careful memory management required

**If embedding remains in bfloat16/float32** (simpler implementation):
- Total **~1.04-1.3 GB** → ❌ Exceeds 1 GB limit
- Would require 2 GB DDR4 upgrade

### Recommended Path Forward

1. **Primary approach**: Implement int4 quantization for **ALL** weights including embedding
   - Requires custom int4 embedding lookup in C code
   - With seq_len=512, total memory fits within 1 GB
   - Tight margin (~50 MB headroom) — careful memory management required

2. **Fallback**: If int4 embedding is too complex to implement, upgrade to 2 GB DDR4 board
