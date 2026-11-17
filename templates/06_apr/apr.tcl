##############################################################################
# apr.tcl — APR（IC Compiler II）：floorplan → power plan → placement → CTS → route
# 執行：cd work/apr && icc2_shell -f ../../scripts/apr.tcl | tee apr.log
#   每一步結束都 save_block -as <名字>，出錯時可以 open_block 回到上一步，在 GUI（start_gui）裡看
#
# 【要改的地方】
#   1. DIE：晶片大小。先看合成 reports/area.rpt 的 Total cell area，
#      core 面積（die 扣掉兩邊 CORE_OFF）約為 cell area 的 2～3 倍（utilization 30～50%）
#      例：cell area 6000 um^2 → die 240 um（core 200 um，utilization 15%，很寬鬆）
#   2. PIN_SIDE_IN／PIN_SIDE_OUT：input／output pin 放在哪一邊
#   3. 電源網路（第 4 步）：ring 寬度、mesh 間距。設計大、耗電多時加密 mesh
#   4. CTS 的 clock transition 上限（第 6 步）
#
# 【跑完看什麼】
#   routes.rpt          ：Total number of DRCs = 0、open nets = 0
#   pg_connectivity.rpt ：沒有 floating（電源網路都有接上）
#   constraints.rpt     ：沒有 VIOLATED（max_capacitance、max_transition、setup、hold）
#   clock_qor.rpt       ：clock tree 有插 buffer、skew 合理
#   還有 max_capacitance／max_transition 或繞線 DRC：跑 apr_eco.tcl；原理見 references/pitfalls.md「APR」
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]

# ---------- 設定 ----------
set DIE          {{0 0} {240 240}}   ;# ← um，依 cell area 估
set CORE_OFF     20                  ;# die 邊到 core 的距離，放 power ring
set PIN_SIDE_IN  1                   ;# ← 1=左 2=上 3=右 4=下
set PIN_SIDE_OUT 3                   ;# ←
set MIN_LAYER    M2
set MAX_LAYER    M6                  ;# 訊號只走 M2～M6，M7/M8 留給電源
set CLK_MAX_TRAN 0.25                ;# ← ns，clock 線的 transition 上限
# --------------------------

# ===== 1. 建 design library、讀 netlist =====
file delete -force $NDM_LIB                  ;# 重跑時先刪舊的，否則 create_lib 報 LIB-009
create_lib $NDM_LIB -technology $TECH_TF -ref_libs [list $NDM_DIR/stdcell_rvt.ndm]
read_verilog -top $DESIGN $NETLIST
link_block
set_user_units -type capacitance -value 1fF  ;# 和 SDC 的單位一致
set_user_units -type resistance  -value 1MOhm
set_user_units -type time        -value 1ns

# ===== 2. Floorplan =====
set_attribute [get_site_defs unit] symmetry Y
set_attribute [get_site_defs unit] is_default true
initialize_floorplan -control_type die -boundary $DIE -core_offset $CORE_OFF -site_def unit
# SAED32 的 tech file 沒有寫繞線方向，要自己設：奇數層水平、偶數層垂直
foreach n {1 3 5 7 9} {set_attribute [get_layers M$n] routing_direction horizontal}
foreach n {2 4 6 8}   {set_attribute [get_layers M$n] routing_direction vertical}
set_attribute [get_layers MRDL] routing_direction vertical
set_ignored_layers -min_routing_layer $MIN_LAYER -max_routing_layer $MAX_LAYER

# 電源 net：建 VDD／VSS，接到每個 cell 的電源 pin
foreach {net type} {VDD power VSS ground} {
    create_net -$type $net
    create_port -direction inout -port_type $type $net
    connect_pg_net -net $net [get_ports $net]
    connect_pg_net -net $net [get_pins -hierarchical */$net]
}

# ===== 3. MCMM：每個 corner 一個 scenario，各自用對應的 RC 模型 =====
foreach rc {Cmin nominal Cmax} {
    read_parasitic_tech -tlup $TLUP_DIR/saed32nm_1p9m_${rc}.tluplus -layermap $TLUP_MAP -name rc_$rc
}
remove_scenarios -all ; remove_modes -all ; remove_corners -all
create_mode functional
dict for {name c} $CORNERS {
    create_corner $name
    create_scenario -mode functional -corner $name -name func_$name
    current_scenario func_$name
    set_process_number [dict get $c p]
    set_temperature [dict get $c t]
    set_voltage     [dict get $c v] -object_list VDD
    set_voltage 0 -object_list VSS
    set_parasitic_parameters -early_spec rc_[dict get $c rc] -late_spec rc_[dict get $c rc]
    source $SDC
}
set_scenario_status [all_scenarios] -active true -setup true -hold true
# 確認每個 corner 都對到自己的 library：pvt.rpt 要看到三個「no PVT mismatches (PVT-032)」，
# 出現 PVT-030 mismatch 就是 CORNERS 的 p／v／t 和 library 不合
redirect pvt.rpt {report_pvt}

# I/O pin 位置
set io_in [remove_from_collection [all_inputs] [get_ports {VDD VSS}]]
set_individual_pin_constraints -ports $io_in        -sides $PIN_SIDE_IN  -allowed_layers {M3 M5}
set_individual_pin_constraints -ports [all_outputs] -sides $PIN_SIDE_OUT -allowed_layers {M3 M5}
place_pins -self

# ===== 4. Power plan：ring（M7/M8）＋ mesh（M6/M7）＋ cell rail（M1） =====
set_pg_strategy_via_rule pg_via -via_rule {{intersection: all} {via_master: default}}
create_pg_ring_pattern ring -horizontal_layer M7 -vertical_layer M8 \
    -horizontal_width 4 -vertical_width 4 -horizontal_spacing 2 -vertical_spacing 2 -corner_bridge true
set_pg_strategy ring_s -core -pattern {{name: ring} {nets: {VDD VSS}} {offset: {4 4}}}
compile_pg -strategies ring_s -via_rule pg_via
# mesh：pitch 越小電源越穩，但佔越多繞線資源 ←
create_pg_mesh_pattern mesh -layers {{{vertical_layer: M6} {width: 2} {spacing: interleaving} {pitch: 40} {offset: 10}} {{horizontal_layer: M7} {width: 2} {spacing: interleaving} {pitch: 40} {offset: 10}}}
set_pg_strategy mesh_s -core -pattern {{name: mesh} {nets: {VDD VSS}}} -extension {{stop: outermost_ring}}
compile_pg -strategies mesh_s -via_rule pg_via
create_pg_std_cell_conn_pattern rail -layers M1
set_pg_strategy rail_s -core -pattern {{name: rail} {nets: {VDD VSS}}} -extension {{stop: outermost_ring}}
compile_pg -strategies rail_s -via_rule pg_via
# M1 rail 到 M6 mesh 的 via 不會自動產生，要自己補；少了這步電源 rail 是浮接的（LVS 會失敗）
create_pg_vias -nets {VDD VSS} -from_layers M1 -to_layers M6 \
    -via_masters {VIA12SQ_C VIA23SQ_C VIA34SQ_C VIA45SQ_C VIA56SQ_C}
# 剛好在同 net M7 正下方的 rail，上面那行會因為 DRC 檢查整條跳過；還有浮接就關掉檢查再補一次
foreach net {VDD VSS} {
    redirect -variable r {check_pg_connectivity -nets $net}
    if {[regexp {floating wires:\s*([1-9]\d*)} $r]} {
        create_pg_vias -nets $net -from_layers M1 -to_layers M6 -drc no_check \
            -via_masters {VIA12SQ_C VIA23SQ_C VIA34SQ_C VIA45SQ_C VIA56SQ_C}
    }
}
redirect pg_connectivity_floorplan.rpt {check_pg_connectivity}
# 常數 1／0 改接 tie cell，不直接接電源
# SAED32 的 TIEH_RVT／TIEL_RVT 在 library 裡是 dont_use、dont_touch，不先解除的話
# add_tie_cells 一顆都插不進去，只印 warning（OPT-200: No tie cell is available），
# 常數 pin 會直接接到電源軌。確認方式：apr.log 沒有 OPT-200，繞線後 netlist 有 TIEH_RVT／TIEL_RVT。
set_attribute [get_lib_cells */TIE*_RVT] dont_use false
set_attribute [get_lib_cells */TIE*_RVT] dont_touch false
add_tie_cells -tie_high_lib_cells [get_lib_cells */TIEH_RVT] -tie_low_lib_cells [get_lib_cells */TIEL_RVT]
connect_pg_net -automatic
save_block -as floorplan

# ===== 5. Placement =====
place_opt
connect_pg_net -automatic
redirect legality.rpt {check_legality}
save_block -as placed

# ===== 6. CTS（clock tree synthesis） =====
foreach_in_collection s [all_scenarios] {
    current_scenario $s
    # 合成時 clock 是理想的（ideal），CTS 前要解除，否則不會插 buffer
    set_dont_touch_network -clear [all_clocks]
    remove_ideal_network [get_ports $CLK_PORT]
    # CTS 後 clock 有實際延遲；I/O delay 改成相對於 clock 源頭（和繞線後 PT 的算法一致）
    # 數字沿用 constraints.sdc 的 IN_MAX 等變數，不要另外寫一組比較鬆的值，否則 hold 會漏修
    set io [remove_from_collection [all_inputs] [get_ports [list $CLK_PORT VDD VSS]]]
    set oo [remove_from_collection [all_outputs] [get_ports {VDD VSS}]]
    set_input_delay  -max $IN_MAX  -network_latency_included -clock $CLK_PORT $io
    set_input_delay  -min $IN_MIN  -network_latency_included -clock $CLK_PORT $io
    set_output_delay -max $OUT_MAX -network_latency_included -clock $CLK_PORT $oo
    set_output_delay -min $OUT_MIN -network_latency_included -clock $CLK_PORT $oo
    set_max_transition $CLK_MAX_TRAN -clock_path [all_clocks]
}
set_lib_cell_purpose -include cts [get_lib_cells {*/NBUFFX*_RVT */INVX*_RVT}]
clock_opt
connect_pg_net -automatic
redirect clock_qor.rpt {report_clock_qor}
save_block -as cts

# ===== 7. Route =====
route_auto
route_opt                                    ;# 繞線後再最佳化一次時序與電氣規則
# 還有少數 DRC 時，增量再繞幾次
for {set i 0} {$i < 3} {incr i} {
    redirect -variable r {check_routes}
    if {[regexp {Total number of DRCs = 0} $r]} break
    route_detail -incremental true -initial_drc_from_input true
}
connect_pg_net -automatic

# ===== 8. 報告 =====
redirect routes.rpt          {check_routes}
redirect pg_connectivity.rpt {check_pg_connectivity}
redirect connectivity.rpt    {check_lvs}
redirect constraints.rpt     {report_constraints -all_violators}
redirect qor.rpt             {report_qor}
dict for {name c} $CORNERS {
    redirect setup_$name.rpt {report_timing -scenarios [get_scenarios func_$name] -delay_type max -max_paths 10}
    redirect hold_$name.rpt  {report_timing -scenarios [get_scenarios func_$name] -delay_type min -max_paths 10}
}
save_block -as routed
save_lib
exit
