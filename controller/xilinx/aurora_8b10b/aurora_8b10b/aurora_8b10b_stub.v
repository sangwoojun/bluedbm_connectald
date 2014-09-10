// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
// Date        : Sun Aug 24 22:19:11 2014
// Host        : umma running 64-bit Ubuntu 12.04.4 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/wjun/headless/vivado/a7/project_1/project_1.srcs/sources_1/ip/aurora_8b10b/aurora_8b10b_stub.v
// Design      : aurora_8b10b
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module aurora_8b10b(s_axi_tx_tdata, s_axi_tx_tvalid, s_axi_tx_tready, m_axi_rx_tdata, m_axi_rx_tvalid, rxp, rxn, txp, txn, gt_refclk1, hard_err, soft_err, lane_up, channel_up, warn_cc, do_cc, user_clk, sync_clk, gt_reset, reset, sys_reset_out, power_down, loopback, tx_lock, init_clk_in, tx_resetdone_out, rx_resetdone_out, link_reset_out, drpclk_in, drpaddr_in, drpen_in, drpdi_in, drprdy_out, drpdo_out, drpwe_in, drpaddr_in_lane1, drpen_in_lane1, drpdi_in_lane1, drprdy_out_lane1, drpdo_out_lane1, drpwe_in_lane1, drpaddr_in_lane2, drpen_in_lane2, drpdi_in_lane2, drprdy_out_lane2, drpdo_out_lane2, drpwe_in_lane2, drpaddr_in_lane3, drpen_in_lane3, drpdi_in_lane3, drprdy_out_lane3, drpdo_out_lane3, drpwe_in_lane3, gt_common_reset_out, gt0_pll0refclklost_in, quad1_common_lock_in, gt0_pll0outclk_in, gt0_pll1outclk_in, gt0_pll0outrefclk_in, gt0_pll1outrefclk_in, tx_out_clk, pll_not_locked)
/* synthesis syn_black_box black_box_pad_pin="s_axi_tx_tdata[0:127],s_axi_tx_tvalid,s_axi_tx_tready,m_axi_rx_tdata[0:127],m_axi_rx_tvalid,rxp[0:3],rxn[0:3],txp[0:3],txn[0:3],gt_refclk1,hard_err,soft_err,lane_up[0:3],channel_up,warn_cc,do_cc,user_clk,sync_clk,gt_reset,reset,sys_reset_out,power_down,loopback[2:0],tx_lock,init_clk_in,tx_resetdone_out,rx_resetdone_out,link_reset_out,drpclk_in,drpaddr_in[8:0],drpen_in,drpdi_in[15:0],drprdy_out,drpdo_out[15:0],drpwe_in,drpaddr_in_lane1[8:0],drpen_in_lane1,drpdi_in_lane1[15:0],drprdy_out_lane1,drpdo_out_lane1[15:0],drpwe_in_lane1,drpaddr_in_lane2[8:0],drpen_in_lane2,drpdi_in_lane2[15:0],drprdy_out_lane2,drpdo_out_lane2[15:0],drpwe_in_lane2,drpaddr_in_lane3[8:0],drpen_in_lane3,drpdi_in_lane3[15:0],drprdy_out_lane3,drpdo_out_lane3[15:0],drpwe_in_lane3,gt_common_reset_out,gt0_pll0refclklost_in,quad1_common_lock_in,gt0_pll0outclk_in,gt0_pll1outclk_in,gt0_pll0outrefclk_in,gt0_pll1outrefclk_in,tx_out_clk,pll_not_locked" */;
  input [0:127]s_axi_tx_tdata;
  input s_axi_tx_tvalid;
  output s_axi_tx_tready;
  output [0:127]m_axi_rx_tdata;
  output m_axi_rx_tvalid;
  input [0:3]rxp;
  input [0:3]rxn;
  output [0:3]txp;
  output [0:3]txn;
  input gt_refclk1;
  output hard_err;
  output soft_err;
  output [0:3]lane_up;
  output channel_up;
  input warn_cc;
  input do_cc;
  input user_clk;
  input sync_clk;
  input gt_reset;
  input reset;
  output sys_reset_out;
  input power_down;
  input [2:0]loopback;
  output tx_lock;
  input init_clk_in;
  output tx_resetdone_out;
  output rx_resetdone_out;
  output link_reset_out;
  input drpclk_in;
  input [8:0]drpaddr_in;
  input drpen_in;
  input [15:0]drpdi_in;
  output drprdy_out;
  output [15:0]drpdo_out;
  input drpwe_in;
  input [8:0]drpaddr_in_lane1;
  input drpen_in_lane1;
  input [15:0]drpdi_in_lane1;
  output drprdy_out_lane1;
  output [15:0]drpdo_out_lane1;
  input drpwe_in_lane1;
  input [8:0]drpaddr_in_lane2;
  input drpen_in_lane2;
  input [15:0]drpdi_in_lane2;
  output drprdy_out_lane2;
  output [15:0]drpdo_out_lane2;
  input drpwe_in_lane2;
  input [8:0]drpaddr_in_lane3;
  input drpen_in_lane3;
  input [15:0]drpdi_in_lane3;
  output drprdy_out_lane3;
  output [15:0]drpdo_out_lane3;
  input drpwe_in_lane3;
  output gt_common_reset_out;
  input gt0_pll0refclklost_in;
  input quad1_common_lock_in;
  input gt0_pll0outclk_in;
  input gt0_pll1outclk_in;
  input gt0_pll0outrefclk_in;
  input gt0_pll1outrefclk_in;
  output tx_out_clk;
  input pll_not_locked;
endmodule
