# SystemVerilog Syntax & Verification Review

**Date:** 2025-12-17  
**Author:** Wei-In Lai  

這份筆記整理了 SystemVerilog 開發過程中常見的語法細節、驗證技巧以及最佳實踐。

---

## 1. 賦值：`=` vs. `<=` (Blocking vs. Non-Blocking)

這是最容易混淆的點，決定了數值更新的「時機」。

| 符號 | 類型 | 白話文解釋 | 適用場景 |
| :--- | :--- | :--- | :--- |
| `=` | **Blocking (阻塞)** | 「插隊」。程式執行到這行，數值**馬上**變。下一行讀到的已經是新值。 | 組合邏輯 (`always_comb`)、產生 Clock (`clk = ~clk`)、單純變數運算。 |
| `<=` | **Non-Blocking (非阻塞)** | 「領號碼牌」。先計算好，等這個時間點(Time slot)結束後才**一起**更新。 | 時序邏輯 (`always_ff`)、在 TB 中餵訊號給 DUT。 |

### 為什麼 TB 餵訊號要用 `<=`？
為了模擬真實硬體的 **Setup Time**。

```systemverilog
@(posedge clk);
myinput <= 1; // 推薦：在 Clock 上升緣後，「稍微晚一點點」才變 1，保證 DUT 能穩定抓到。
```

---

## 2. 數值寫法：`0` vs. `'0` (Fill Literal)

| 寫法 | 意義 | 潛在風險/優點 |
| :--- | :--- | :--- |
| `0` | 整數 0 (預設 32-bit) | 如果匯流排是 1024-bit，雖然編譯器會補零，但語意上是用小容器裝大水缸。 |
| `'0` | **全填 0 (Fill Literal)** | **推薦**。不管變數多寬，自動把每一個 bit 都填滿 0。 |

**同場加映：**
*   `'1`：全部填 1 (全 F)。(比寫 `-1` 或 `16'hFFFF` 直觀且安全)
*   `'z`：全部高阻抗。
*   `'x`：全部未知。

---

## 3. 時序控制 (Time Flow Control)

這段代碼的連續動作解析：

```systemverilog
#100;           // 動作 A
@(posedge clk); // 動作 B
rst = 0;        // 動作 C
```

1.  `#100;`：**睡覺**。原地暫停 100ns。
2.  `@(posedge clk);`：**設柵欄 (Barrier)**。不管現在幾點，程式會卡住 (Block) 在這裡。死守到下一次 clk 變為 1 (Rising Edge) 的瞬間，柵欄才會打開。
3.  `rst = 0;`：柵欄一打開，馬上執行這一行。

**VHDL 對照：**
這完全等同於 VHDL 的 `wait until rising_edge(clk); rst <= '0';`。

---

## 4. 並行等待：`fork ... join_any`

用於實現 **「帶有超時機制 (Timeout) 的等待」**。

### 結構圖解

```systemverilog
fork 
    // 跑者 A：等待成功訊號
    begin
        wait(outvalid);
        $display("Success!");
    end
    
    // 跑者 B：計時器 (倒數計時)
    begin
        #20000;
        $display("Timeout!");
    end
join_any; // <--- 只要 A 或 B 其中一人跑完，比賽就結束，主程式往下走
```

*   `fork`：分身術，讓 A 和 B 同時開始跑。
*   `join_any`：**「看誰先做完」**。如果 A 先收到訊號，就不管 B 了，直接往下執行。
*   **注意**：通常建議在後面加一行 `disable fork;` 來殺死還沒跑完的那個執行緒 (避免殭屍計時器在背景亂叫)。

---

## 5. 參數路徑串接 (String Concatenation)

如何讓 Testbench 的檔案路徑更有彈性？使用 `{}` 串接字串。

**技巧：** 利用 SystemVerilog 的 `parameter` 相依性，在宣告時直接組裝路徑。

```systemverilog
module neuron #(
    // 1. 定義根目錄 (記得加 / )
    parameter string base_dir = "C:/Project/",
    
    // 2. 定義檔名
    parameter string weight_file = "w.mif",
    
    // 3. 自動組裝 (就像拼積木一樣)
    parameter string weight_path_abs = {base_dir, weight_file} 
)(...);

    initial begin
        // 4. 之後都用組裝好的變數
        $readmemb(weight_path_abs, mem);
    end
endmodule
```

**好處：** 只要改 `base_dir` 一個地方，所有的 .mif 讀取路徑都會自動更新，移機開發超方便。
