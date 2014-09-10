-- Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
-- Date        : Sun Aug 24 22:19:12 2014
-- Host        : umma running 64-bit Ubuntu 12.04.4 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/wjun/headless/vivado/a7/project_1/project_1.srcs/sources_1/ip/aurora_8b10b/aurora_8b10b_stub.vhdl
-- Design      : aurora_8b10b
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a200tfbg676-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity aurora_8b10b is
  Port ( 
    s_axi_tx_tdata : in STD_LOGIC_VECTOR ( 0 to 127 );
    s_axi_tx_tvalid : in STD_LOGIC;
    s_axi_tx_tready : out STD_LOGIC;
    m_axi_rx_tdata : out STD_LOGIC_VECTOR ( 0 to 127 );
    m_axi_rx_tvalid : out STD_LOGIC;
    rxp : in STD_LOGIC_VECTOR ( 0 to 3 );
    rxn : in STD_LOGIC_VECTOR ( 0 to 3 );
    txp : out STD_LOGIC_VECTOR ( 0 to 3 );
    txn : out STD_LOGIC_VECTOR ( 0 to 3 );
    gt_refclk1 : in STD_LOGIC;
    hard_err : out STD_LOGIC;
    soft_err : out STD_LOGIC;
    lane_up : out STD_LOGIC_VECTOR ( 0 to 3 );
    channel_up : out STD_LOGIC;
    warn_cc : in STD_LOGIC;
    do_cc : in STD_LOGIC;
    user_clk : in STD_LOGIC;
    sync_clk : in STD_LOGIC;
    gt_reset : in STD_LOGIC;
    reset : in STD_LOGIC;
    sys_reset_out : out STD_LOGIC;
    power_down : in STD_LOGIC;
    loopback : in STD_LOGIC_VECTOR ( 2 downto 0 );
    tx_lock : out STD_LOGIC;
    init_clk_in : in STD_LOGIC;
    tx_resetdone_out : out STD_LOGIC;
    rx_resetdone_out : out STD_LOGIC;
    link_reset_out : out STD_LOGIC;
    drpclk_in : in STD_LOGIC;
    drpaddr_in : in STD_LOGIC_VECTOR ( 8 downto 0 );
    drpen_in : in STD_LOGIC;
    drpdi_in : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drprdy_out : out STD_LOGIC;
    drpdo_out : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drpwe_in : in STD_LOGIC;
    drpaddr_in_lane1 : in STD_LOGIC_VECTOR ( 8 downto 0 );
    drpen_in_lane1 : in STD_LOGIC;
    drpdi_in_lane1 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drprdy_out_lane1 : out STD_LOGIC;
    drpdo_out_lane1 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drpwe_in_lane1 : in STD_LOGIC;
    drpaddr_in_lane2 : in STD_LOGIC_VECTOR ( 8 downto 0 );
    drpen_in_lane2 : in STD_LOGIC;
    drpdi_in_lane2 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drprdy_out_lane2 : out STD_LOGIC;
    drpdo_out_lane2 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drpwe_in_lane2 : in STD_LOGIC;
    drpaddr_in_lane3 : in STD_LOGIC_VECTOR ( 8 downto 0 );
    drpen_in_lane3 : in STD_LOGIC;
    drpdi_in_lane3 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    drprdy_out_lane3 : out STD_LOGIC;
    drpdo_out_lane3 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    drpwe_in_lane3 : in STD_LOGIC;
    gt_common_reset_out : out STD_LOGIC;
    gt0_pll0refclklost_in : in STD_LOGIC;
    quad1_common_lock_in : in STD_LOGIC;
    gt0_pll0outclk_in : in STD_LOGIC;
    gt0_pll1outclk_in : in STD_LOGIC;
    gt0_pll0outrefclk_in : in STD_LOGIC;
    gt0_pll1outrefclk_in : in STD_LOGIC;
    tx_out_clk : out STD_LOGIC;
    pll_not_locked : in STD_LOGIC
  );

end aurora_8b10b;

architecture stub of aurora_8b10b is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "s_axi_tx_tdata[0:127],s_axi_tx_tvalid,s_axi_tx_tready,m_axi_rx_tdata[0:127],m_axi_rx_tvalid,rxp[0:3],rxn[0:3],txp[0:3],txn[0:3],gt_refclk1,hard_err,soft_err,lane_up[0:3],channel_up,warn_cc,do_cc,user_clk,sync_clk,gt_reset,reset,sys_reset_out,power_down,loopback[2:0],tx_lock,init_clk_in,tx_resetdone_out,rx_resetdone_out,link_reset_out,drpclk_in,drpaddr_in[8:0],drpen_in,drpdi_in[15:0],drprdy_out,drpdo_out[15:0],drpwe_in,drpaddr_in_lane1[8:0],drpen_in_lane1,drpdi_in_lane1[15:0],drprdy_out_lane1,drpdo_out_lane1[15:0],drpwe_in_lane1,drpaddr_in_lane2[8:0],drpen_in_lane2,drpdi_in_lane2[15:0],drprdy_out_lane2,drpdo_out_lane2[15:0],drpwe_in_lane2,drpaddr_in_lane3[8:0],drpen_in_lane3,drpdi_in_lane3[15:0],drprdy_out_lane3,drpdo_out_lane3[15:0],drpwe_in_lane3,gt_common_reset_out,gt0_pll0refclklost_in,quad1_common_lock_in,gt0_pll0outclk_in,gt0_pll1outclk_in,gt0_pll0outrefclk_in,gt0_pll1outrefclk_in,tx_out_clk,pll_not_locked";
begin
end;
