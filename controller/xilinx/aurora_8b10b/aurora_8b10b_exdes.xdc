 
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
## XDC generated for xc7a200t-fbg676-2 device
# 275.0MHz GT Reference clock constraint
create_clock -name GT_REFCLK1 -period 3.636	 [get_pins gtp_clk_0/O]
####################### GT reference clock LOC #######################
set_property LOC E11 [get_ports CLK_gtp_clk_0_n]
set_property LOC F11 [get_ports CLK_gtp_clk_0_p]
# TXOUTCLK Constraint: Value is selected based on the line rate (4.4 Gbps) and lane width (4-Byte)
#create_clock -name tx_out_clk_i -period 4.545	 [get_pins aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt0_aurora_8b10b_i/gtpe2_i/TXOUTCLK]
# SYNC_CLK constraint : Value is selected based on the line rate (4.4 Gbps) and lane width (4-Byte)
create_clock -name sync_clk_i -period 4.545	 [get_pins */auroraIntraImport/aurora_module_i/clock_module_i/clkout1_buf/O]

# USER_CLK constraint : Value is selected based on the line rate (4.4 Gbps) and lane width (4-Byte)
create_clock -name user_clk_i -period 9.091	 [get_pins */auroraIntraImport/aurora_module_i/clock_module_i/clkout0_buf/O]
# 20.0 ns period Board Clock Constraint 
create_clock -name init_clk_i -period 20.0 [get_pins */auroraIntraClockDiv2_slowbuf/O]
# 20.0 ns period DRP Clock Constraint 
create_clock -name drp_clk_i -period 20.0 [get_pins */auroraIntraClockDiv2_slowbuf/O] -add
#TODO #create_clock -name drp_clk_i -period 20.0 [get_ports DRP_CLK_IN]

###### CDC in RESET_LOGIC from INIT_CLK to USER_CLK ##############
set_max_delay -from [get_clocks init_clk_i] -to [get_clocks user_clk_i] -datapath_only 9.091	

#CDC clkout0 to/from user_clk_i 
set_max_delay -from [get_clocks clkout0] -to [get_clocks user_clk_i] -datapath_only 9.091	
set_max_delay -from [get_clocks user_clk_i] -to [get_clocks clkout0] -datapath_only 9.091	



############################### GT LOC ###################################
set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells */auroraIntraImport/aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt0_aurora_8b10b_i/gtpe2_i]
set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells */auroraIntraImport/aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt1_aurora_8b10b_i/gtpe2_i]
set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells */auroraIntraImport/aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt2_aurora_8b10b_i/gtpe2_i]
set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells */auroraIntraImport/aurora_module_i/aurora_8b10b_i/inst/gt_wrapper_i/aurora_8b10b_multi_gt_i/gt3_aurora_8b10b_i/gtpe2_i]

  
# aurora X0Y4 
 set_property LOC A11 [get_ports pins_aurora_rxn_i[3]] 
 set_property LOC B11 [get_ports pins_aurora_rxp_i[3]] 
 set_property LOC A7 [get_ports pins_aurora_TXN[3]] 
 set_property LOC B7 [get_ports pins_aurora_TXP[3]]
  
 # aurora X0Y5
 set_property LOC C14 [get_ports pins_aurora_rxn_i[2]] 
 set_property LOC D14 [get_ports pins_aurora_rxp_i[2]] 
 set_property LOC C8 [get_ports pins_aurora_TXN[2]] 
 set_property LOC D8 [get_ports pins_aurora_TXP[2]]
 
 # aurora X0Y6 
 set_property LOC A13 [get_ports pins_aurora_rxn_i[1]] 
 set_property LOC B13 [get_ports pins_aurora_rxp_i[1]] 
 set_property LOC A9 [get_ports pins_aurora_TXN[1]] 
 set_property LOC B9 [get_ports pins_aurora_TXP[1]]
 
 # aurora X0Y7 
 set_property LOC C12 [get_ports pins_aurora_rxn_i[0]] 
 set_property LOC D12 [get_ports pins_aurora_rxp_i[0]] 
 set_property LOC C10 [get_ports pins_aurora_TXN[0]] 
 set_property LOC D10 [get_ports pins_aurora_TXP[0]]
