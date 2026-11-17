# 常見問題與手動修法

格式：**症狀 → 原因 → 怎麼修**。括號裡的數字是驗證時的實測值，換設計會不同。
公版不會自動修這些問題：看懂報告、自己下指令修，是這個流程要練的部分。

## 環境

- **Formality／ICV 一啟動就 crash：`symbol lookup error … libkrb5.so.3`** → 工具自帶的函式庫與系統版本不合。執行前設 `LD_PRELOAD=/lib64/libk5crypto.so.3`（Formality）或 `LD_PRELOAD=/usr/lib64/libkrb5support.so.0`（ICV、Verdi）。不要改安裝目錄。
- **`StarXtract: command not found`** → StarRC 沒在 PATH 裡，`run_starrc.sh` 的 `STARXTRACT` 改成絕對路徑。
- **工具 exit 0 不代表通過** → 一律看報告內容：slack、`VIOLATED`、`Verification SUCCEEDED`、`RESULTS: CLEAN`、`Final comparison result:PASS`。

## 合成（DC）

- **單位搞錯，時序或負載結果怪異** → CBDK 是 pF／kΩ，SAED32 是 fF／MΩ。`set_load 1` 在 SAED32 只是 1 fF。先 `report_units` 確認。
- **SAED32 推不動 1 pF 輸出負載** → 核心 cell 最大的 max_capacitance 只有 168 fF（NBUFFX32_RVT）。核心設計改用 20～50 fF；1 pF 要由 IO PAD 去推。
- **DC 乾淨，佈局前 STA 的 fast corner 卻大負 slack（單一 gate 7～9 ns）** → SAED32 的 wire-load 在 FF library 上讓高扇出 net 延遲暴增，只對 SS 合成時 DC 看不到。公版已用 FF 當 target、同時 link SS（`dc_syn.tcl` 第 1 步）。
- **DC 沒有違規，PT 卻報 max_capacitance 差一點（例 17.6 fF > 16 fF）** → PT 算 pin 電容取上限、DC 用標稱值。把 `dc_syn.tcl` 的 `MAXCAP_DERATE` 調低（0.85 → 0.75 → 0.70）。估法：`上限 × DC 算的值 ÷ PT 算的值`。乘法器這類 XOR／XNOR 多的設計差距最大。
- **PT 報非同步 reset 的 recovery／removal 違規，DC 報告沒有** → DC 預設不分析這兩種檢查，公版已打開 `enable_recovery_removal_arcs`。打開後 slow corner 仍有 removal 違規，就把 `HOLD_LIB` 設成 `$LIB_SLOW`（公版預設）。
- **netlist 出現 assign** → `set_fix_multiple_port_nets -all -buffer_constants`（公版已加）。
- **`UCN-4` 名稱衝突** → `define_name_rules verilog -replacement_char x` 再 `change_names`（公版已加）。
- **constraint 報告一直有 max_leakage_power VIOLATED** → 預設上限是 0，不是時序問題。
- **setup 差一點點（例 −0.002 ns）** → 先用 `report_timing -significant_digits 4` 確認，再試 `compile_ultra -incremental`，或用 `group_path -weight` 加重那一組路徑。

## Function 驗證（Formality）

- **大量 unmatched、black box** → SVF 沒讀到、`hdlin_dwroot` 沒設，或 DC 沒開 `hdlin_enable_hier_map`。
- **verify 跑很久（>20 分鐘）** → `compile_ultra` 重組了 datapath。改回 `compile`，或確認 SVF 有讀到。
- **FM-503 register not found（暫存器在 `DP_OP_*` 底下）** → 合成時做了 retime，DC 要用 `compile_ultra -retime`，SVF 才會記錄。

## Gate-level sim

- **SDF warning `SDFCOM_CFTC … $removal`（每個非同步 reset 的 DFF 一個）** → SAED32 cell model 沒有 removal check，只是 warning。reset 的 removal 時序只能靠 STA 檢查，回報時要說明。
- **`SDFCOM_IWSBA` INTERCONNECT will still be annotated（繞線後 SDF）** → 跨階層的線延遲提醒，VCS 說延遲仍會註入，可接受。
- **RTL 模擬過、Gate-level sim 失敗** → 先看是不是 tb 取樣太早（在 clock-to-Q 延遲之前就取樣）。要改 tb 時改副本，並記錄理由。
- **SDF annotation 有 error** → 通常是 tb 的 `$sdf_annotate` instance 名稱不對，或 SDF 檔名不對。

## APR（ICC2）

- **重跑 `create_lib` 報 LIB-009、`commit_workspace` 報 FILE-008（already exists）** → 上次的 library 還在。公版在建立前已先 `file delete -force`。
- **APR 報告乾淨，繞線後 PT 的 typical／fast 卻有幾百個 hold／removal 違規（例 fast −0.06 ns，607 個 hold、259 個 removal）** → ICC2 的 typical／fast corner 其實用了 slow library。apr.log 會有 `PVT-030 … 1 voltage, and 1 temperature mismatches`：scenario 的 process／電壓／溫度和 library 對不上，ICC2 就拿別的 library 算，以為 hold 夠了。`set_process_number`、`set_voltage`、`set_temperature` 三個都要設，值和 library 檔頭的 nom_process／nom_voltage／nom_temperature 一致（`common_setup.tcl` 的 CORNERS）。確認方式：apr.log 三個 corner 都是 `no PVT mismatches (PVT-032)`。
- **CTS 後 clock tree 沒有 buffer** → 合成留下的 ideal network／dont_touch 沒解除，CTS 前要 `set_dont_touch_network -clear`、`remove_ideal_network`（公版已加）。
- **繞線後 PT 出現大量 hold／removal 違規，ICC2 卻沒報** → ICC2 裡的 I/O delay 比 SDC 鬆。CTS 後重設的 I/O delay 要用和 SDC 同一組數字（公版沿用 `IN_MIN` 等變數；實測多寫 0.2 ns 就漏修 619 個 removal）。
- **apr.log 有 `OPT-200 No tie cell is available for constant fixing`，繞線後 netlist 沒有 TIEH／TIEL** → SAED32 的 `TIEH_RVT`／`TIEL_RVT` 在 library 裡是 `dont_use`、`dont_touch`，`add_tie_cells` 一顆都插不進去，只印 warning，常數 1／0 直接接到電源軌。只做核心時 LVS 還是會過，所以很容易漏掉；但業界做法是閘極不直接接電源（防 ESD）。`add_tie_cells` 前先用 `set_attribute [get_lib_cells */TIE*_RVT] dont_use false`（`dont_touch` 同樣）解除（用 `set_dont_use … false` 會報 CMD-012）。確認方式：apr.log 沒有 OPT-200 warning，繞線後 netlist 有 TIEH_RVT／TIEL_RVT。
- **LVS 的 VDD 斷成好幾十段，`check_pg_connectivity` 顯示 floating wires** → M1 rail 到 M6 的 via 沒補（公版第 4 步已補）。
- **`check_routes` 還剩少數 short／spacing，`route_detail -incremental` 也清不掉（例 3 個）** → cell 剛好在電源條正下方，電源條往下的 via 佔掉走線空間。`apr_eco.tcl` 第 2 步會處理；少量時也可以手動修：
  ```tcl
  # 1. 從 check_routes 或 GUI（Error Browser）找出違規的 net，拆掉重繞
  remove_routes -nets [get_nets <net>] -detail_route -global_route
  route_eco -nets [get_nets <net>]
  route_detail -incremental true -initial_drc_from_input true
  # 2. 還在的話，把相連的 cell 移開電源條約 2 um 再重繞（clock net 也要一起重繞）
  set_cell_location -coordinates {<x> <y>} [get_cells <cell>]
  legalize_placement -cells [get_cells <cell>]
  ```
- **`report_constraints` 還有 max_capacitance／max_transition 違規** → `route_opt` 不一定修得掉（例：REFRACT 的乘法器 FA cell，上限 8 fF、實際 15 fF，約 50 個）。跑 `apr_eco.tcl`：依負載在 driver 後插 buffer。擠的區域不要把 cell 換大顆：會推擠旁邊的 cell，繞線 DRC 反而變多（例：換大顆後 DRC 從 2 個變 52 個）。只有幾個時也可以手動：
  ```tcl
  # 換大一點的 cell（SAED32 的 X0 和 X1 max_cap 一樣，要直接換 X2 以上）
  size_cell [get_cells <cell>] [get_lib_cells */NAND2X2_RVT]
  # 或在推太多負載的 pin 後面插 buffer（依負載挑 X4/X8/X16）
  insert_buffer [get_pins <cell>/<out_pin>] [get_lib_cells */NBUFFX8_RVT]
  legalize_placement -incremental
  route_eco
  route_detail -incremental true -initial_drc_from_input true
  ```
- **`save_block -as X` 之後，指令還在改舊的 block** → `save_block -as` 不會切換 block，要再 `open_block X`。
- **report_timing 把每個 scenario 都列出來** → 加 `-scenarios [get_scenarios func_slow]`。

## DRC／LVS

- **DRC `M1.W.2.1`（M1 細條，寬度 < 0.06 um）** → 繞線在 cell pin 旁邊留下細條。在同一條 net 上畫一塊 M1，蓋住「pin ∪ 錯誤區」，細條就併成寬金屬。`apr_m1_patch.tcl` 會讀錯誤檔逐一處理；一兩個時也可以手動：
  ```tcl
  open_block routed
  get_objects_by_location -classes pin -intersect {{x1 y1} {x2 y2}}   ;# 找到錯誤旁的 pin
  create_shape -shape_type rect -layer M1 -net [get_nets <net>] -boundary {{llx lly} {urx ury}}
  save_block
  ```
  修完重跑 `apr_finish.tcl`（重新匯出 GDS）和 DRC。錯誤座標一定要來自目前這份 GDS 的 DRC 結果，用舊的會畫錯地方。
- **SAED32 原始 LVS runset 直接用失敗** → 它是範例設定，`run_lvs.sh` 已用 sed 產生專案副本。
- **`icv_nettran: unknown option -sp-dollarPins`** → 新版預設就有，拿掉這個選項。
- **LVS 找不到 port** → GDS 匯出的 layer map 不對（SAED32 用 `saed32nm_1p9m_gdsout_mw.map`）。

## 繞線後 STA

- **max_capacitance／max_transition 小幅超標（例 16.38 fF > 16 fF，REFRACT 實測 slow 19 個）** → StarRC 的 Cmax 比 ICC2 的估計多幾 %，ICC2 自己的報告看不到。把 `apr_eco.tcl` 的 `FROM_PT` 設成 1（讀 PT 的報告）再跑一次，之後重跑 apr_finish → DRC（必要時 M1 補丁）→ LVS → StarRC → 繞線後 STA。
- **PT 報告還有 1 個違規，`apr_eco.tcl`（`FROM_PT 1`）卻說 `0 violating pins`** → 違規很小時 PT 印成 `(VIOLATED: increase significant digits)`（例：transition 0.0844 ns，上限 0.0844 ns），只比對 `(VIOLATED)` 會漏掉。公版比對到 `(VIOLATED` 為止。
- **只有 fast corner hold 差幾 ps（例 −0.003 ns）** → ICC2 估計 RC 時剛好過，StarRC 的 Cmin 更快。回 ICC2 在違規的 endpoint（FF 的 D pin）前插一顆小 buffer：
  ```tcl
  insert_buffer [get_pins <reg>/D] [get_lib_cells */NBUFFX2_RVT]
  ```
  差得多時改用延遲 cell（SAED32 `DELLN1X2_RVT`）。插在資料路徑上會吃掉 setup slack，先確認 slow corner 的 setup 夠寬。
- **StarRC 金屬溫度** → 沒有設定時是 25°C，報告要註明。
