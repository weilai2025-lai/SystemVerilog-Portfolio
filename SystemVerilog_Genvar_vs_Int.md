# SystemVerilog 筆記：genvar vs int 的區別

**Date:** 2025-12-18  
**Author:** Wei-In Lai  

## 1. 核心概念
在 SystemVerilog 中，迴圈有分「蓋房子用的」和「住房子用的」。

- **genvar**：屬於 **硬體架構 (Structure)**，用於編譯時期 (Compile/Elaboration Time)。
- **int**：屬於 **行為邏輯 (Behavior)**，用於運作時期 (Run Time)。

---

## 2. 詳細比較表

| 特性 | genvar (Generation Variable) | int (Integer) |
| :--- | :--- | :--- |
| **執行時機** | Elaboration Time (電路合成/展開時) | Run Time (電路通電運作時) |
| **主要用途** | 實例化模組 (Instantiation)、複製硬體電路、批量產生訊號線。 | 描述邏輯行為、陣列索引運算、訊號賦值 (Assignment)。 |
| **物理意義** | 告訴編譯器：「幫我複製貼上這段電路碼 N 次」。 | 告訴電路：「在運作時，依序檢查這 N 條線的狀態」。 |
| **生命週期** | 僅存在於編譯階段，電路生成後即消失。 | 存在於模擬或晶片運作的整個過程中。 |
| **限制** | 只能用在 `generate ... endgenerate` 區塊中。 | 通常用在 `always_comb`、`always_ff` 或 `initial` 區塊中。 |

---

## 3. 圖解比喻：售票亭
想像你要建造並管理一個有 30 個窗口的售票亭：

### 🧱 genvar 是「建築師的藍圖指令」
- **指令**：「用 genvar i = 0 to 29，蓋 30 個售票窗口。」
- **結果**：建築工人 (Quartus/Vivado) 真的蓋出了 30 個實體的物理窗口。
- **特點**：窗口蓋好後就固定了，不能在運作時突然變多或變少。
- **對應代碼**：`neuron u_neuron(...)` 的實例化。

### 👮 int 是「售票員的操作手冊」
- **指令**：「用 int j = 0 to 29，去檢查這 30 個窗口有沒有人排隊。」
- **結果**：售票員 (電路邏輯) 在上班時 (Clock 運作時)，會跑去檢查訊號。
- **特點**：這是在描述「動作」或「訊號流動」。
- **對應代碼**：`always_comb` 裡的邏輯判斷或接線。

---

## 4. 程式碼範例

### 場景 A：我要產生 30 個神經元 (硬體生成)
必須使用 `genvar`，因為你是要創造出 30 個 neuron 模組實體。

```systemverilog
genvar i; // 宣告生成變數
generate
    for (i = 0; i < 30; i++) begin : gen_neurons
        // 這裡是在「蓋房子」，編譯器會把這段 copy-paste 30 次
        neuron u_neuron (
            .id(i),
            .out(layer_out[i])
        );
    end
endgenerate
```

### 場景 B：我要把 30 條線接成一長條 (行為邏輯)
可以使用 `int`，因為模組已經蓋好了，現在只是描述訊號線怎麼連接 (Wiring)。

```systemverilog
always_comb begin
    // 這裡是在「描述行為」，不需要創造新模組
    for (int j = 0; j < 30; j++) begin
        // 把 2D 陣列的線，依序接到 1D 陣列上
        flat_output[j*16 +: 16] = layer_out[j];
    end
end
```

---

## 5. 快速判斷準則 (Rule of Thumb)

1.  **你要 Call Module (u_neuron, u_ram...) 嗎？** 👉 用 `genvar`。
2.  **你要用 assign (或在 always 裡) 做運算或接線嗎？** 👉 用 `int`。
3.  **你在 initial block 裡寫 Testbench 嗎？** 👉 用 `int` (因為 Testbench 本質上是軟體模擬)。
