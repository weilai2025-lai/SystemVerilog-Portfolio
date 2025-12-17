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
在原本的 VHDL 版本中，我們是用 **「算術邏輯」** 來思考。我們想把原本範圍 `[-512, +511]` (假設 in_width=10) 的訊號，平移成 `[0, 1023]` 的位址。

**VHDL Code:**
```vhdl
if rising_edge(clk) then
  if signed(x) >= 0 then
    -- 正數：原本是 0，加上 512 (Offset) 變成 ROM 的中後半段
    y <= std_logic_vector(signed(x) + to_signed(2**(inWidth-1), inWidth));
  else
    -- 負數：原本是 -1，減去 512 (或者說加上負的 Offset)，繞一圈回到 ROM 的前半段
    y <= std_logic_vector(signed(x) - to_signed(2**(inWidth-1), inWidth));
  end if;
end if;
```
**缺點：** 雖然邏輯正確，但寫起來很冗長，而且使用了加法器/減法器邏輯 (Adder/Subtractor)，雖然合成器很聰明會優化，但語意上看起來很重。

### Phase 2: The "Aha!" Moment (Bitwise Analysis)
讓我們用 **10-bit** (範圍 -512 ~ +511) 來拆解 VHDL 裡面的數學在二進位做了什麼事。
OFFSET (偏移量) 是 $2^{(10-1)} = 512$，二進位是 `10_0000_0000`。

1.  **對於正數 (Case: x = 0, 00...0)**
    - VHDL 邏輯：`0 + 512 = 512`
    - 二進位運算：`00_0000_0000 + 10_0000_0000 = 10_0000_0000`
    - **觀察：** 其實只是把 MSB 從 0 變成 1。

2.  **對於負數 (Case: x = -512, 10...0)**
    - VHDL 邏輯：`-512 - 512 = -1024`。在 10-bit 系統中，-1024 溢位後就是 0。
    - 二進位運算：`10_0000_0000 - 10_0000_0000 = 00_0000_0000`
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

### Truth Table 證明 (以 10-bit 為例)
假設 `in_width = 10`，數值範圍 -512 到 +511。

| 十進位數值 (Val) | 2's Comp (Binary) | MSB | 反相 MSB 後的 `y` | 對應的 ROM 意義 |
| :--- | :--- | :--- | :--- | :--- |
| **-512 (Min)** | 10_0000_0000 | 1 | **00_0000_0000 (Addr 0)** | **最小值 (Sigmoid趨近0)** |
| ... | ... | ... | ... | ... |
| -1 | 11_1111_1111 | 1 | 01_1111_1111 (Addr 511) | |
| **0** | 00_0000_0000 | 0 | **10_0000_0000 (Addr 512)** | **零點 (Sigmoid=0.5)** |
| 1 | 00_0000_0001 | 0 | 10_0000_0001 (Addr 513) | |
| ... | ... | ... | ... | ... |
| **511 (Max)** | 01_1111_1111 | 0 | **11_1111_1111 (Addr 1023)** | **最大值 (Sigmoid趨近1)** |

---

## 2. Sum Accumulator Bit-Width Selection

### 決策
**累加器暫存器 `sum` 維持 `2*data_width` (32-bit)，但中間運算訊號 `comboadd` 多開 1-bit (33-bit)。**

### 硬體運作原理 (Why logic works?)

#### 1. 暫態擴展 (Transient Expansion via comboadd)
雖然 `sum` (Storage) 只有 32-bit。
但你的 `comboadd` (Wire) 定義為 `logic signed [2*data_width:0] comboadd;` (**33-bit**)。

**關鍵點：** 當 `mul + sum` 的結果超過 32-bit 範圍時，這個瞬間的溢位數值會被完整保留在 33-bit 的 `comboadd` 線路上，不會馬上遺失。

#### 2. 溢位攔截 (Overflow Detection)
我們檢查 `mul` (加數)、`sum` (被加數) 和 `comboadd` (結果) 的最高位元 (Sign Bit)。

**邏輯判斷：**
```systemverilog
// 正 + 正 = 負 (代表爆掉了)
if (!mul[MSB] && !sum[MSB] && comboadd[MSB+1])
```
因為 `comboadd` 多了那第 33 個 bit，所以它能正確反映出「數學上已經爆掉」的事實。

#### 3. 飽和寫回 (Saturation Clamp)
當偵測到上述溢位時，我們拒絕把 `comboadd` (那串爆掉的亂碼) 寫入 `sum`。
取而代之，我們強制寫入 `pos_sat` (32-bit 的最大正整數)。

### 結論
因為我們有這道「攔截機制」，所以 `sum` 暫存器永遠不需要儲存大於 32-bit 的數值。任何超過的值，都會被硬體「削平」成 `pos_sat`。

**一句話總結：**
我們不需要加寬 `sum` 來存放溢位值，因為 `comboadd` (33-bit) 負責在組合邏輯層偵測溢位，並透過飽和邏輯直接將其「削平」後才存入 `sum`。

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
