 
################################################################################
##
## (c) Copyright 2010-2014 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##
################################################################################
## aurora_8b10b.xdc generated for xc7a200t-fbg676-2 device

create_clock -period 3.636 [get_ports gt_refclk1]







####### CDC in HOTPLUG module from user_clk to init_clk
#### INIT_CLK period is set as 20.0 ns in example design has been considered as it is capturing clock.
#### Change in INIT_CLK frequency should be applied here as well.
set_max_delay -from [get_clocks -of_objects [get_ports user_clk]] -to [get_clocks -of_objects [get_ports init_clk_in]] -datapath_only 20.0

####### CDC from init_clk to user_clk
set_max_delay -from [get_clocks -of_objects [get_ports init_clk_in]] -to [get_clocks -of_objects [get_ports user_clk]] -datapath_only 9.091	

#### DRPCLK is set as 50 MHz in example design has been considered as it is capturing clock.
#### Change in DRPCLK frequency should be applied here as well.

####### CDC in DRP module from INIT_CLK to DRP_CLK
set_max_delay -from [get_clocks -of_objects [get_ports init_clk_in]] -to [get_clocks -of_objects [get_ports drpclk_in]] -datapath_only 20.000


####################### GT reference clock LOC (For use in top level design) #######################
# set_property LOC E11 [get_ports GTPQ2_N]
# set_property LOC F11 [get_ports GTPQ2_P]

############################### GT LOC (For use in top level design) ###################################
# set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt0_aurora_8b10b_i/gtpe2_i]
# set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt1_aurora_8b10b_i/gtpe2_i]
# set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt2_aurora_8b10b_i/gtpe2_i]
# set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt3_aurora_8b10b_i/gtpe2_i]

