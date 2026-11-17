##############################################################################
# fm_rtl2gate.tcl — Function 驗證（Formality）：確認合成 netlist 的功能和 RTL 一樣
# 執行：mkdir -p work/fm && cd work/fm && fm_shell -f ../../scripts/fm_rtl2gate.tcl | tee fm.log
#   reference（r:）= RTL，implementation（i:）= netlist，SVF 告訴 Formality DC 改了哪些名字
#
# 【要改的地方】
#   通常不用改：DESIGN、RTL_FILES、SVF 都從 common_setup.tcl 來
#   SystemVerilog 的 RTL：read_verilog 改 read_sverilog
#
# 【跑完看什麼】
#   fm.log 的 Verification SUCCEEDED；failing points = 0
#   失敗時看 reports/failing.rpt、reports/unmatched.rpt：
#     unmatched 很多 → 通常是 SVF 沒讀到，或合成用了 compile_ultra 重組
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
file mkdir reports

set synopsys_auto_setup true          ;# 照 DC 的設定解讀 RTL
# DesignWare 元件（+、* 等）要 DC 的安裝路徑才能展開
if {![catch {exec which dc_shell} dc]} {set_app_var hdlin_dwroot [file dirname [file dirname $dc]]}

set_svf $SVF
read_db -technology_library [file join $LIB_DIR $LIB_SLOW.db]

read_verilog -r $RTL_FILES
set_top r:/WORK/$DESIGN

read_verilog -i $NETLIST
set_top i:/WORK/$DESIGN

match
redirect reports/unmatched.rpt {report_unmatched_points}
if {[verify]} {
    redirect reports/passing.rpt {report_passing_points}
} else {
    redirect reports/failing.rpt {report_failing_points}
    redirect reports/aborted.rpt {report_aborted_points}
}
exit
