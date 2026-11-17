##############################################################################
# dc_syn.tcl — 邏輯合成（Design Compiler）：RTL → gate-level netlist
# 執行：mkdir -p work/syn && cd work/syn && dc_shell -f ../../scripts/dc_syn.tcl | tee syn.log
#
# 【要改的地方】
#   1. common_setup.tcl 的 DESIGN、RTL_FILES
#   2. constraints.sdc 的 clock、I/O delay、負載
#   3. 下面「設定」區的 MAXCAP_DERATE、HOLD_LIB（第一次先用預設，報告有問題再調）
#   4. 第 4 步的 compile 指令：要壓面積或時序很緊時換成註解裡的版本
#   5. SystemVerilog 的 RTL：analyze 改 -format sverilog
#
# 【跑完看什麼】
#   reports/timing_max.rpt ：最差 setup slack ≥ 0（slack (MET)）
#   reports/constraint.rpt ：沒有 VIOLATED（max_leakage_power 那段可忽略）
#   reports/check_timing.rpt：沒有 unconstrained endpoint、沒有 no clock
#   reports/area.rpt       ：Total cell area（比賽會評面積）
#   syn.log                ：沒有 Error；Warning 要看懂，尤其 LINT、LATCH（RTL 不小心寫出 latch）
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
file mkdir reports

# ---------- 設定 ----------
# max_capacitance 收緊成 library 值的幾倍（只在 DC 記憶體內改，PDK 檔案不動）。
# 原因：PT 算 pin 電容取上限、DC 用標稱值，不收緊的話 DC 過了，PT 還是會報 max_capacitance。
# 佈局前 STA 仍報 max_capacitance 就調低（例 0.70）；XOR／XNOR 很多的設計（乘法器）通常要更低。
set MAXCAP_DERATE 0.85
# DC 修 hold 用哪個 corner 的 library：
#   SS（slow）：設計有很多非同步 reset 的 DFF 時用這個，reset 的 removal 檢查在 SS 最嚴
#   FF（fast）：一般 D 端 hold 在 FF 最嚴；沒有非同步 reset 時用這個
set HOLD_LIB $LIB_SLOW
# --------------------------

# ===== 1. Library =====
# target_library：合成時可以挑的 cell
# link_library  ：解析 netlist 時找得到的 cell（* = 記憶體中的 design）
# SAED32 以 FF 為 target、同時 link SS：SAED32 的 wire-load 在 FF corner 會讓高扇出 net 延遲暴增，
# 只對 SS 合成時 DC 看不到，佈局前 STA 的 fast corner 會出現假的大負 slack。
set_app_var search_path       [concat [list $LIB_DIR] $search_path]
set_app_var target_library    [list $LIB_FAST.db]
set_app_var link_library      [list * $LIB_SLOW.db $LIB_FAST.db dw_foundation.sldb]
set_app_var synthetic_library [list dw_foundation.sldb]
set_app_var verilogout_no_tri true
set_app_var hdlin_enable_hier_map true      ;# SVF 記錄階層對應，Formality 需要

# ===== 2. 讀 RTL =====
set_svf $SVF                                ;# 要在讀檔前開始記錄
analyze -format verilog $RTL_FILES          ;# SystemVerilog 改 -format sverilog
elaborate $DESIGN
current_design $DESIGN
set_verification_top
link
uniquify

# ===== 3. 約束 =====
# setup 用 FF library 分析、hold 用 HOLD_LIB；wire-load 用 SS library 的模型
set_operating_conditions -max [string map {saed32rvt_ ""} $LIB_FAST] -max_library $LIB_FAST \
                         -min [string map {saed32rvt_ ""} $HOLD_LIB] -min_library $HOLD_LIB
set_wire_load_model -name $WLM -library $LIB_SLOW
set_wire_load_mode top
source $SDC

foreach lib [list $LIB_FAST $LIB_SLOW] {
    foreach_in_collection pin [get_lib_pins $lib/*/*] {
        set cap [get_attribute -quiet $pin max_capacitance]
        if {$cap ne "" && $cap > 0} {set_attribute $pin max_capacitance [expr {$MAXCAP_DERATE*$cap}]}
    }
}
# 不用最小的 X0／X1 cell：驅動太弱，繞線後很容易 max_capacitance／transition 超標
set_dont_use [get_lib_cells [list $LIB_FAST/*X0_RVT $LIB_FAST/*X1_RVT]]
# DC 預設不分析非同步 reset 的 recovery／removal（PT 會），不打開的話 reset 的高扇出不會被修
set_app_var enable_recovery_removal_arcs true
set_fix_hold [all_clocks]
# 同一條 net 接到多個 output 或常數時插 buffer，避免 netlist 出現 assign
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]
redirect reports/check_design_pre.rpt {check_design}

# ===== 4. 合成 =====
compile
# compile -map_effort high -area_effort high   ;# 壓面積
# compile_ultra                                ;# 時序很緊時；會重組 datapath，Formality 可能跑很久

# ===== 5. 命名清理：讓 netlist 名稱與 Verilog 模擬器相容 =====
define_name_rules verilog -replacement_char x
change_names -rules verilog -hierarchy

# ===== 6. 報告 =====
redirect reports/check_design.rpt {check_design}
redirect reports/check_timing.rpt {check_timing}
redirect reports/area.rpt         {report_area -hierarchy}
redirect reports/timing_max.rpt   {report_timing -delay_type max -max_paths 10}
redirect reports/timing_min.rpt   {report_timing -delay_type min -max_paths 10}
redirect reports/constraint.rpt   {report_constraint -all_violators}
redirect reports/qor.rpt          {report_qor}

# ===== 7. 寫出 =====
write -format ddc     -hierarchy -output ${DESIGN}_syn.ddc
write -format verilog -hierarchy -output $NETLIST
write_sdc ${DESIGN}_syn.sdc
write_sdf -version 3.0 ${DESIGN}_syn.sdf
set_svf -off

puts "setup slack = [get_attribute [get_timing_paths -delay_type max] slack]  (see reports/)"
exit
