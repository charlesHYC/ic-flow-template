#!/usr/bin/env bash
##############################################################################
# run_drc.sh — DRC（IC Validator）：檢查 layout 有沒有違反製程的幾何規則（寬度、間距…）
# 執行：mkdir -p work/drc && cd work/drc && bash ../../scripts/run_drc.sh
#
# 【要改的地方】
#   1. DESIGN：和 common_setup.tcl 一致
#   2. RUNSET：製程的 DRC 規則檔（換製程才改）
#
# 【跑完看什麼】
#   ${DESIGN}.RESULTS      ：「RESULTS: CLEAN」才算通過
#   ${DESIGN}.LAYOUT_ERRORS：每個錯誤的規則名稱與座標，可以在 ICC2 GUI 用座標找到位置
#   常見的 M1.W.2.1（M1 細條）怎麼修，見 references/pitfalls.md
##############################################################################
set -eo pipefail
PROJ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

DESIGN=MY_TOP                                   # ← top module
GDS=$PROJ/work/apr/$DESIGN.gds
RUNSET=/mnt/nfs/opt/PROCESS/SAED32_EDK/tech/icv_drc/saed32nm_1p9m_drc_rules.rs
# 本機 ICV 與系統 Kerberos 函式庫衝突時需要這行（遇到啟動錯誤才加）
export LD_PRELOAD=/usr/lib64/libkrb5support.so.0

icv -vue -i "$GDS" -c "$DESIGN" -host_init 2 "$RUNSET" > icv_drc.log 2>&1 || true
grep -E 'RESULTS:' "$DESIGN.RESULTS"
