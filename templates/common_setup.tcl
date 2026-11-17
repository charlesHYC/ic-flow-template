##############################################################################
# common_setup.tcl — 所有 tcl 腳本共用的設定（DC、Formality、PT、ICC2 第一行都會 source 它）
#
# 【要改的地方】
#   1. DESIGN     ：RTL 的 top module 名稱
#   2. RTL_FILES  ：RTL 檔案清單
#   3. PDK 路徑   ：換製程或 PDK 安裝位置不同時才改
#
# 專案目錄的假設（不同的話改 PROJ 下面幾行）：
#   <proj>/rtl/       RTL
#   <proj>/tb/        testbench、pattern
#   <proj>/scripts/   這些公版腳本（從 skill 複製過來）
#   <proj>/work/<階段>/  每個階段在自己的目錄執行，輸出也放在那裡
##############################################################################

# ---- 專案路徑：以本檔位置推算 ----
set PROJ [file normalize [file join [file dirname [info script]] ..]]
set WORK $PROJ/work

# ---- 1. 設計 ----
set DESIGN    MY_TOP                          ;# ← 改成你的 top module
set RTL_FILES [list $PROJ/rtl/$DESIGN.v]      ;# ← 多個檔案就列多個，例 [list $PROJ/rtl/a.v $PROJ/rtl/b.v]

# ---- 2. 製程：SAED32 EDK（RVT，單位 ns / fF / MOhm） ----
set PDK      /mnt/nfs/opt/PROCESS/SAED32_EDK  ;# ← PDK 安裝位置
set LIB_DIR  $PDK/lib/stdcell_rvt/db_nldm
set LIB_SLOW saed32rvt_ss0p95v125c            ;# 最慢：看 setup
set LIB_TYP  saed32rvt_tt1p05v25c
set LIB_FAST saed32rvt_ff1p16vn40c            ;# 最快：看 hold
set WLM      ForQA                            ;# 合成／佈局前 STA 用的 wire-load 模型（在 SS library 裡）

# 實體資料（APR、DRC、LVS、PEX 用）
set TECH_TF  $PDK/tech/milkyway/saed32nm_1p9m_mw.tf
set CELL_LEF $PDK/lib/stdcell_rvt/lef/saed32nm_rvt_1p9m.lef
set CELL_GDS $PDK/lib/stdcell_rvt/gds/saed32nm_rvt_oa.gds
set GDS_MAP  $PDK/tech/milkyway/saed32nm_1p9m_gdsout_mw.map
set TLUP_DIR $PDK/tech/star_rcxt
set TLUP_MAP $TLUP_DIR/saed32nm_tf_itf_tluplus.map

# corner 對照表：名稱 → library、RC 模型、process、電壓、溫度（APR、PT 共用）
# p／v／t 要和 library 檔頭的 nom_process／nom_voltage／nom_temperature 一致：ICC2 靠這三個值
# 挑每個 corner 用哪個 library，對不上就退回用別的 library（見 pitfalls.md「APR」）
set CORNERS [dict create \
    slow    [dict create lib $LIB_SLOW rc Cmax    p 0.99 v 0.95 t 125] \
    typical [dict create lib $LIB_TYP  rc nominal p 1.00 v 1.05 t 25 ] \
    fast    [dict create lib $LIB_FAST rc Cmin    p 1.01 v 1.16 t -40]]

# ---- 各階段產物（下一個階段從這裡讀上一個階段的結果） ----
set NETLIST  $WORK/syn/${DESIGN}_syn.v        ;# 合成 netlist
set SVF      $WORK/syn/${DESIGN}.svf          ;# 給 Formality 的合成轉換紀錄
set SDC      $PROJ/scripts/constraints.sdc    ;# 時序約束，所有工具都讀這一份
set NDM_DIR  $WORK/apr/libs                   ;# ICC2 reference library
set NDM_LIB  $WORK/apr/${DESIGN}.ndm          ;# ICC2 design library
set ROUTED_V    $WORK/apr/${DESIGN}_routed.v      ;# 繞線後 netlist（STA、Formality、模擬用）
set ROUTED_PG_V $WORK/apr/${DESIGN}_routed_pg.v   ;# 含電源與 filler 的 netlist（LVS 用）
set ROUTED_GDS  $WORK/apr/${DESIGN}.gds           ;# 完整 GDS（DRC、LVS 用）

catch {set_host_options -max_cores 4}
