#!/usr/bin/env bash
##############################################################################
# run_rtl_sim.sh — RTL 模擬（VCS）：確認 RTL 功能正確，這是之後每一步的基準
# 執行：mkdir -p work/rtl_sim && cd work/rtl_sim && bash ../../scripts/run_rtl_sim.sh
#
# 【要改的地方】
#   1. DESIGN、RTL：和 common_setup.tcl 一致
#   2. TB、TB_TOP  ：你的 testbench 與它的 top module 名稱
#   3. PATTERNS    ：tb 用相對路徑讀的測資，會複製到執行目錄
#   4. DEFINES     ：tb 需要的 define，例 "+define+P1"（題目有多組測資時常用）
#   5. 用到 DesignWare 元件時，在 vcs 那行加 -y $SYNOPSYS/dw/sim_ver +libext+.v
#
# 【跑完看什麼】
#   simulation.log：tb 印出的 PASS 訊息、mismatch 數 = 0
#   compile.log   ：沒有 Error；Lint warning 要看懂（寬度不符、未接的 port）
#   波形：tb 有 $fsdbDumpvars 就用 verdi -ssf *.fsdb 看
##############################################################################
set -eo pipefail
PROJ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

DESIGN=MY_TOP                         # ← top module
RTL="$PROJ/rtl/$DESIGN.v"             # ← RTL 檔案，多個用空白分開
TB=$PROJ/tb/tb.v                      # ← testbench
TB_TOP=testfixture                    # ← testbench 的 top module
PATTERNS="$PROJ/tb/*.dat"             # ← 測資（沒有就留空）
DEFINES=""                            # ← 例 "+define+P1"

for p in $PATTERNS; do cp -r "$p" .; done
vcs -full64 -sverilog -debug_access+all -timescale=1ns/10ps \
    "$TB" $RTL $DEFINES -top "$TB_TOP" -o simv -l compile.log
./simv -l simulation.log
