 ##################################################################################
 ##
 ## Project:  Aurora 64B/66B
 ## Company:  Xilinx
 ##
 ##
 ##
 ## (c) Copyright 2012 - 2014 Xilinx, Inc. All rights reserved.
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
 #################################################################################
 ##
 ##
 ##  aurora_64b66b_625
 ##
 ##
 ##  Description: This is the design constraints file for a 1 lane Aurora
 ##               core.
 ##               This is aurora.xdc
 ##               User should provide correct IO STANDARD for the LOC allocation.
 ##
 #################################################################################

 ################################ CLOCK CONSTRAINTS ##############################

    set_false_path -to [get_pins -hier *data_fifo*/RST]
    set_false_path -to [get_pins -hier *rxrecclk_bufg_i*/CE]

    # Create clock constraint for TXOUTCLK from GT
    create_clock -period 3.200	 [get_pins -hier -filter {name=~*aurora_64b66b_625_gtx_inst/gtxe2_i/TXOUTCLK}]
    # create_clock -period 3.200	 [get_pins -hier -filter {name=~*aurora_64b66b_625_wrapper_i*aurora_64b66b_625_multi_gt_i*aurora_64b66b_625_gtx_inst/gtxe2_i/TXOUTCLK}]

    # Create clock constraint for RXOUTCLK from GT
    create_clock -period 3.200	 [get_pins -hier -filter {name=~*aurora_64b66b_625_gtx_inst/gtxe2_i/RXOUTCLK}]
    # create_clock -period 3.200	 [get_pins -hier -filter {name=~*aurora_64b66b_625_wrapper_i*aurora_64b66b_625_multi_gt_i*aurora_64b66b_625_gtx_inst/gtxe2_i/RXOUTCLK}]

## clocks.xdc


 set_false_path -to [get_pins -hier *aurora_64b66b_625_cdc_to*/D]        

## ooc.xdc
	##########################################################################

	### User Clock Contraint
	## create_clock -name user_clk -period 6.400	 [get_ports user_clk] 

	### SYNC Clock Constraint
	## create_clock -name sync_clk -period 3.200	 [get_ports sync_clk]




## exdes.xdc

	################################ CLOCK CONSTRAINTS #########################
	# User Clock Contraint: the value is selected based on the line rate of the module
	create_clock -name TS_user_clk_i -period 6.400	 [get_pins */aurora_64b66b_625_block_i/clock_module_i/user_clk_net_i/O]

	# SYNC Clock Constraint
	create_clock -name TS_sync_clk_i -period 3.200	 [get_pins */aurora_64b66b_625_block_i/clock_module_i/sync_clock_net_i/O]

	################################ IP LEVEL CONSTRAINTS END ##################
	# Reference clock contraint for GTX
	create_clock -name GTXQ6_left_i -period 1.600	 [get_ports CLK_gtx_clk_1_0_p]
	create_clock -name GTXQ6_left_i -period 1.600	 [get_ports CLK_gtx_clk_1_0_n]
	set_property LOC E10 [get_ports CLK_gtx_clk_1_0_p]
	set_property LOC E9 [get_ports CLK_gtx_clk_1_0_n]
	

   set_property LOC GTXE2_CHANNEL_X1Y24 [get_cells  */top_auroraImport1_0/auroraImport/aurora_64b66b_625_block_i/aurora_64b66b_625_i/inst/aurora_64b66b_625_wrapper_i/aurora_64b66b_625_multi_gt_i/aurora_64b66b_625_gtx_inst/gtxe2_i]

   # set_property LOC GTXE2_COMMON_X1Y6 [get_cells */top_auroraImport1_0/auroraImport/aurora_64b66b_625_block_i/gt_common_support/gtxe2_common_i]




 # false path constraints to the example design logic
 set_false_path -to [get_pins -hier *aurora_64b66b_625_cdc_to*/D]

 set_property LOC E2 [get_ports { pins_aurora1_0_TXP }]
 set_property LOC E1 [get_ports { pins_aurora1_0_TXN }]
 set_property LOC D8 [get_ports { pins_aurora1_0_rxp_i }]
 set_property LOC D7 [get_ports { pins_aurora1_0_rxn_i }]


#####################################################################################################
