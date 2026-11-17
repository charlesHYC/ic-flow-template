##############################################################################
# fm_postroute.tcl — 繞線後等價驗證（Formality）：RTL vs 繞線後 netlist
# 執行：mkdir -p work/fm_post && cd work/fm_post && fm_shell -f ../../scripts/fm_postroute.tcl | tee fm.log
#   APR 會插 buffer、tie cell、建 clock tree；要確認功能沒有被改壞。沿用 DC 的 SVF 對名字
#
# 【要改的地方】
#   通常不用改（同 fm_rtl2gate.tcl）
#
# 【跑完看什麼】
#   fm.log 的 Verification SUCCEEDED；failing points = 0
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
file mkdir reports

set synopsys_auto_setup true
if {![catch {exec which dc_shell} dc]} {set_app_var hdlin_dwroot [file dirname [file dirname $dc]]}
set_svf $SVF
read_db -technology_library [file join $LIB_DIR $LIB_SLOW.db]

read_verilog -r $RTL_FILES
set_top r:/WORK/$DESIGN
read_verilog -i $ROUTED_V                       ;# 不含電源與 filler 的版本
set_top i:/WORK/$DESIGN

match
redirect reports/unmatched.rpt {report_unmatched_points}
if {[verify]} {
    redirect reports/passing.rpt {report_passing_points}
} else {
    redirect reports/failing.rpt {report_failing_points}
}
exit
