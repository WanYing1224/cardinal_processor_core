set log file report/cardinal_cpu.lec -replace

read library -both -verilog include/gscl45nm.v

read design design/control_decoder.v design/register_file.v design/hazard_unit.v design/alu.v design/sfu.v design/cardinal_cpu.v -golden -verilog

read design netlist/cardinal_cpu.syn.v -revised -verilog

set root module cardinal_cpu -golden
set root module cardinal_cpu -revised

set flatten model -seq_constant -seq_constant_x_to 0 -gated_clock

add pin constraints 0 reset -both

set mapping method -phase -name first

set system mode lec

add compared points -all

delete compared points ex_wb_calc_result_reg*

compare

report compare data -class nonequivalent
report compare data -class abort

exit -f
