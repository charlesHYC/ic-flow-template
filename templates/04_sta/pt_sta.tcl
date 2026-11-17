##############################################################################
# pt_sta.tcl — 佈局前 STA（PrimeTime）：每個 corner 檢查一次 setup／hold
# 執行（每個 corner 跑一次）：
#   mkdir -p work/sta && cd work/sta
#   pt_shell -x "set corner slow"    -f ../../scripts/pt_sta.tcl | tee sta_slow.log
#   pt_shell -x "set corner typical" -f ../../scripts/pt_sta.tcl | tee sta_typical.log
#   pt_shell -x "set corner fast"    -f ../../scripts/pt_sta.tcl | tee sta_fast.log
# 也會寫出該 corner 的 SDF，給閘級模擬用
#
# 【要改的地方】
#   通常不用改。要加 corner 就改 common_setup.tcl 的 CORNERS
#
# 【跑完看什麼】（reports_<corner>/）
#   setup.rpt      ：slow corner 最容易 setup 違規，slack ≥ 0
#   hold.rpt       ：fast corner 最容易 hold 違規，slack ≥ 0
#   constraint.rpt ：沒有 VIOLATED（max_capacitance、max_transition 也算）
#   check_timing.rpt：沒有 unconstrained endpoint
#   coverage.rpt   ：哪些檢查沒有被測到（例如 reset 的 pulse width），回報時要說明
#   佈局前用 wire-load 估線延遲，fast corner 的 slack 常常偏悲觀；真正的結果看繞線後 STA
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
if {![info exists corner]} {set corner slow}
set lib [dict get $CORNERS $corner lib]
set R reports_$corner
file mkdir $R

# 要分析的 corner 放 link_path 第一個；SS 也要載入，因為 wire-load 模型在 SS library 裡
# （少了它，set_wire_load_model 報 SEL-005，fast corner 出現假的大負 slack）
set_app_var search_path [concat [list $LIB_DIR] $search_path]
set link [list * $lib.db]
if {$lib ne $LIB_SLOW} {lappend link $LIB_SLOW.db}
set_app_var link_path $link

read_verilog $NETLIST
current_design $DESIGN
link_design $DESIGN

set_wire_load_model -name $WLM -library $LIB_SLOW
set_wire_load_mode top
source $SDC
update_timing

redirect $R/check_timing.rpt {check_timing -verbose}
redirect $R/setup.rpt      {report_timing -delay_type max -max_paths 10 -significant_digits 4}
redirect $R/hold.rpt       {report_timing -delay_type min -max_paths 10 -significant_digits 4}
redirect $R/constraint.rpt {report_constraint -all_violators -significant_digits 4}
redirect $R/coverage.rpt   {report_analysis_coverage}
write_sdf -version 3.0 ${DESIGN}_${corner}.sdf

puts "$corner setup slack = [get_attribute [get_timing_paths -delay_type max] slack]"
puts "$corner hold  slack = [get_attribute [get_timing_paths -delay_type min] slack]"
exit
