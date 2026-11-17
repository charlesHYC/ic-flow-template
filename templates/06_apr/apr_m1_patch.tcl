##############################################################################
# apr_m1_patch.tcl — DRC 報 M1 細條（SAED32 的 M1.W.2.1）時的修補
# 執行：cd work/apr && icc2_shell -f ../../scripts/apr_m1_patch.tcl | tee m1_patch.log
#   順序：apr_finish → run_drc 報 M1.W.2.1 → 本腳本 → 再跑 apr_finish（重新匯出 GDS）→ run_drc
#
# 原理：繞線在 cell pin 旁邊留下寬度不到 0.06 um 的 M1 細條。在同一條 net 上畫一塊 M1 矩形，
#       蓋住「pin 形狀 ∪ 錯誤區域」，細條就併進寬金屬。PDK 和規則都不改。
#
# 【要改的地方】
#   1. ERR_FILE：DRC 的錯誤檔。一定要是「目前這份 GDS」的 DRC 結果，用舊的會把補丁畫在錯的地方
#   2. RULE    ：要處理的規則名稱
#
# 【跑完看什麼】
#   m1_patch.log：每個錯誤框都有一行 PATCH；有 UNPATCHED 就要進 GUI 看那個位置
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]

set ERR_FILE $WORK/drc/$DESIGN.LAYOUT_ERRORS
set RULE     M1.W.2.1
set MARGIN   0.01         ;# um，錯誤框常常只是貼著 pin 邊緣，找 pin 時放大一點

# 讀錯誤檔：規則名稱那一行之後的「(x1, y1) (x2, y2)」就是錯誤框
set fp [open $ERR_FILE r]; set lines [split [read $fp] \n]; close $fp
set boxes {}; set rule ""
foreach l $lines {
    if {[regexp {^\s*([A-Z0-9]+\.[A-Za-z0-9.]+)\s*:} $l -> r]} {set rule $r; continue}
    if {$rule eq $RULE && [regexp {\(\s*([-0-9.]+),\s*([-0-9.]+)\)\s*\(\s*([-0-9.]+),\s*([-0-9.]+)\)} $l -> x1 y1 x2 y2]} {
        lappend boxes [list $x1 $y1 $x2 $y2]
    }
}
puts "M1 error boxes: [llength $boxes]"

open_lib $NDM_LIB
open_block routed
link_block
foreach b $boxes {
    lassign $b x1 y1 x2 y2
    set search [list [list [expr {$x1-$MARGIN}] [expr {$y1-$MARGIN}]] [list [expr {$x2+$MARGIN}] [expr {$y2+$MARGIN}]]]
    set done 0
    foreach_in_collection p [get_objects_by_location -classes pin -intersect $search -quiet] {
        set net [get_nets -quiet -of_objects $p]
        if {[sizeof_collection $net] == 0} continue
        set pb [get_attribute $p bbox]
        set box [list [list [expr {min([lindex $pb 0 0],$x1)}] [expr {min([lindex $pb 0 1],$y1)}]] \
                      [list [expr {max([lindex $pb 1 0],$x2)}] [expr {max([lindex $pb 1 1],$y2)}]]]
        create_shape -shape_type rect -layer M1 -net $net -boundary $box
        puts "PATCH [get_object_name $p] net=[get_object_name $net] $box"
        set done 1; break
    }
    if {!$done} {puts "UNPATCHED $b (no pin here, check in GUI)"}
}
redirect m1_patch_routes.rpt {check_routes}
save_block
save_lib
exit
