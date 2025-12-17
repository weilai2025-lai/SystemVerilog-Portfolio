# Neuron Design Checkpoint & Implementation Notes

**Date:** 2025-12-17  
**Project:** NPU Implementation (SystemVerilog)  
**Author:** Wei-In Lai

## 1. Sigmoid ROM Addressing Logic (The "MSB Flip" Trick)

### 程式碼片段
```systemverilog
// x is signed input (2's complement), y is unsigned ROM address
always_ff @(posedge clk) begin
    y <= {~x[in_width-1], x[in_width-2:0]};
end
```

### 為什麼要這樣寫？（推導與證明）

**問題情境：**
- 輸入 `x` 是一個 **有號數 (Signed 2's Complement)**，代表神經元的加權總和（數值範圍包含負數到正數）。
- ROM 的位址 `y` 是一個 **無號數 (Unsigned Index)**，代表查表的位置（從 0 開始遞增）。

我們希望 ROM 的內容排列是順序的：
- **Address 0 (最小位址)**：存放 Sigmoid(最小值)（即最負的輸入）
- **Address Max (最大位址)**：存放 Sigmoid(最大值)（即最正的輸入）

**直覺上的衝突：**
在 2's Complement 表示法中，負數的 MSB 是 1，正數的 MSB 是 0。如果直接把二進位碼當作位址去查：
- 正數 (MSB=0) 會被映射到 ROM 的 **前半段**。
- 負數 (MSB=1) 會被映射到 ROM 的 **後半段**。

**結果：**
數值順序會變成 `[0, 1, 2 ... -Max, ... -2, -1]`，這是錯亂的。

### 解決方案：MSB 反相
我們需要把負數搬到前面（位址 0~N/2），把正數搬到後面（位址 N/2~N）。
觀察二進位碼，只要把 **最高位元 (Sign Bit) 反相**，就能完美達成線性映射。

### Truth Table 證明 (以 3-bit 為例)
假設 `in_width = 3`，數值範圍 -4 到 +3。

| 十進位數值 (Val) | 2's Comp 輸入 `x` (Binary) | MSB (Sign Bit) | 反相 MSB 後的 `y` | 對應的 ROM 意義 |
| :--- | :--- | :--- | :--- | :--- |
| **-4 (Min)** | 100 | 1 | **000 (Addr 0)** | **最小值 (Sigmoid趨近0)** |
| -3 | 101 | 1 | 001 (Addr 1) | |
| -2 | 110 | 1 | 010 (Addr 2) | |
| -1 | 111 | 1 | 011 (Addr 3) | |
| **0** | 000 | 0 | **100 (Addr 4)** | **零點 (Sigmoid=0.5)** |
| 1 | 001 | 0 | 101 (Addr 5) | |
| 2 | 010 | 0 | 110 (Addr 6) | |
| **3 (Max)** | 011 | 0 | **111 (Addr 7)** | **最大值 (Sigmoid趨近1)** |

**結論：**
`{~x[MSB], x[Rest]}` 是將 2's Complement (有號) 轉換為 Biased Unsigned (無號線性偏移) 的最快硬體實作方式。

---

## 2. Sum Accumulator Bit-Width Selection

### 決策
累加器 `sum` 的寬度設定為 **2 * data_width** (或 2*data_width + 1)。

### 理由
1.  **乘法擴展 (Multiplication Expansion)**：
    - 輸入 `myinput` 是 `data_width` (16-bit)。
    - 權重 `weight` 是 `data_width` (16-bit)。
    - 乘法結果 `mul` 必然需要 16 + 16 = 32-bit (`2 * data_width`) 才能完整保留精度而不溢位。

2.  **累加溢位防護 (Accumulation Headroom)**：
    - 我們需要連續累加 784 次 (MNIST 圖片大小)。
    - 理論上，累加 784 個 32-bit 的數，需要額外的 $\lceil \log_2(784) \rceil \approx 10$ bits 才能保證 "絕對" 不溢位。
    - **但為什麼只用 2*data_width 就夠？**
        - 因為神經網路的權重與輸入通常呈現常態分佈，正負值會互相抵消，極少出現連續 784 次都是最大正值的情況。

3.  **配合飽和運算 (Saturation Logic)**：
    - 我們在代碼中實作了 `pos_sat` (正飽和) 和 `neg_sat` (負飽和)。
    - 如果真的爆掉了，就卡在最大/最小值，這對神經網路的準確度影響遠小於直接 Overflow (數值 wrap around)。

**設計總結：**
`sum` 必須至少容納單次乘法的完整結果 (`2*data_width`)，這就是基本盤。

---

## 3. Pipeline Timing Control (Logic Confirmation)

### 核心爭論點
**什麼時候才是「算完」的時刻？什麼時候該 Reset？**

### 最終確認邏輯 (The Correct Approach)

**資料流動：**
`myinput` 進來 -> `mul` (乘法, 1 cycle) -> `sum` (加法, 1 cycle) -> ...
這是一個 Pipeline，不能在輸入停掉的當下就馬上抓值，因為資料還在管線裡跑。

**關鍵訊號 `muxvalid_f` (Falling Edge)：**
我們利用 `muxvalid` 的 **下降緣 (Falling Edge)** 來偵測「最後一筆乘法剛做完，正要推進去加法器」的時刻。

**Logic:**
```systemverilog
(!muxvalid) && (muxvalid_d)
```
這確保了我們是在所有 pixel 都進入累加器後的**下一個 cycle** 才拉起 `outvalid`。

### Reset 機制 (sum 歸零)

**Reset 時機：**
```systemverilog
if (rst || outvalid_i) sum <= '0;
```
這是一個 **Non-blocking Assignment (<=)**。

**時序細節：**
- 當 `outvalid` 為 High 的當下 (T0)，`output_data` 輸出的是計算好的正確 `sum` (經過 Sigmoid)。
- 同時，`sum <= '0` 這行指令被觸發，但它會在 **T0 結束後 (即 T1 的開始)** 才生效。

**結果：**
- T0 依然能讀到正確值。
- T1 才會變回 0 (導致 T1 的 output 變成 Sigmoid(0)=0.5)。

**結論：**
這個設計是安全的，確保了 Output Valid 期間資料有效，且能自動清空給下一張圖片使用。
