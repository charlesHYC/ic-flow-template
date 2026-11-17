##############################################################################
# pt_postroute.tcl — 繞線後 STA（PrimeTime）：繞線後 netlist ＋ StarRC 的 SPEF
# 執行（每個 corner 跑一次）：
#   mkdir -p work/postroute && cd work/postroute
#   pt_shell -x "set corner slow" -f ../../scripts/pt_postroute.tcl | tee sta_slow.log   （typical、fast 同理）
# 和佈局前 STA 的差別：clock 用實際的 clock tree（propagated）、線延遲用實際 RC、不用 wire-load
# 也會寫出 SDF，給繞線後閘級模擬（POSTROUTE=1 run_gate_sim.sh）
#
# 【要改的地方】
#   通常不用改
#
# 【跑完看什麼】（reports_<corner>/）
#   setup.rpt、hold.rpt：三個 corner 的 slack 都 ≥ 0
#   constraint.rpt     ：沒有 VIOLATED
#   parasitics.rpt     ：每條 net 都有註入 RC（沒註入的會被當成理想線，結果不可信）
#   有違規時怎麼回 ICC2 修，見 references/pitfalls.md「Signoff」一節
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
if {![info exists corner]} {set corner slow}
set lib [dict get $CORNERS $corner lib]
set R reports_$corner
file mkdir $R

set_app_var search_path [concat [list $LIB_DIR] $search_path]
set_app_var link_path   [list * $lib.db]
read_verilog $ROUTED_V
current_design $DESIGN
link_design $DESIGN

source $SDC
set_propagated_clock [all_clocks]               ;# 用實際的 clock tree 延遲
read_parasitics $WORK/pex/$corner/$DESIGN.spef
update_timing

redirect $R/check_timing.rpt {check_timing -verbose}
redirect $R/parasitics.rpt   {report_annotated_parasitics -check}
redirect $R/setup.rpt        {report_timing -delay_type max -max_paths 10 -significant_digits 4}
redirect $R/hold.rpt         {report_timing -delay_type min -max_paths 10 -significant_digits 4}
redirect $R/constraint.rpt   {report_constraint -all_violators -significant_digits 4}
write_sdf -version 3.0 ${DESIGN}_postroute_${corner}.sdf

puts "$corner setup slack = [get_attribute [get_timing_paths -delay_type max] slack]"
puts "$corner hold  slack = [get_attribute [get_timing_paths -delay_type min] slack]"
exit
