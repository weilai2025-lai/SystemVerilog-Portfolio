# Neuron Design Checkpoint & Implementation Notes

**Date:** 2025-12-17  
**Project:** NPU Implementation (SystemVerilog)  
**Author:** Wei-In Lai

## 1. Sigmoid ROM Addressing Logic: From Math to Bit-Hacking

**目標：** 將有號輸入 `x` (Signed 2's Complement) 映射到 ROM 的無號位址 `y` (Unsigned Index)。

**核心概念：** 我們需要做一個座標平移，把原本在中間的 0 搬到 ROM 的中間位址。
我們希望 ROM 的內容排列是順序的：
- **Address 0 (最小位址)**：存放 Sigmoid(最小值)（即最負的輸入）
- **Address Max (最大位址)**：存放 Sigmoid(最大值)（即最正的輸入）

### Phase 1: The Old VHDL Approach (Mathematical Offset)
在原本的 VHDL 版本中，我們是用 **「算術邏輯」** 來思考。我們想把原本範圍 `[-128, +127]` 的訊號，平移成 `[0, 255]` 的位址。

**VHDL Code:**
```vhdl
if rising_edge(clk) then
  if signed(x) >= 0 then
    -- 正數：原本是 0，加上 128 (Offset) 變成 ROM 的中後半段
    y <= std_logic_vector(signed(x) + to_signed(2**(inWidth-1), inWidth));
  else
    -- 負數：原本是 -1，減去 128 (或者說加上負的 Offset)，繞一圈回到 ROM 的前半段
    y <= std_logic_vector(signed(x) - to_signed(2**(inWidth-1), inWidth));
  end if;
end if;
```
**缺點：** 雖然邏輯正確，但寫起來很冗長，而且使用了加法器/減法器邏輯 (Adder/Subtractor)，雖然合成器很聰明會優化，但語意上看起來很重。

### Phase 2: The "Aha!" Moment (Bitwise Analysis)
讓我們用 3-bit (範圍 -4 ~ +3) 來拆解 VHDL 裡面的數學在二進位做了什麼事。
OFFSET (偏移量) 是 $2^{(3-1)} = 4$，二進位是 `100`。

1.  **對於正數 (Case: x = 0, 000)**
    - VHDL 邏輯：`0 + 4 = 4`
    - 二進位運算：`000 + 100 = 100`
    - **觀察：** 其實只是把 MSB 從 0 變成 1。

2.  **對於負數 (Case: x = -4, 100)**
    - VHDL 邏輯：`-4 - 4 = -8`。在 3-bit 系統中，-8 溢位後就是 0。
    - 二進位運算：`100 - 100 = 000` (或者想成 `100 + 100 = 1000` -> 取後三位 -> `000`)
    - **觀察：** 其實只是把 MSB 從 1 變成 0。

### Phase 3: The New SystemVerilog Approach (MSB Flip)
我們發現，不管是要加 Offset 還是減 Offset，在二進位及補數系統的特性下，等效動作竟然只有「**反轉最高位元 (Toggle MSB)**」。

**SystemVerilog Code:**
```systemverilog
always_ff @(posedge clk) begin
    // 直接把 x 的最高位元取反 (~)，剩下的位元照抄
    y <= {~x[in_width-1], x[in_width-2:0]};
end
```

### 演進總結 (Summary of Evolution)

| 特性 | 舊版 VHDL | 新版 SystemVerilog |
| :--- | :--- | :--- |
| **思考模式** | 十進位算術思維 (正數加偏移，負數減偏移) | 二進位硬體思維 (觀察 Bit pattern 的變化) |
| **硬體成本** | 寫起來像加法器 (Adder)，依賴合成器優化 | 只有一個 **反相器 (Inverter)**，成本極低 |
| **程式碼** | 7 行 (If-Else 判斷) | 1 行 (Bit Concatenation) |

**結論：**
`x ± Offset` <=> `MSB Invert`
一言以蔽之：在二補數系統中，加上半個範圍的數值 (Bias Shift)，在硬體電路上 **等同於** 反轉最高位元 (MSB Invert)。

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
