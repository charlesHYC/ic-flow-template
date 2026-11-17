#!/usr/bin/env bash
##############################################################################
# run_gate_sim.sh — 閘級模擬（VCS + SDF）：用合成 netlist 加上 cell 延遲再模擬一次
# 執行（每個 corner 一個目錄）：mkdir -p work/gate_slow && cd work/gate_slow && bash ../../scripts/run_gate_sim.sh slow
#   參數是 corner：slow 用 max 延遲（看 setup）、fast 用 min 延遲（看 hold），兩個都要跑
#   fast 同理（work/gate_fast）；繞線後在 work/gate_post_slow 等目錄跑：POSTROUTE=1 bash ../../scripts/run_gate_sim.sh slow
#
# 【要改的地方】
#   1. DESIGN、TB、TB_TOP、PATTERNS、DEFINES：和 run_rtl_sim.sh 一樣
#   2. tb 要能讀 SDF：tb 裡要有類似下面這段（比賽的 tb 通常已經有，用 `ifdef SDF 包起來）
#        `ifdef SDF
#          initial $sdf_annotate(`SDFFILE, u_dut);
#        `endif
#      SDFFILE 指到這裡複製出來的 ${DESIGN}_syn.sdf；u_dut 換成 tb 裡 DUT 的 instance 名稱
#
# 【跑完看什麼】
#   simulation.log：功能 PASS（和 RTL 模擬一樣）；沒有 timing violation（$setuphold、$recrem、$width）
#   compile.log   ：SDF annotation「Total errors: 0」
#     SDF warning 要逐一看懂。SAED32 已知可接受的：
#       SDFCOM_CFTC ... $removal：cell model 沒有 removal check，每個非同步 reset 的 DFF 一個
#       SDFCOM_IWSBA：跨階層的 INTERCONNECT，VCS 說延遲仍會註入
##############################################################################
set -eo pipefail
PROJ=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CORNER=${1:-slow}

DESIGN=MY_TOP                         # ← top module
TB=$PROJ/tb/tb.v                      # ← testbench
TB_TOP=testfixture                    # ← testbench 的 top module
PATTERNS="$PROJ/tb/*.dat"             # ← 測資
DEFINES=""                            # ← 例 "+define+P1"
CELL_MODEL=/mnt/nfs/opt/PROCESS/SAED32_EDK/lib/stdcell_rvt/verilog/saed32nm.v

if [ "${POSTROUTE:-0}" = 1 ]; then
  NETLIST=$PROJ/work/apr/${DESIGN}_routed.v
  SDF=$PROJ/work/postroute/${DESIGN}_postroute_${CORNER}.sdf
else
  NETLIST=$PROJ/work/syn/${DESIGN}_syn.v
  SDF=$PROJ/work/sta/${DESIGN}_${CORNER}.sdf
fi
case $CORNER in slow) DELAY=+maxdelays;; fast) DELAY=+mindelays;; *) DELAY=+typdelays;; esac

for p in $PATTERNS; do cp -r "$p" .; done
cp "$SDF" ${DESIGN}_syn.sdf                    # tb 常用固定檔名讀 SDF
# +neg_tchk：允許負的 setup/hold 值；+sdfverbose：列出所有 SDF warning
vcs -full64 -sverilog -debug_access+all +neg_tchk $DELAY +sdfverbose \
    "$TB" "$NETLIST" -v "$CELL_MODEL" +define+SDF $DEFINES -top "$TB_TOP" -o simv -l compile.log
./simv -l simulation.log
