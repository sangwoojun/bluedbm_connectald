#open_hw
connect_hw_server
#current_hw_target [get_hw_targets */xilinx_tcf/Digilent/*]
#set_property PARAM.FREQUENCY 30000000 [get_hw_targets */xilinx_tcf/Digilent/*]
open_hw_target 
set artixfpga [lindex [get_hw_devices] 0] 
set vc707fpga [lindex [get_hw_devices] 2] 

set file ./mkTopArtix.bit
set_property PROGRAM.FILE $file $artixfpga
puts "fpga is $artixfpga, bit file size is [exec ls -sh $file], PROGRAM BEGIN"
program_hw_devices $artixfpga

set file ./vc707/hw/mkTop.bit
set_property PROGRAM.FILE $file $vc707fpga
puts "fpga is $vc707fpga, bit file size is [exec ls -sh $file], PROGRAM BEGIN"
program_hw_devices $vc707fpga

refresh_hw_device $vc707fpga
refresh_hw_device $artixfpga


