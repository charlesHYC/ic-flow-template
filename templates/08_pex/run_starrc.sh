#!/usr/bin/env bash
##############################################################################
# run_starrc.sh — 寄生萃取 PEX（StarRC）：從繞線結果算出每條線實際的 R、C，寫成 SPEF
# 執行：mkdir -p work/pex && cd work/pex && bash ../../scripts/run_starrc.sh
#   每個 corner 一份 SPEF：slow → Cmax、typical → nominal、fast → Cmin（和 APR 的 RC 模型一致）
#   APR 裡的 RC 是估計值；這裡的才是 signoff 用的
#
# 【要改的地方】
#   1. DESIGN：和 common_setup.tcl 一致
#   2. STARXTRACT：StarRC 執行檔位置（PATH 裡找不到時才改）
#   3. 要指定金屬溫度時，在 extract.cmd 加 OPERATING_TEMPERATURE（沒加是 25C）
#
# 【跑完看什麼】
#   <corner>/${DESIGN}.spef 有產生且不是空的；<corner>/extract.log 沒有 Error
##############################################################################
set -eo pipefail
PROJ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

DESIGN=MY_TOP                                   # ← top module
NDM=$PROJ/work/apr/$DESIGN.ndm
RC_DIR=/mnt/nfs/opt/PROCESS/SAED32_EDK/tech/star_rcxt
STARXTRACT=${STARXTRACT:-$(command -v StarXtract || echo /mnt/nfs/opt/EDA/synopsys/star-rcxt/cur/bin/StarXtract)}

for corner in slow typical fast; do
  case $corner in slow) rc=Cmax;; typical) rc=nominal;; fast) rc=Cmin;; esac
  mkdir -p $corner
  cat > $corner/extract.cmd <<CMD
BLOCK: routed
NDM_DATABASE: $NDM
TCAD_GRD_FILE: $RC_DIR/saed32nm_1p9m_${rc}.nxtgrd
MAPPING_FILE: $RC_DIR/saed32nm_tf_itf_tluplus.map
EXTRACTION: RC
NETS: *
POWER_NETS: VDD VSS
COUPLE_TO_GROUND: NO
NETLIST_FORMAT: SPEF
NETLIST_FILE: $DESIGN.spef
CMD
  (cd $corner && "$STARXTRACT" extract.cmd > extract.log 2>&1)
  ls -l $corner/$DESIGN.spef
done
