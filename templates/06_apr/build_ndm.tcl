##############################################################################
# build_ndm.tcl — APR 前置：把 cell 的時序（.db）與實體（LEF）合成 ICC2 用的 NDM library
# 執行：mkdir -p work/apr && cd work/apr && icc2_lm_shell -f ../../scripts/build_ndm.tcl | tee ndm.log
#   注意是 icc2_lm_shell（library manager），不是 icc2_shell
#   同一個製程只要建一次；換設計不用重建
#
# 【要改的地方】
#   通常不用改：路徑都從 common_setup.tcl 來
#   要加 HVT／LVT cell 時，再建一份 workspace，read_db／read_lef 換成那組 library
#
# 【跑完看什麼】
#   ndm.log：check_workspace 沒有 Error；work/apr/libs/stdcell_rvt.ndm 有產生
##############################################################################
source [file join [file dirname [info script]] common_setup.tcl]
file mkdir $NDM_DIR

create_workspace stdcell_rvt -technology $TECH_TF
dict for {name c} $CORNERS { read_db [file join $LIB_DIR [dict get $c lib].db] }
read_lef $CELL_LEF
check_workspace
file delete -force $NDM_DIR/stdcell_rvt.ndm     ;# 重跑時先刪舊的，否則 FILE-008 already exists
commit_workspace -output $NDM_DIR/stdcell_rvt.ndm
remove_workspace
exit
