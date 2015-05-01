
vivado -mode batch -source program-clear-all.tcl
vivado -mode batch -source program-valid-all.tcl

pciescanportal
sleep 0.5
sudo chmod agu+rw /dev/fpga*
sudo chmod agu+rw /dev/portalmem
