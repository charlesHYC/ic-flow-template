#!/usr/bin/env bash
##############################################################################
# run_lvs.sh — LVS（IC Validator）：比對 layout 萃取出的電路和 netlist 是不是同一個電路
# 執行：mkdir -p work/lvs && cd work/lvs && bash ../../scripts/run_lvs.sh
# 流程：含電源的 netlist ＋ cell 的 CDL ──icv_nettran──> SPICE schematic ──icv──> 和 GDS 比對
#
# 【要改的地方】
#   1. DESIGN：和 common_setup.tcl 一致
#   2. PDK、CDL、RUNSET_SRC：換製程才改
#   3. SAED32 原始 LVS runset 是範例設定，不能直接用；下面用 sed 產生專案副本（PDK 檔案不動）：
#        library_name／cell 改成本設計、schematic 指到 schematic.sp、
#        修正新版 ICV 不接受的型別名與字串尾端空白
#
# 【跑完看什麼】
#   ${DESIGN}.LVS_ERRORS：「Final comparison result:PASS」
#   失敗時同一個檔案會列出對不上的 net／device；先看 VDD／VSS 有沒有斷開（power rail 浮接）
##############################################################################
set -eo pipefail
PROJ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

DESIGN=MY_TOP                                   # ← top module
PDK=/mnt/nfs/opt/PROCESS/SAED32_EDK
GDS=$PROJ/work/apr/$DESIGN.gds
NETLIST_PG=$PROJ/work/apr/${DESIGN}_routed_pg.v  # 一定要用含電源與 filler 的版本
CDL=$PDK/lib/stdcell_rvt/lvs/saed32nm_rvt.cdl
RUNSET_SRC=$PDK/tech/icv_lvs/saed32nm_1p9m_lvs_rules.rs
export SAED32_PATH=$PDK
export LD_PRELOAD=/usr/lib64/libkrb5support.so.0  # 遇到 ICV 啟動錯誤才需要

# 專案用的 runset 副本
sed -e "s#library_name= \"CELLNAME.gds\",#library_name= \"$GDS\",#" \
    -e "s#^cell= \"resistor\"#cell= \"$DESIGN\"#" \
    -e 's#xref_db_h:handle;#xref_db_h:xref_database_handle;#' \
    -e 's#schematic_file    = {{filename = "[^"]*func.rs", format = SPICE}}#schematic_file    = {{filename = "schematic.sp", format = SPICE}}#' \
    -e 's#tagname="subtie_scon "#tagname="subtie_scon"#' \
    -e 's#tagname="ndores "#tagname="ndores"#' \
    "$RUNSET_SRC" > lvs.rs

icv_nettran -outType SPICE -verilog "$NETLIST_PG" -sp "$CDL" -outName schematic.sp > nettran.log 2>&1
icv -vue -i "$GDS" -c "$DESIGN" -s schematic.sp -stc "$DESIGN" -sf SPICE -host_init 2 lvs.rs > icv_lvs.log 2>&1 || true
grep 'Final comparison result' "$DESIGN.LVS_ERRORS"
