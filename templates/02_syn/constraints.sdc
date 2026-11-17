##############################################################################
# constraints.sdc — 時序約束（DC、PT 佈局前／繞線後、ICC2 都 source 這一份）
# 單位跟著 library：SAED32 是 ns / fF / MOhm（CBDK 是 ns / pF / kOhm，數字要換算）
#
# 【要改的地方】
#   1. CLK_PORT、PERIOD ：clock port 名稱與週期，照題目規定
#   2. clock uncertainty／transition／latency：題目有給就照題目，沒給用下面的預設
#   3. I/O delay        ：外部電路在 clock 後多久送進資料、要求輸出多早穩定
#                         題目常寫成「input delay = 0.5 × period」之類
#   4. set_load／set_drive：輸出負載、輸入驅動。題目的 1 pF 在 SAED32 要寫 1000（fF），
#                         但 SAED32 核心 cell 推不動 1 pF（最大 cell 上限約 168 fF），核心設計用 20~50
#   5. 例外路徑（多 clock、multicycle、false path）：題目有提到才加，加在檔尾
##############################################################################

set CLK_PORT clk            ;# ← clock port 名稱
set PERIOD   10.0           ;# ← clock 週期（ns）

create_clock -name $CLK_PORT -period $PERIOD [get_ports $CLK_PORT]
set_clock_uncertainty -setup 0.10 [get_clocks $CLK_PORT]   ;# ← skew＋jitter 預留
set_clock_uncertainty -hold  0.05 [get_clocks $CLK_PORT]
set_clock_transition  0.10        [get_clocks $CLK_PORT]

# 不含 clock 的 input
set in_ports [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]

# I/O delay：max 用來檢查 setup，min 用來檢查 hold（min 越小越嚴格）
# 數字放在變數裡，APR 的 CTS 之後會用同一組數字重設（見 apr.tcl）
set IN_MAX  1.0             ;# ← input 最晚到達
set IN_MIN  0.0             ;# ← input 最早到達
set OUT_MAX 1.0             ;# ← output 要提早多久穩定
set OUT_MIN 0.0             ;# ← output 的 hold 要求
# 外部用 falling edge 送資料時，每行加 -clock_fall
set_input_delay  -clock $CLK_PORT -max $IN_MAX  $in_ports
set_input_delay  -clock $CLK_PORT -min $IN_MIN  $in_ports
set_output_delay -clock $CLK_PORT -max $OUT_MAX [all_outputs]
set_output_delay -clock $CLK_PORT -min $OUT_MIN [all_outputs]
set_input_transition 0.10 $in_ports

set_load  20.0   [all_outputs]      ;# ← fF
set_drive 0.0001 $in_ports          ;# ← MOhm（= 100 Ohm）

# 非同步 reset 不要設 false path：要保留 recovery／removal 檢查
# ---- 例外路徑（需要時才加） ----
# set_false_path -from [get_ports test_mode]
# set_multicycle_path 2 -setup -from [get_cells u_slow_reg*]
# set_multicycle_path 1 -hold  -from [get_cells u_slow_reg*]
