##############################################################################
# apr_eco.tcl — APR 後的 ECO（Engineering Change Order，工程變更）：修 route_opt 沒修掉的違規
# 執行：cd work/apr && icc2_shell -f ../../scripts/apr_eco.tcl | tee eco.log
#   什麼時候跑：
#     (a) apr.tcl 的報告還有違規：FROM_PT 0（讀 ICC2 自己的報告）
#     (b) 繞線後 STA（pt_postroute.tcl）還有 max_capacitance／max_transition 小幅超標：FROM_PT 1
#         （ICC2 的 RC 是估計值，StarRC 算出來常常多幾 %，ICC2 自己看不到這些違規，要讀 PT 的報告）
#   跑完再跑 apr_finish.tcl，之後的 DRC → LVS → PEX → 繞線後 STA 都要重跑
#   每次執行都先把目前的 routed 存一份 routed_before_eco，修壞了可以 open_block 回來
#
# 做兩件事：
#   1. max_capacitance／max_transition：在推太多負載的 pin 後面插 buffer。
#      用插 buffer 而不是把 cell 換大顆：擠的區域（例如乘法器）換大顆會推擠旁邊的 cell，
#      繞線 DRC 反而變多（例：REFRACT 換大顆後 DRC 從 2 個變 52 個）。
#   2. 殘留的繞線 DRC（short／spacing）：先拆掉有問題的 net 重繞；還在的話，
#      把相連的 cell 移開電源條一點再重繞（cell 在電源條正下方時，電源條的 via 會佔掉走線空間）
#
# 【要改的地方】
#   1. BUF_TABLE：依負載挑 buffer 的對照表（換製程要改 cell 名稱）
#   2. MAX_ROUNDS、ROUTE_FIX_ROUNDS：最多修幾輪
#   3. SHIFT：移 cell 的距離，約等於電源條寬度（apr.tcl mesh 的 width）
#   4. FROM_PT：0 = 讀 ICC2 的報告，1 = 讀繞線後 PT 的報告（見上面「什麼時候跑」）
#
# 【跑完看什麼】
#   eco.log            ：每一輪剩幾個違規 pin、插了哪些 buffer、繞線 DRC 剩幾個
#   eco_constraints.rpt：沒有 VIOLATED
#   eco_routes.rpt     ：Total number of DRCs = 0、open nets = 0
#   還修不掉：看 eco.log 是哪些 pin，進 GUI（start_gui）看位置，考慮加大 DIE 重跑 APR
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]

# ---------- 設定 ----------
# {負載上限(fF) buffer}：由小到大，上限約取該 buffer max_capacitance 的 75%
set BUF_TABLE {{24 NBUFFX4_RVT} {48 NBUFFX8_RVT} {96 NBUFFX16_RVT} {1e9 NBUFFX32_RVT}}
set MAX_ROUNDS       4
set ROUTE_FIX_ROUNDS 4
set SHIFT            2.0            ;# um
set FROM_PT          0              ;# ←
set PT_REPORTS [glob -nocomplain $WORK/postroute/reports_*/constraint.rpt]
# --------------------------

open_lib $NDM_LIB
open_block routed
save_block -as routed_before_eco -force   ;# 備份
open_block routed
link_block
# apr_finish.tcl 跑過的話已經有 filler，會擋住新插的 buffer：先拿掉，apr_finish.tcl 會重新補
set fillers [get_cells -hierarchical -quiet -filter {ref_name =~ SHFILL*}]
if {[sizeof_collection $fillers] > 0} {remove_cells $fillers}

# ===== 1. max_capacitance／max_transition =====
proc pick_buf {load} {
    foreach e $::BUF_TABLE { if {$load <= [lindex $e 0]} {return [lindex $e 1]} }
}
# 從報告抓「PIN : <名稱> <上限> <實際值>」；同一個 pin 可能出現在好幾個 scenario，取最大負載
proc violating_pins {} {
    if {$::FROM_PT} {return [pt_violating_pins]}
    redirect -variable txt {report_constraints -all_violators -max_capacitance -max_transition}
    set pins [dict create]
    foreach {all pin actual} [regexp -all -inline {PIN\s*:\s*(\S+)\s+[0-9.]+\s+([0-9.]+)} $txt] {
        if {![dict exists $pins $pin] || [dict get $pins $pin] < $actual} {dict set pins $pin $actual}
    }
    return $pins
}
# PT 的 report_constraint：只看 max_capacitance／max_transition 段落。
# pin 名稱太長時 PT 會換行，數字在下一行，所以名稱要從上一行拿
proc pt_violating_pins {} {
    set pins [dict create]
    foreach f $::PT_REPORTS {
        set fp [open $f r]; set lines [split [read $fp] \n]; close $fp
        set section ""; set prev ""
        foreach l $lines {
            if {[regexp {^\s+(max_capacitance|max_transition|min_delay/hold|max_delay/setup)\s} "$l "  -> section]} continue
            # 違規很小時 PT 印成「(VIOLATED: increase significant digits)」，所以比對到「(VIOLATED」為止
            if {$section in {max_capacitance max_transition} && [string match *(VIOLATED* $l]} {
                set w [regexp -all -inline {\S+} $l]
                if {[string is double -strict [lindex $w 0]]} {set pin [lindex $prev 0]; set actual [lindex $w 1]} \
                else {set pin [lindex $w 0]; set actual [lindex $w 2]}
                # max_transition 的「實際值」是 ns，不是負載；用一個小的數字讓它挑最小的 buffer
                if {$section eq "max_transition"} {set actual 1}
                if {![dict exists $pins $pin] || [dict get $pins $pin] < $actual} {dict set pins $pin $actual}
            }
            if {[string trim $l] ne ""} {set prev $l}
        }
    }
    return $pins
}
set n 0
set TAG [clock seconds]            ;# 每次執行的新 cell 名稱不同，重跑不會撞名
# PT 的報告不會因為這裡改了 netlist 而更新，所以 FROM_PT 時只修一輪
set rounds [expr {$FROM_PT ? 1 : $MAX_ROUNDS}]
for {set round 1} {$round <= $rounds} {incr round} {
    set pins [violating_pins]
    puts "ECO round $round: [dict size $pins] violating pins"
    if {[dict size $pins] == 0} break
    dict for {pin load} $pins {
        set p [get_pins -quiet $pin]
        if {[sizeof_collection $p] == 0} {puts "skip $pin (not found)"; continue}
        if {[get_attribute $p direction] ne "out"} continue
        set buf  [pick_buf $load]
        set cell [get_cells -of_objects $p]
        if {[string match *eco_buf_* [get_object_name $cell]]} {
            # 已經是 ECO buffer 還推不動：換大顆，不要再串一級
            size_cell $cell [get_lib_cells */$buf]
            puts "ECO upsize [get_object_name $cell] -> $buf (load $load fF)"
        } else {
            insert_buffer $p [get_lib_cells */$buf] -new_cell_names eco_buf_${TAG}_$n -new_net_names eco_net_${TAG}_$n
            puts "ECO buffer $pin -> $buf (load $load fF)"
            incr n
        }
    }
    legalize_placement -incremental
    connect_pg_net -automatic
    route_eco -reroute modified_nets_first_then_others
    route_detail -incremental true -initial_drc_from_input true -max_number_iterations 30
}
puts "ECO inserted $n buffers"

# ===== 2. 殘留的繞線 DRC =====
proc drc_nets {} {
    redirect -variable r {check_routes}
    regexp {Total number of DRCs = (\d+)} $r -> n
    set nets {}
    if {$n > 0} {
        open_drc_error_data zroute.err
        foreach_in_collection e [get_drc_errors -error_data zroute.err] {
            foreach x [get_object_name [get_attribute -quiet $e objects]] {
                if {$x ni {VDD VSS} && $x ni $nets} {lappend nets $x}
            }
        }
    }
    return [list $n $nets]
}
for {set i 1} {$i <= $ROUTE_FIX_ROUNDS} {incr i} {
    lassign [drc_nets] n nets
    puts "ROUTE_FIX round $i: DRCs=$n nets={$nets}"
    if {$n == 0} break
    if {$nets eq ""} {route_detail -incremental true -initial_drc_from_input true; continue}
    set nets [get_nets $nets]
    if {$i >= 2} {
        # 第 2 輪起：把相連的 cell 往遠離電源條的方向移 SHIFT
        set cells [filter_collection [get_cells -of [get_pins -of $nets]] "physical_status!=fixed"]
        foreach_in_collection c $cells {
            set bb [get_attribute $c boundary_bbox]
            set cx [expr {([lindex $bb 0 0] + [lindex $bb 1 0]) / 2.0}]
            set dir 1
            set st [get_shapes -quiet -intersect $bb -filter "shape_use==stripe"]
            if {[sizeof_collection $st] > 0} {
                set sb [get_attribute [index_collection $st 0] bbox]
                if {$cx < ([lindex $sb 0 0] + [lindex $sb 1 0]) / 2.0} {set dir -1}
            }
            set_cell_location -coordinates [list [expr {[lindex $bb 0 0] + $dir*$SHIFT}] [lindex $bb 0 1]] $c
        }
        legalize_placement -cells $cells
        # 移過的 cell 上所有訊號 net 都要重繞（包括 clock net，否則 clock 會斷開）
        set nets [add_to_collection -unique $nets [get_nets -of [get_pins -of $cells]]]
        set nets [filter_collection $nets "net_type!=power && net_type!=ground"]
    }
    remove_routes -nets $nets -detail_route -global_route
    route_eco -nets $nets
    route_detail -incremental true -initial_drc_from_input true
}
connect_pg_net -automatic

# ===== 3. 報告 =====
redirect eco_constraints.rpt  {report_constraints -all_violators}
redirect eco_routes.rpt       {check_routes}
redirect eco_connectivity.rpt {check_lvs}
save_block
save_lib
exit
