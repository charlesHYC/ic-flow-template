# ic-flow-template

數位 IC（cell-based）設計流程的公版腳本，從 RTL 到 GDS，每個階段一份 `.tcl`／`.sh`。

給學習者用：把公版複製到自己的專案，照每個檔頭的【要改的地方】修改，自己執行，再照【跑完看什麼】讀報告、判斷有沒有通過。公版刻意不做一鍵跑完，看懂每一步、從報告找問題、決定下一步，是這個流程要練的。

它同時是一個標準格式的 skill（`SKILL.md` 加上腳本），支援 skill 的 AI 程式助手可以照這份內容回答流程問題、幫忙看腳本。

## 流程

| # | 階段 | 工具 | 公版 |
|---|---|---|---|
| 1 | RTL 模擬 | VCS | `templates/01_rtl_sim/run_rtl_sim.sh` |
| 2 | 邏輯合成 | Design Compiler | `templates/02_syn/dc_syn.tcl`、`constraints.sdc` |
| 3 | 等價驗證 | Formality | `templates/03_fm/fm_rtl2gate.tcl` |
| 4 | 佈局前 STA | PrimeTime | `templates/04_sta/pt_sta.tcl` |
| 5 | 閘級模擬 | VCS + SDF | `templates/05_gate_sim/run_gate_sim.sh` |
| 6 | APR | IC Compiler II | `templates/06_apr/build_ndm.tcl`、`apr.tcl`、`apr_finish.tcl`；需要時 `apr_eco.tcl`、`apr_m1_patch.tcl` |
| 7 | DRC／LVS | IC Validator | `templates/07_drc_lvs/run_drc.sh`、`run_lvs.sh` |
| 8 | 寄生萃取 | StarRC | `templates/08_pex/run_starrc.sh` |
| 9 | 繞線後 STA／等價驗證／模擬 | PrimeTime、Formality、VCS | `templates/09_postroute/pt_postroute.tcl`、`fm_postroute.tcl`；模擬用 `run_gate_sim.sh`（`POSTROUTE=1`） |

每個階段做什麼、怎樣算通過，見 `SKILL.md`；遇到錯誤先查 `references/pitfalls.md`；縮寫對照在 `references/glossary.md`。

## 使用方式

1. 把 `templates/` 底下的檔案複製到自己專案的 `scripts/`。
2. 先改 `common_setup.tcl`（top 名稱、RTL 檔案、clock、週期、PDK 路徑），再依序改每個階段檔頭標示的地方。
3. 一個階段一個階段執行，每一步都看報告確認通過再往下。

當成 skill 使用時，把整個 repo 放到 AI 助手讀取 skill 的目錄（例如 `~/.claude/skills/ic-flow-template/`）。

## 需求與限制

- Synopsys 工具：VCS、Design Compiler、Formality、PrimeTime、IC Compiler II、IC Validator、StarRC。
- 製程預設 SAED32 EDK（RVT，三個 corner）。PDK 路徑寫在 `common_setup.tcl` 與幾支 `.sh` 的檔頭，請改成自己環境的位置。
- 只做核心，不含 IO PAD。
- 已用一個 IC Contest 題目在 SAED32 上從頭跑過，每個階段都通過（DRC CLEAN、LVS PASS、繞線後三個 corner 沒有違規）。CBDK_IC_Contest 製程的改法寫在 `SKILL.md`，但沒有實際跑過。

## 授權

MIT License，見 `LICENSE`。
