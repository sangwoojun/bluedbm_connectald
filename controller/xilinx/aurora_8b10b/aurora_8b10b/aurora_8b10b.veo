// (c) Copyright 1995-2014 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.

// IP VLNV: xilinx.com:ip:aurora_8b10b:10.2
// IP Revision: 0

// The following must be inserted into your Verilog file for this
// core to be instantiated. Change the instance name and port connections
// (in parentheses) to your own signal names.

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
aurora_8b10b your_instance_name (
  .s_axi_tx_tdata(s_axi_tx_tdata),                // input wire [0 : 127] s_axi_tx_tdata
  .s_axi_tx_tvalid(s_axi_tx_tvalid),              // input wire s_axi_tx_tvalid
  .s_axi_tx_tready(s_axi_tx_tready),              // output wire s_axi_tx_tready
  .m_axi_rx_tdata(m_axi_rx_tdata),                // output wire [0 : 127] m_axi_rx_tdata
  .m_axi_rx_tvalid(m_axi_rx_tvalid),              // output wire m_axi_rx_tvalid
  .hard_err(hard_err),                            // output wire hard_err
  .soft_err(soft_err),                            // output wire soft_err
  .channel_up(channel_up),                        // output wire channel_up
  .lane_up(lane_up),                              // output wire [0 : 3] lane_up
  .txp(txp),                                      // output wire [0 : 3] txp
  .txn(txn),                                      // output wire [0 : 3] txn
  .do_cc(do_cc),                                  // input wire do_cc
  .warn_cc(warn_cc),                              // input wire warn_cc
  .reset(reset),                                  // input wire reset
  .gt_reset(gt_reset),                            // input wire gt_reset
  .loopback(loopback),                            // input wire [2 : 0] loopback
  .rxp(rxp),                                      // input wire [0 : 3] rxp
  .rxn(rxn),                                      // input wire [0 : 3] rxn
  .drpclk_in(drpclk_in),                          // input wire drpclk_in
  .drpaddr_in(drpaddr_in),                        // input wire [8 : 0] drpaddr_in
  .drpen_in(drpen_in),                            // input wire drpen_in
  .drpdi_in(drpdi_in),                            // input wire [15 : 0] drpdi_in
  .drprdy_out(drprdy_out),                        // output wire drprdy_out
  .drpdo_out(drpdo_out),                          // output wire [15 : 0] drpdo_out
  .drpwe_in(drpwe_in),                            // input wire drpwe_in
  .drpaddr_in_lane1(drpaddr_in_lane1),            // input wire [8 : 0] drpaddr_in_lane1
  .drpen_in_lane1(drpen_in_lane1),                // input wire drpen_in_lane1
  .drpdi_in_lane1(drpdi_in_lane1),                // input wire [15 : 0] drpdi_in_lane1
  .drprdy_out_lane1(drprdy_out_lane1),            // output wire drprdy_out_lane1
  .drpdo_out_lane1(drpdo_out_lane1),              // output wire [15 : 0] drpdo_out_lane1
  .drpwe_in_lane1(drpwe_in_lane1),                // input wire drpwe_in_lane1
  .drpaddr_in_lane2(drpaddr_in_lane2),            // input wire [8 : 0] drpaddr_in_lane2
  .drpen_in_lane2(drpen_in_lane2),                // input wire drpen_in_lane2
  .drpdi_in_lane2(drpdi_in_lane2),                // input wire [15 : 0] drpdi_in_lane2
  .drprdy_out_lane2(drprdy_out_lane2),            // output wire drprdy_out_lane2
  .drpdo_out_lane2(drpdo_out_lane2),              // output wire [15 : 0] drpdo_out_lane2
  .drpwe_in_lane2(drpwe_in_lane2),                // input wire drpwe_in_lane2
  .drpaddr_in_lane3(drpaddr_in_lane3),            // input wire [8 : 0] drpaddr_in_lane3
  .drpen_in_lane3(drpen_in_lane3),                // input wire drpen_in_lane3
  .drpdi_in_lane3(drpdi_in_lane3),                // input wire [15 : 0] drpdi_in_lane3
  .drprdy_out_lane3(drprdy_out_lane3),            // output wire drprdy_out_lane3
  .drpdo_out_lane3(drpdo_out_lane3),              // output wire [15 : 0] drpdo_out_lane3
  .drpwe_in_lane3(drpwe_in_lane3),                // input wire drpwe_in_lane3
  .power_down(power_down),                        // input wire power_down
  .tx_lock(tx_lock),                              // output wire tx_lock
  .tx_resetdone_out(tx_resetdone_out),            // output wire tx_resetdone_out
  .rx_resetdone_out(rx_resetdone_out),            // output wire rx_resetdone_out
  .link_reset_out(link_reset_out),                // output wire link_reset_out
  .gt_common_reset_out(gt_common_reset_out),      // output wire gt_common_reset_out
  .gt0_pll0outclk_in(gt0_pll0outclk_in),          // input wire gt0_pll0outclk_in
  .gt0_pll1outclk_in(gt0_pll1outclk_in),          // input wire gt0_pll1outclk_in
  .gt0_pll0outrefclk_in(gt0_pll0outrefclk_in),    // input wire gt0_pll0outrefclk_in
  .gt0_pll1outrefclk_in(gt0_pll1outrefclk_in),    // input wire gt0_pll1outrefclk_in
  .gt0_pll0refclklost_in(gt0_pll0refclklost_in),  // input wire gt0_pll0refclklost_in
  .quad1_common_lock_in(quad1_common_lock_in),    // input wire quad1_common_lock_in
  .init_clk_in(init_clk_in),                      // input wire init_clk_in
  .pll_not_locked(pll_not_locked),                // input wire pll_not_locked
  .tx_out_clk(tx_out_clk),                        // output wire tx_out_clk
  .sys_reset_out(sys_reset_out),                  // output wire sys_reset_out
  .user_clk(user_clk),                            // input wire user_clk
  .sync_clk(sync_clk),                            // input wire sync_clk
  .gt_refclk1(gt_refclk1)                        // input wire gt_refclk1
);
// INST_TAG_END ------ End INSTANTIATION Template ---------

// You must compile the wrapper file aurora_8b10b.v when simulating
// the core, aurora_8b10b. When compiling the wrapper file, be sure to
// reference the Verilog simulation library.

