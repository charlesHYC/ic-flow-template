# ic-flow-template

數位 IC（cell-based）設計流程的公版腳本，從 RTL 到 GDS，每個階段一份 `.tcl`／`.sh`。

給學習者用：把公版複製到自己的專案，照每個檔頭的【要改的地方】修改，自己執行，再照【跑完看什麼】讀報告、判斷有沒有通過。公版刻意不做一鍵跑完，看懂每一步、從報告找問題、決定下一步，是這個流程要練的。

它同時是一個標準格式的 skill（`SKILL.md` 加上腳本），支援 skill 的 AI 程式助手可以照這份內容回答流程問題、幫忙看腳本。

## 流程

| # | 階段 | 工具 | 公版 | 怎樣算通過 |
|---|---|---|---|---|
| 1 | RTL 模擬 | VCS | `01_rtl_sim/run_rtl_sim.sh` | tb 印出 PASS，mismatch = 0 |
| 2 | 邏輯合成 | Design Compiler | `02_syn/dc_syn.tcl`、`constraints.sdc` | setup slack ≥ 0，沒有 VIOLATED |
| 3 | 等價驗證 | Formality | `03_fm/fm_rtl2gate.tcl` | `Verification SUCCEEDED` |
| 4 | 佈局前 STA | PrimeTime | `04_sta/pt_sta.tcl` | 三個 corner slack ≥ 0，沒有 VIOLATED |
| 5 | 閘級模擬 | VCS + SDF | `05_gate_sim/run_gate_sim.sh` | 功能 PASS、SDF 0 error、沒有 timing violation |
| 6-0 | 建 NDM | ICC2 lm_shell | `06_apr/build_ndm.tcl` | 沒有 Error（同一製程只要建一次） |
| 6 | APR | IC Compiler II | `06_apr/apr.tcl` | 0 繞線 DRC／open、電源沒浮接、沒有 VIOLATED |
| 6-E | APR ECO（需要時） | IC Compiler II | `06_apr/apr_eco.tcl` | 0 繞線 DRC、沒有 VIOLATED |
| 6-1 | APR 收尾 | IC Compiler II | `06_apr/apr_finish.tcl` | GDS、netlist 有產生，仍是 0 DRC |
| 7a | DRC | IC Validator | `07_drc_lvs/run_drc.sh` | `RESULTS: CLEAN` |
| 7a-E | M1 補丁（需要時） | IC Compiler II | `06_apr/apr_m1_patch.tcl` | 重跑 6-1 與 7a 後 CLEAN |
| 7b | LVS | IC Validator | `07_drc_lvs/run_lvs.sh` | `Final comparison result:PASS` |
| 8 | 寄生萃取 | StarRC | `08_pex/run_starrc.sh` | 三個 corner 的 SPEF 有產生 |
| 9a | 繞線後 STA | PrimeTime | `09_postroute/pt_postroute.tcl` | 三個 corner slack ≥ 0，沒有 VIOLATED |
| 9b | 繞線後等價驗證 | Formality | `09_postroute/fm_postroute.tcl` | `Verification SUCCEEDED` |
| 9c | 繞線後閘級模擬 | VCS + SDF | `05_gate_sim/run_gate_sim.sh`（`POSTROUTE=1`） | 同第 5 步 |

公版都在 `templates/` 底下。標「需要時」的兩個階段由你看過報告後自己決定要不要跑：

- **6-E APR ECO**：APR 報告還有 max_capacitance／max_transition 違規時跑（`FROM_PT 0`，讀 ICC2 的報告）。繞線後 STA（9a）才發現小幅超標時，改成 `FROM_PT 1`（讀 PT 的報告）再跑一次，之後從 6-1 重跑到 9a。
- **7a-E M1 補丁**：DRC 只剩 M1 太細的錯誤時跑，之後重跑 6-1 與 7a。

每個階段在做什麼、為什麼要做，見 `SKILL.md`；遇到錯誤先查 `references/pitfalls.md`；縮寫對照在 `references/glossary.md`；想加 IO PAD 做成完整晶片，見 `references/pad.md`。

## 安裝與使用

```bash
git clone https://github.com/charlesHYC/-ic-flow-template.git
```

1. 把 `templates/` 底下的檔案複製到自己專案的 `scripts/`。
2. 先改 `common_setup.tcl`（top 名稱、RTL 檔案、clock、週期、PDK 路徑），再依序改每個階段檔頭標示的地方。
3. 一個階段一個階段執行（每支腳本檔頭的【執行】寫了指令），每一步都看報告確認通過再往下。

當成 skill 使用時，把整個 repo 放到 AI 助手讀取 skill 的目錄，例如：

```bash
git clone https://github.com/charlesHYC/-ic-flow-template.git ~/.claude/skills/ic-flow-template
```

## 檔案結構

```
SKILL.md                            流程總覽、每階段的通過標準、回答原則
templates/
  common_setup.tcl                  共用設定（所有 tcl 第一行 source）
  01_rtl_sim/run_rtl_sim.sh
  02_syn/dc_syn.tcl  constraints.sdc
  03_fm/fm_rtl2gate.tcl
  04_sta/pt_sta.tcl
  05_gate_sim/run_gate_sim.sh       佈局前；POSTROUTE=1 為繞線後
  06_apr/build_ndm.tcl  apr.tcl  apr_eco.tcl  apr_finish.tcl  apr_m1_patch.tcl
  07_drc_lvs/run_drc.sh  run_lvs.sh
  08_pex/run_starrc.sh
  09_postroute/pt_postroute.tcl  fm_postroute.tcl
references/
  pitfalls.md                       常見錯誤與手動修法
  glossary.md                       縮寫與名詞對照
  pad.md                            IO PAD 說明（公版不含 PAD 腳本，這份說明要自己做時怎麼做）
```

## 需求與限制

- Synopsys 工具：VCS、Design Compiler、Formality、PrimeTime、IC Compiler II、IC Validator、StarRC。
- 製程預設 SAED32 EDK（RVT，三個 corner）。PDK 路徑寫在 `common_setup.tcl` 與幾支 `.sh` 的檔頭，請改成自己環境的位置。製程檔不包含在這個 repo 裡。
- 只做核心，不含 IO PAD 的腳本；PAD 的觀念與做法見 `references/pad.md`。完整可以跑的 PAD 流程在 [IC_flow_skill](https://github.com/charlesHYC/IC_flow_skill)。
- CBDK_IC_Contest 製程的改法寫在 `SKILL.md`，但沒有實際跑過。

## 驗證狀態

2026-11-17 用 REFRACT（2026 IC Contest 題目，SAED32、clock 50 ns）照上面的順序一個階段一個階段跑完，每個階段都通過：

- DRC `RESULTS: CLEAN`（M1 補丁 1 輪）、LVS `Final comparison result:PASS`。
- 繞線後 STA 三個 corner 沒有 VIOLATED：setup slow／typical／fast = +36.17／+42.10／+45.69 ns，hold +0.223／+0.088／+0.004 ns（APR ECO 先用 `FROM_PT 0` 跑 1 輪；繞線後 STA 還有小幅 max_cap／transition 超標，再用 `FROM_PT 1` 修 2 輪，分別插 15 顆、1 顆 buffer）。
- 繞線後 Formality `Verification SUCCEEDED`、slow／fast 繞線後閘級模擬 PASS。
- tie cell 有插入（繞線後 netlist 有 `TIEL_RVT`）。

這次驗證找到並修正兩個公版問題，寫在 `references/pitfalls.md`：

- `apr.tcl`：SAED32 的 TIEH／TIEL 是 dont_use、dont_touch，原本 `add_tie_cells` 一顆都插不進去（OPT-200）。
- `apr_eco.tcl`：PT 把很小的違規印成 `(VIOLATED: increase significant digits)`，原本讀不到，會漏修。

## 授權

MIT License，見 `LICENSE`。
