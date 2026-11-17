##############################################################################
# apr_finish.tcl — APR 收尾：補 filler、放電源 terminal、匯出 GDS／netlist
# 執行：cd work/apr && icc2_shell -f ../../scripts/apr_finish.tcl | tee finish.log
#   在 apr.tcl（必要時加 apr_eco.tcl）的結果都乾淨之後才跑；apr_m1_patch.tcl 修完後也要再跑一次
#
# 【要改的地方】
#   通常不用改。filler 的種類換製程時要改（SAED32 是 SHFILL*）
#
# 【跑完看什麼】
#   work/apr/ 下有 ${DESIGN}.gds、${DESIGN}_routed.v、${DESIGN}_routed_pg.v
#   routes.rpt 仍然 0 DRC（filler 不應該產生新的繞線錯誤）
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]

open_lib $NDM_LIB
open_block routed
set_user_units -type capacitance -value 1fF
set_user_units -type resistance  -value 1MOhm
set_user_units -type time        -value 1ns

# 1. Filler：填滿 cell 之間的空隙，讓 well／implant 連續（不填 DRC 會錯）
# 第二次執行（例如修完 M1 細條後重新匯出）時已經有 filler，不要重複補
if {[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SHFILL*}]] == 0} {
    create_stdcell_fillers -prefix filler_ -lib_cells [get_lib_cells \
        {*/SHFILL128_RVT */SHFILL64_RVT */SHFILL3_RVT */SHFILL2_RVT */SHFILL1_RVT}]
}
connect_pg_net -automatic

# 2. 電源 terminal：LVS 要知道 VDD／VSS port 在哪個金屬上，放在 power ring
foreach net {VDD VSS} {
    set ring [index_collection [get_shapes -of_objects [get_nets $net] -filter "shape_use == ring"] 0]
    if {[sizeof_collection [get_terminals -quiet -of_objects [get_ports $net]]] == 0} {
        create_terminal -port [get_ports $net] -boundary [get_attribute $ring bbox] \
            -layer [get_attribute $ring layer_name]
    }
}
redirect routes.rpt {check_routes}

# 3. 匯出
# GDS 一定要 merge 標準元件的 GDS，否則 cell 裡面是空的，DRC／LVS 驗不到電晶體
write_gds -hierarchy design -long_names -output_pin all \
    -layer_map $GDS_MAP -merge_files [list $CELL_GDS] -merge_gds_top_cell $DESIGN $ROUTED_GDS
# 給 STA、Formality、模擬：不含電源與 filler
write_verilog -exclude {physical_only_cells pg_netlist} $ROUTED_V
# 給 LVS：含電源與 filler（filler 要另外列，physical_only_cells 不包含 filler）
write_verilog -include {pg_netlist physical_only_cells filler_cells} $ROUTED_PG_V
write_def ${DESIGN}.def
save_block
save_lib
exit
