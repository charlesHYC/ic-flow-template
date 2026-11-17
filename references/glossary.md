# 縮寫與名詞對照

流程、報告與對話中常見的縮寫，依類別整理。解釋給初學者時，縮寫第一次出現就附上全名與白話說明。

## 流程與設計層級

| 縮寫 | 全名 | 白話 |
|---|---|---|
| **RTL** | Register Transfer Level | 用 Verilog 描述「暫存器之間資料怎麼流動」的設計層級，就是你寫的程式碼 |
| **APR** | Automatic Placement and Routing | 自動擺放與繞線，把 netlist 變成實際版圖 |
| **PEX** | Parasitic Extraction | 萃取線上的寄生電阻與電容（StarRC 做的事） |
| **STA** | Static Timing Analysis | 靜態時序分析：不跑模擬，直接算每條路徑夠不夠快 |
| **LEC** | Logic Equivalence Checking | 邏輯等價驗證：數學證明兩份電路功能相同（Formality 做的事） |
| **DRC** | Design Rule Check | 檢查版圖有沒有違反製程規則（線太細、太近） |
| **LVS** | Layout Versus Schematic | 比對版圖和電路圖是否一致 |
| **ECO** | Engineering Change Order | 設計後期的小幅修改（插 buffer、換大顆 cell），不重做整個流程 |
| **CTS** | Clock Tree Synthesis | 時脈樹合成：把 clock 平均送到每顆 FF |
| **DFT** | Design for Testability | 可測試性設計（scan chain 等），本流程未做 |

## 工具

| 縮寫 | 全名 | 用在哪一階段 |
|---|---|---|
| **VCS** | Verilog Compiled Simulator（Synopsys） | RTL 模擬、閘級模擬 |
| **DC** | Design Compiler（Synopsys） | 邏輯合成 |
| **FM** | Formality（Synopsys） | 等價驗證 |
| **PT** | PrimeTime（Synopsys） | STA |
| **ICC2** | IC Compiler II（Synopsys） | APR |
| **ICV** | IC Validator（Synopsys） | DRC、LVS |
| **StarRC** | Synopsys 的寄生萃取工具（RC = Resistance–Capacitance） | PEX |
| **Verdi** | Synopsys 的波形與除錯工具 | 看波形 |

## 檔案格式

| 縮寫 | 全名 | 白話 |
|---|---|---|
| **LEF** | Library Exchange Format | 零件的外框和接腳位置圖（給 APR 擺放、接線） |
| **DEF** | Design Exchange Format | 整顆晶片擺放和繞線結果的描述（LEF 的搭檔） |
| **GDS**（GDSII） | Graphic Data System II（常被寫成 Graphic Design System） | 真正的版圖檔，每一層的每個形狀；交給晶圓廠的就是它 |
| **CDL** | Circuit Description Language | 電路圖的文字版（電晶體怎麼連），LVS 的標準答案 |
| **SPICE** | Simulation Program with Integrated Circuit Emphasis | 電路模擬程式；CDL 是它的格式變體 |
| **Liberty**（.lib／.db） | Synopsys 制定的 cell 時序格式（.db 是編譯後的二進位版） | 每顆 cell 的延遲、電容、面積規格表 |
| **SDC** | Synopsys Design Constraints | 時序約束：clock 週期、I/O 延遲、負載 |
| **SDF** | Standard Delay Format | 每顆 cell、每條線的延遲，給閘級模擬用 |
| **SPEF** | Standard Parasitic Exchange Format | 萃取出的寄生 RC，給繞線後 STA 用 |
| **SVF** | Setup Verification for Formality | DC 記錄的合成轉換紀錄，讓 Formality 對得上名字 |
| **DDC** | Synopsys 的設計資料庫格式 | DC 存檔用，保留約束與合成結果 |
| **NDM** | New Data Model | ICC2 用的 library／設計資料庫格式 |
| **FRAM** | Frame view（Milkyway） | 舊版 ICC（Milkyway）的零件抽象圖，等同 LEF 的角色 |
| **VCD** | Value Change Dump | 標準波形檔 |
| **FSDB** | Fast Signal DataBase | Verdi 的壓縮波形檔 |
| **TLU+** | Table Look-Up Plus | 依繞線層查電阻電容的表，APR 估 RC 用 |

## 時序與 corner

| 縮寫 | 全名 | 白話 |
|---|---|---|
| **PVT** | Process, Voltage, Temperature | 製程、電壓、溫度三個會影響速度的條件 |
| **SS／TT／FF** | Slow-Slow／Typical-Typical／Fast-Fast | 三種製程 corner：最慢、典型、最快 |
| **MCMM** | Multi-Corner Multi-Mode | 同時分析多個 corner 與工作模式 |
| **OCV** | On-Chip Variation | 同一顆晶片內不同位置的速度差異 |
| **WLM** | Wire Load Model | 合成時還沒繞線，用扇出數估線電容的模型 |
| **NLDM** | Non-Linear Delay Model | 查表式的 cell 延遲模型（輸入轉換時間 × 負載） |
| **CCS** | Composite Current Source | 比 NLDM 更精確的電流源延遲模型 |
| **WNS／TNS** | Worst／Total Negative Slack | 最差的負 slack／所有負 slack 加總 |

## 製程與元件

| 縮寫 | 全名 | 白話 |
|---|---|---|
| **PDK** | Process Design Kit | 製程設計套件（所有 library 和規則檔的總稱） |
| **EDK** | Educational Design Kit | 教學用設計套件（SAED32 EDK） |
| **SAED** | Synopsys Armenia Educational Department | Synopsys 亞美尼亞教育部門，做 SAED32 這套教學製程的單位 |
| **CBDK** | Cell-Based Design Kit | 台灣 CIC／TSRI 提供的 cell-based 設計套件（IC Contest 用 CBDK_IC_Contest） |
| **CIC／TSRI** | Chip Implementation Center／Taiwan Semiconductor Research Institute | 國家晶片系統設計中心，現為台灣半導體研究中心 |
| **RVT／HVT／LVT** | Regular／High／Low Threshold Voltage | 標準／高／低臨界電壓的 cell：HVT 省漏電但慢，LVT 快但漏電大 |
| **DFF** | D Flip-Flop | D 型正反器，存 1 bit 的暫存器 |
| **PG** | Power／Ground | 電源與地 |
| **VDD／VSS** | 核心電源／核心地 | SAED32 核心 1.05 V |
| **VDDIO／VSSIO** | IO 電源／IO 地 | PAD 用的 2.5 V 電源 |
| **MRDL** | Metal ReDistribution Layer | 最上層的重分佈金屬，打線點所在 |

## IO 與 PAD

| 縮寫 | 全名 | 白話 |
|---|---|---|
| **IO** | Input／Output | 晶片和外界溝通的介面 |
| **PAD** | IO pad | 晶片邊緣的接點零件：打線、ESD 保護、推板級負載 |
| **ESD** | Electrostatic Discharge | 靜電放電；ESD 二極體是防靜電的保護元件 |
| **WB／FC** | Wire Bond／Flip Chip | 兩種封裝方式：打線／覆晶；SAED32 io_std 兩種都有（`_wb`、`_fc`） |
| **HSTL／SSTL** | High-Speed Transceiver Logic／Stub Series Terminated Logic | 高速記憶體介面的 IO 標準（SAED32 io_sp） |
| **PAD_LIMITED** | 本 skill 自訂的判定 | 核心區 DRC 0、電晶體全對上，剩下的錯誤只在 IO library 內；**不等於 PASS** |
