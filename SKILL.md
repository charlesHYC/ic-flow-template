---
name: ic-flow-template
description: 數位 IC（cell-based）設計流程的公版腳本：RTL 模擬、DC 合成、Formality、PrimeTime STA、Gate-level sim、ICC2 APR、ICV DRC/LVS、StarRC、繞線後 STA，每個階段一份 .tcl／.sh，檔頭寫清楚要改哪裡、為什麼、跑完看哪份報告。給學習者複製後自己修改、自己執行、自己判斷結果；不做一鍵自動化。當使用者問數位 IC flow 某個階段怎麼做、要一份 dc_shell／pt_shell／fm_shell／icc2_shell／ICV／StarRC 腳本、問下一步是什麼，或問某個階段的錯誤怎麼修時使用。
---

# 數位 IC 設計流程公版

這個 skill 提供一套專業數位 IC（cell-based）設計流程每個階段的公版腳本。使用者把公版複製到自己的專案，照檔頭的【要改的地方】修改，自己執行，再照【跑完看什麼】讀報告、判斷有沒有通過。

公版刻意不做一鍵跑完：看懂每一步在做什麼、從報告找出問題、決定下一步，是這個流程要練的。標「需要時」的兩個 ECO 階段（`apr_eco.tcl`、`apr_m1_patch.tcl`）由使用者看過報告後自己決定要不要跑。

## 流程與公版

| # | 階段 | 解決什麼問題 | 工具 | 公版 | 輸入 → 輸出 | 怎樣算通過 |
|---|---|---|---|---|---|---|
| 1 | RTL 模擬 | RTL 功能對不對 | VCS（Verdi 看波形） | `01_rtl_sim/run_rtl_sim.sh` | RTL、tb → log、波形 | tb 印出 PASS，mismatch = 0 |
| 2 | 邏輯合成 | RTL 轉成 gate-level netlist，並滿足時序 | Design Compiler | `02_syn/dc_syn.tcl`、`constraints.sdc` | RTL、SDC、.db → netlist、SDF、SVF | setup slack ≥ 0，constraint 報告沒有 VIOLATED |
| 3 | Function 驗證 | netlist 的功能和 RTL 是否一樣 | Formality | `03_fm/fm_rtl2gate.tcl` | RTL、netlist、SVF → 比對報告 | `Verification SUCCEEDED` |
| 4 | 佈局前 STA | 每個 corner 的 setup／hold | PrimeTime | `04_sta/pt_sta.tcl` | netlist、SDC → 時序報告、SDF | 三個 corner slack ≥ 0，沒有 VIOLATED |
| 5 | Gate-level sim | 加上 cell 延遲後功能還對不對 | VCS + SDF | `05_gate_sim/run_gate_sim.sh` | netlist、SDF、tb → log | 功能 PASS、SDF 0 error、沒有 timing violation |
| 6-0 | 建 NDM | 把 cell 資料轉成 ICC2 的格式 | ICC2 lm_shell | `06_apr/build_ndm.tcl` | .db、LEF → NDM | 沒有 Error（同一製程只要建一次） |
| 6 | APR | 擺放、電源、clock tree、繞線 | IC Compiler II | `06_apr/apr.tcl` | netlist、NDM、SDC → routed block | 0 繞線 DRC／open、電源沒浮接、沒有 VIOLATED |
| 6-E | APR ECO（需要時） | 修 route_opt 沒修掉的 max_cap／transition 與繞線 DRC | IC Compiler II | `06_apr/apr_eco.tcl` | routed block → 修正後的 routed block | 0 繞線 DRC、沒有 VIOLATED |
| 6-1 | APR 收尾 | filler、匯出 GDS 與 netlist | IC Compiler II | `06_apr/apr_finish.tcl` | routed block → GDS、netlist | 檔案有產生，仍是 0 DRC |
| 7a | DRC | layout 幾何規則 | IC Validator | `07_drc_lvs/run_drc.sh` | GDS → 錯誤清單 | `RESULTS: CLEAN` |
| 7a-E | M1 補丁（需要時） | 修 DRC 的 M1 細條 | IC Compiler II | `06_apr/apr_m1_patch.tcl` | DRC 錯誤檔 → 修正後的 block | 之後重跑 6-1 與 7a 要 CLEAN |
| 7b | LVS | layout 和 netlist 是同一個電路 | IC Validator | `07_drc_lvs/run_lvs.sh` | GDS、netlist → 比對結果 | `Final comparison result:PASS` |
| 8 | 寄生萃取 | 算出繞線實際的 R、C | StarRC | `08_pex/run_starrc.sh` | routed block → SPEF ×3 corner | SPEF 有產生，log 沒有 Error |
| 9a | 繞線後 STA | 用實際 RC 再檢查時序 | PrimeTime | `09_postroute/pt_postroute.tcl` | routed netlist、SPEF → 報告、SDF | 三個 corner slack ≥ 0，沒有 VIOLATED；小幅 max_cap 超標時用 `apr_eco.tcl`（`FROM_PT 1`）修，再從 6-1 重跑 |
| 9b | 繞線後 Function 驗證 | APR 有沒有改壞功能 | Formality | `09_postroute/fm_postroute.tcl` | RTL、routed netlist → 比對報告 | `Verification SUCCEEDED` |
| 9c | 繞線後 Gate-level sim | 實際延遲下功能還對不對 | VCS + SDF | `05_gate_sim/run_gate_sim.sh`（`POSTROUTE=1`） | routed netlist、繞線後 SDF → log | 同第 5 步 |

比賽（例如 IC Contest）通常只做到第 5 步；6～9 是延伸成完整晶片流程。回答前先確認使用者要做到哪一步。

`templates/common_setup.tcl` 是所有 tcl 共用的設定（top 名稱、RTL 清單、library 路徑、corner）；`.sh` 腳本檔頭各自有 `DESIGN` 等變數，要和它一致。

## 怎麼使用

1. 專案目錄：
   ```
   <proj>/rtl/       RTL
   <proj>/tb/        testbench、測資
   <proj>/scripts/   把 templates/ 底下所有檔案複製到這裡（同一層）
   <proj>/work/      每個階段在 work/<階段>/ 執行
   ```
2. 先改 `common_setup.tcl`（`DESIGN`、`RTL_FILES`）和 `constraints.sdc`（clock、I/O delay、負載）。
3. 一個階段一個階段做：照該腳本檔頭的【執行】指令跑，再照【跑完看什麼】讀報告。通過了才往下一步；沒過就查 `references/pitfalls.md`，修完重跑這一步。
4. 換一個設計時，只有標 `←` 的值一定要改；其他設定第一次先用預設，報告有問題再調整。

## 回答時的原則

- **給公版，並說清楚要改哪裡**：使用者問某一步怎麼做時，給對應的公版，指出【要改的地方】每一項在他的設計裡該填什麼、去哪裡找這個值（題目、RTL、上一步的報告）。值由使用者自己決定；他填錯時（例如單位錯、和題目矛盾）要指出來並解釋。
- **教使用者讀報告**：說明要看哪份報告的哪一行、數字代表什麼。不要只說「通過了」或「失敗了」。
- **修違規時給指令，讓使用者自己下**：從 `references/pitfalls.md` 找對應的手動修法，說明為什麼這樣修。
- **通過要看報告內容**：工具 exit 0 不等於通過。
- **說清楚驗證範圍**：ICC2 裡的 RC 是估計值，signoff 要用 StarRC；佈局前 STA 用 wire-load 估線延遲，fast corner 常偏悲觀。沒做的階段不能說成完成。
- **單位跟著 library 走**：SAED32 是 ns／fF／MΩ，CBDK 是 ns／pF／kΩ。換製程先 `report_units`。
- **不修改 PDK 與官方檔案**：要調整就在工具記憶體內或專案副本處理。
- **縮寫第一次出現附上全名與白話**，例如「LVS（Layout Versus Schematic，比對版圖和電路圖）」。縮寫表在 `references/glossary.md`。
- **解釋一個階段的順序**：這一步解決什麼問題 → 怎麼做 → 怎麼確認做對了 → 省略會怎樣。

## 製程

公版以 SAED32 EDK（RVT，三個 corner：ss0p95v125c／tt1p05v25c／ff1p16vn40c）為預設。

換成 IC Contest 的 CBDK_IC_Contest_v2.5 時，要改這幾處：
- `common_setup.tcl`：library 改成 `slow.db`，三個 corner 都指向它，wire-load 改成 `tsmc13_wl10`。
- `constraints.sdc`：單位改成 pF／kΩ，例如 `set_load 1` = 1 pF、`set_drive 0.1` = 100 Ω。
- `dc_syn.tcl`：target 與 link 都只放 `slow.db`，`set_operating_conditions -max slow -max_library slow`。
- CBDK 沒有完整的實體資料，6～9 步只能用 SAED32 做。

IO PAD（全晶片）不在這套公版內；加 PAD 會影響每一步（延遲、負載、die 大小、DRC／LVS），屬於進階題目。使用者問 PAD（是什麼、製程給什麼、怎麼選、要多做哪些步驟、怎麼確認、corner pad）時，照 `references/pad.md` 回答。

## 檔案地圖

```
templates/
  common_setup.tcl                     共用設定（所有 tcl 第一行 source）
  01_rtl_sim/run_rtl_sim.sh
  02_syn/dc_syn.tcl  constraints.sdc
  03_fm/fm_rtl2gate.tcl
  04_sta/pt_sta.tcl
  05_gate_sim/run_gate_sim.sh          佈局前；POSTROUTE=1 為繞線後
  06_apr/build_ndm.tcl  apr.tcl  apr_eco.tcl  apr_finish.tcl  apr_m1_patch.tcl
  07_drc_lvs/run_drc.sh  run_lvs.sh
  08_pex/run_starrc.sh
  09_postroute/pt_postroute.tcl  fm_postroute.tcl
references/
  pitfalls.md   常見錯誤與手動修法
  glossary.md   縮寫與名詞對照
  pad.md        IO PAD 說明（公版不含 PAD 腳本，這份說明要自己做時怎麼做）
```
