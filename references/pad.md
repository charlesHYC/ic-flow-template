# IO PAD 說明

這套公版只做核心，沒有 PAD 的腳本。這份說明給想把設計做成「加 PAD 的完整晶片」的人：PAD 是什麼、製程給了什麼、怎麼選、流程每一步要多做什麼、要自己寫哪些腳本、怎麼確認做對。

SAED32 的部分對照它的 IO library 手冊（`lib/io_std/doc/SAED32.28nm_IO_Standard_Cell_Library_b100_01312012.pdf`）。標「業界常見做法」的是一般原則，不是 SAED32 手冊的規定。

## 1. PAD 是什麼、為什麼要

晶片做好後，要用金線（打線，wire bond）接到封裝的接腳。金線不能打在你的電路上，要打在晶片邊緣一圈專門的元件上，這種元件叫 PAD。PAD 做四件事：

- **打線的落點**：每顆 PAD 有一塊大金屬片給金線焊上去。
- **推得動外面的負載**：板子上的線和其他晶片是 pF 等級，核心的小 cell 推不動，要靠 PAD 裡的大驅動電路。
- **電壓轉換**：核心 1.05 V，晶片外 2.5 V（SAED32），PAD 負責兩者之間的轉換。
- **ESD（Electrostatic Discharge，靜電放電）保護**：PAD 裡的二極體把靜電導走，避免打壞核心電晶體（SAED32 手冊：HBM 2 kV）。

不加 PAD 的設計只能當 IP block，不能直接封裝。

## 2. 製程提供哪些 PAD 資料、怎麼用

SAED32 的 PAD 資料在 `lib/io_std/`：

| 資料 | 內容 | 哪一步用 |
|---|---|---|
| `db_nldm/*.db`、`.lib` | 每顆 PAD 的延遲、負載能力、電壓，一個 corner 一份 | 合成、STA；也可以從這裡查 PAD 延遲 |
| `verilog/` | PAD 的行為 model（沒有延遲） | RTL／Gate-level sim |
| `lef/` | 外框大小、pin 位置、繞線阻擋 | 建 NDM、APR |
| `gds/` | 真正的版圖 | APR 輸出 GDS 時併進去，給 DRC／LVS |
| `lvs/*.cdl` | PAD 裡的電晶體電路 | LVS |
| `doc/*.pdf` | 有哪些 PAD、電壓、電流上限、結構 | 選 PAD、決定電源 PAD 數量 |

這些都是固定的元件資料。製程**不會**告訴你 PAD 要擺哪裡、電源怎麼接，這部分要自己寫腳本（第 5 節）。

注意：SAED32 io_std 的 GDS、CDL、LEF 彼此有幾處不一致（例如輸入 PAD 裡有一條訊號線和 VDDIO 短路、電源 PAD 的二極體方向寫反、LEF 漏寫真正的電源線），直接用原檔做全晶片 DRC／LVS 不會過。正常的商用製程遇到這種情況，是回報給廠商修正。

## 3. SAED32 有哪些 PAD、怎麼選

| 種類 | SAED32 名稱 | 什麼時候用 |
|---|---|---|
| 輸入 | `I1025` | 一般輸入 |
| 輸入（Schmitt trigger，施密特觸發，抗雜訊） | `ISH1025` | 訊號慢或雜訊大，例如 reset、按鍵 |
| 輸出 | `D4I1025`、`D8I1025`、`D12I1025`、`D16I1025` | 一般輸出；數字是驅動電流（mA），負載大選大的（手冊列了 2 mA 版，但 library 裡沒有） |
| 雙向 | `B4I1025`～`B16I1025`（`BxISH1025` 為 Schmitt 版） | inout port |
| 核心電源 | `VDD`、`VSS` | 核心 1.05 V 電源；手冊標每顆 40 mA |
| IO 電源 | `IOVDD`、`IOVSS` | PAD 自己的 2.5 V 電源；每顆 40 mA |
| 類比 | `A1825`、`AR1825`、`AVDD`、`AVSS` | 類比訊號與類比電源 |
| 角落 | `CORNER`、`CAPCORNER` | 四個角，見第 9 節 |
| 填空 | `FILLER`、`FILLER01`～`FILLER50` | PAD 之間的空位；數字是寬度（µm），讓電源環連續 |
| 斷開 | `BREAKCORE`（只留 IO 電源）、`BREAKIO`（只留核心電源） | 要把電源環切成好幾段時 |
| 去耦電容 | `CVDDVSS`、`CIOVDDIOVSS` | 放在 PAD ring 裡多加穩壓電容（約 70 pF） |

每種都有 `_NS` 與 `_EW` 兩個版本：**`_NS`（直的，40 寬 × 300 高）放上下邊，`_EW`（橫的，300 × 40）放左右邊**。不要把 `_NS` 轉 90 度放在左右邊：裡面電晶體的方向會錯，DRC 報幾千個 PO／CO 錯誤。

輸出驅動電流怎麼選：看 `.lib` 推 1 pF 的延遲。電流越大越快，但耗電與同時切換雜訊也越大。例：`D4I1025`（4 mA）在 slow corner 推 1 pF 約 1.2–1.4 ns，對 30–50 ns 週期夠用。

## 4. 加 PAD 後，流程每一步要多做什麼

PAD 要在寫 RTL、跑第一次模擬前就決定，不是到 APR 才加：PAD 有延遲（SAED32 slow：輸入約 0.4 ns、輸出推 1 pF 約 1.2–1.4 ns），輸出負載也從核心的幾十 fF 變成板子上的 1 pF，從 RTL 模擬開始每一步的結果都會變。中途才加，前面每一步都要重做。

| 步驟 | 加 PAD 後多做的事 |
|---|---|
| 0. 規劃 | 每個 port 用哪種 PAD、幾顆電源 PAD、晶片多大 |
| 0. wrapper | 寫一個 `<DESIGN>_chip` 模組：每個 port 接一顆 PAD，裡面接原設計。之後每一步的 top 都是它 |
| 1. RTL 模擬 | 模擬 `<DESIGN>_chip`。官方 PAD model 沒有延遲，要自己加 `specify` 延遲才看得到 PAD 的影響 |
| 2. 合成 | PAD 設 `set_dont_touch`；輸出負載改 1 pF；port 到 PAD 那段是打線，`set_resistance 0` |
| 4. STA | 路徑起訖點是 PAD；clock 經過 PAD 後要 `set_ideal_network`（否則寫出的 SDF 會帶很大的假延遲） |
| 5. Gate-level sim | SDF 的 PAD 延遲要註入得進 PAD model |
| 6. APR | 依 PAD 數算 die；擺 PAD、corner、filler；建立四組電源 VDD／VSS／VDDIO／VSSIO；電源 PAD 接到 core ring；port 綁在 PAD 上；clock PAD 後插一顆 buffer 當 clock tree 起點 |
| 7. DRC／LVS | GDS 併入 PAD 版圖；LVS 加入 PAD 的 CDL |
| 8、9 | 和核心相同，top 換成 `<DESIGN>_chip` |

## 5. 要自己寫哪些腳本

製程只給 PAD 元件，怎麼擺、怎麼接要自己寫；業界也是每個專案自己寫，或用公司內部模板。至少需要：

| 要寫的東西 | 做什麼 |
|---|---|
| wrapper 產生器（或手寫 `<DESIGN>_chip.v`） | 每個 port 接一顆 PAD；PAD 的電源 pin 在模擬時要給 1／0 |
| 帶延遲的 PAD 模擬 model | 從 `.lib` 查延遲，寫成 `specify` |
| 加 PAD 的 SDC | 1 pF 負載、打線電阻 0、clock PAD 後 ideal |
| APR 的 PAD ring 腳本 | 算 die、擺 PAD／corner／filler、四組電源與 IO 電壓、電源 PAD 接 core ring、port terminal |
| LVS 的 netlist 處理 | 加入 PAD 的 CDL；刪掉 CDL 裡沒有電路的 corner、filler |

完整可以跑的參考實作在 [IC_flow_skill](https://github.com/charlesHYC/IC_flow_skill) 的 `digital-ic-flow`：`pad_tools.py`（wrapper、PAD model）、`apr_pad_ring.tcl`（PAD ring）、`constraints_chip.sdc`、`fix_io_lib.py`（修正 SAED32 PAD 資料的不一致）。它用 REFRACT 跑過，加 PAD 的全晶片 DRC CLEAN、LVS PASS。

## 6. 怎麼確認 PAD 用對了

全部都要成立：

1. **功能**：RTL 模擬 `<DESIGN>_chip` PASS，而且看得到 PAD 延遲（結果和沒 PAD 時一模一樣，代表 PAD model 沒延遲）。
2. **時序**：最差路徑有經過 PAD 且 slack ≥ 0；輸出負載確實是 1 pF，不是預設幾 fF。
3. **APR**：PAD 圍成一圈不中斷、四角都有 corner；`check_pg_connectivity` 四組電源全部 0 浮接；每個 port 都綁在對應 PAD 上。
4. **DRC**：`RESULTS: CLEAN`，PAD 區域的錯誤也算錯誤。
5. **LVS**：`Final comparison result:PASS`，PAD 裡的電晶體與二極體也要對上。
6. **繞線後模擬**：用實際線延遲跑 `<DESIGN>_chip` 仍然 PASS。

## 7. 最常要注意的點

- **一開始就決定**：中途才加 PAD，合成 top 會變，前面每一步都要重跑。
- **輸出負載要改**：沒改成 1 pF，時序結論是假的。
- **上下 `_NS`、左右 `_EW`**：不要自己轉。
- **電源 PAD 要夠（業界常見做法）**：核心總電流 ÷ 每顆電源 PAD 的電流上限（SAED32 手冊 40 mA）= 至少要幾對；輸出 PAD 同時切換會讓 IO 電源跳動，每幾顆輸出 PAD 要配一對 IO 電源 PAD（實際比例看廠商的 SSO 規範，SSO = Simultaneous Switching Output）。不夠時 DRC／LVS 照樣會過，但晶片可能不穩。
- **電源 PAD 一定要真的接到 core ring**：沒接上核心就沒電；用 `check_pg_connectivity` 確認。
- **PAD 一定要 `dont_touch`**：否則合成或 APR 可能改掉、刪掉 PAD。
- **clock 經過 PAD 之後**：ICC2 不在 PAD 的輸出 net 上建 clock tree（CTS-053），要在 PAD 後插一顆 buffer 當起點。
- **port 的 terminal 要放在真正有金屬的地方**：LVS 靠 GDS 裡的 port 文字找接腳，文字落在沒有金屬的地方會報 untexted port。
- **VSS 與 VSSIO**：手冊有 `DIOVSSVSS` 二極體，表示原本設計是兩者分開；但 SAED32 核心和 IO 共用 P 型基板，矽片上是連在一起的，LVS 抽出來會是同一個 net。

## 8. 通常怎麼排（業界常見做法）

- **先判斷 pad-limited 還是 core-limited**：PAD 一圈排下來比核心大，就是 pad-limited（例：49 個 PAD → die 1200 µm，核心只用一部分），可以縮 PAD 間距、選窄的 PAD、減少 port。核心比較大就是 core-limited，PAD 之間會有空位要補 filler。
- **電源 PAD 分散在四邊**：不要擠在同一邊，核心各處電壓才平均。
- **輸出 PAD 附近要有 IO 電源 PAD**。
- **clock 輸入 PAD 放在某一邊的中間附近**，到核心的距離短。
- **相關訊號放同一邊**（例如同一組匯流排），板子上拉線方便。

## 9. Corner pad 是什麼、怎麼選

PAD 一圈排下來，四個角是空的。但 PAD 裡的四條電源環（VDD／VSS／VDDIO／VSSIO）要繞整圈才連得起來，角落要放一塊把兩邊電源環接起來的元件，這就是 corner pad。它沒有打線金屬、沒有電路，只讓電源環轉彎連通。

| 名稱 | 差別 | 什麼時候用 |
|---|---|---|
| `CORNER` | 只把電源環接起來 | 一般情況 |
| `CAPCORNER` | 再加上 VDD／VSS 之間的去耦電容 | 核心電源雜訊大、想多一點穩壓時 |

四個角都要放，方向依角落旋轉（例：左下 R270、右下 R0、右上 R90、左上 R180，依 cell 原始方向而定）。

兩種 corner 的 LEF 都很複雜（各約 11 萬個形狀），ICC2 用預設設定建 IO 的 NDM 要 40 分鐘以上；在建 NDM 時用 `configure_frame_options -mode block_and_trim` 可以降到幾秒。
