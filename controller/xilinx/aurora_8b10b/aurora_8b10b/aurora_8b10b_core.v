
///////////////////////////////////////////////////////////////////////////////
// (c) Copyright 2008 Xilinx, Inc. All rights reserved.
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
//
///////////////////////////////////////////////////////////////////////////////
//
//  aurora_8b10b
//
//
//  Description: This is the top level module for a 4 4-byte lane Aurora
//               reference design module with streaming interface.
//


`timescale 1 ns / 1 ps
(* core_generation_info = "aurora_8b10b,aurora_8b10b_v10_2,{user_interface=AXI_4_Streaming,backchannel_mode=Sidebands,c_aurora_lanes=4,c_column_used=None,c_gt_clock_1=GTPQ2,c_gt_clock_2=None,c_gt_loc_1=X,c_gt_loc_10=2,c_gt_loc_11=3,c_gt_loc_12=4,c_gt_loc_13=X,c_gt_loc_14=X,c_gt_loc_15=X,c_gt_loc_16=X,c_gt_loc_17=X,c_gt_loc_18=X,c_gt_loc_19=X,c_gt_loc_2=X,c_gt_loc_20=X,c_gt_loc_21=X,c_gt_loc_22=X,c_gt_loc_23=X,c_gt_loc_24=X,c_gt_loc_25=X,c_gt_loc_26=X,c_gt_loc_27=X,c_gt_loc_28=X,c_gt_loc_29=X,c_gt_loc_3=X,c_gt_loc_30=X,c_gt_loc_31=X,c_gt_loc_32=X,c_gt_loc_33=X,c_gt_loc_34=X,c_gt_loc_35=X,c_gt_loc_36=X,c_gt_loc_37=X,c_gt_loc_38=X,c_gt_loc_39=X,c_gt_loc_4=X,c_gt_loc_40=X,c_gt_loc_41=X,c_gt_loc_42=X,c_gt_loc_43=X,c_gt_loc_44=X,c_gt_loc_45=X,c_gt_loc_46=X,c_gt_loc_47=X,c_gt_loc_48=X,c_gt_loc_5=X,c_gt_loc_6=X,c_gt_loc_7=X,c_gt_loc_8=X,c_gt_loc_9=1,c_lane_width=4,c_line_rate=44000,c_nfc=false,c_nfc_mode=IMM,c_refclk_frequency=275000,c_simplex=false,c_simplex_mode=TX,c_stream=true,c_ufc=false,flow_mode=None,interface_mode=Streaming,dataflow_config=Duplex}" *)
module aurora_8b10b_core #
(
     parameter   SIM_GTRESET_SPEEDUP=   "FALSE"      // Set to 'TRUE' to speed up sim reset
)
(
    // AXI TX Interface
    s_axi_tx_tdata,
    s_axi_tx_tvalid,
    s_axi_tx_tready,

    // AXI RX Interface
    m_axi_rx_tdata,
    m_axi_rx_tvalid,

    //Clock Correction Interface
    do_cc,
    warn_cc,

    //GT Serial I/O
    rxp,
    rxn,
    txp,
    txn,

    //GT Reference Clock Interface
    gt_refclk1,

    //Error Detection Interface
    hard_err,
    soft_err,

    //Status
    channel_up,
    lane_up,

    //System Interface
    user_clk,
    sync_clk,
    reset,
    power_down,
    loopback,
    gt_reset,
    init_clk_in,
    pll_not_locked,
    tx_resetdone_out,
    rx_resetdone_out,
    link_reset_out,
drpclk_in,
    drpaddr_in,
    drpdi_in,
    drpdo_out,
    drpen_in,
    drprdy_out,
    drpwe_in,
    drpaddr_in_lane1,
    drpdi_in_lane1,
    drpdo_out_lane1,
    drpen_in_lane1,
    drprdy_out_lane1,
    drpwe_in_lane1,
    drpaddr_in_lane2,
    drpdi_in_lane2,
    drpdo_out_lane2,
    drpen_in_lane2,
    drprdy_out_lane2,
    drpwe_in_lane2,
    drpaddr_in_lane3,
    drpdi_in_lane3,
    drpdo_out_lane3,
    drpen_in_lane3,
    drprdy_out_lane3,
    drpwe_in_lane3,
    tx_out_clk,

//------------------{
gt_common_reset_out,
//____________________________COMMON PORTS_______________________________{
gt0_pll0refclklost_in,
quad1_common_lock_in,
//----------------------- Channel - Ref Clock Ports ------------------------
gt0_pll0outclk_in,
gt0_pll1outclk_in,
gt0_pll0outrefclk_in,
gt0_pll1outrefclk_in,
//____________________________COMMON PORTS_______________________________}
//------------------}

    sys_reset_out,
    tx_lock
);


`define DLY #1
   
//***********************************Port Declarations*******************************
output   sys_reset_out;
//------------------{
output gt_common_reset_out;
//____________________________COMMON PORTS_______________________________{
input    gt0_pll0refclklost_in;
input    quad1_common_lock_in;
//----------------------- Channel - Ref Clock Ports ------------------------
input           gt0_pll0outclk_in;
input           gt0_pll1outclk_in;
input           gt0_pll0outrefclk_in;
input           gt0_pll1outrefclk_in;
//____________________________COMMON PORTS_______________________________}
//------------------}

    // AXI TX Interface
 
input   [0:127]    s_axi_tx_tdata;
 
input              s_axi_tx_tvalid;

output             s_axi_tx_tready;

    // AXI RX Interface
 
output  [0:127]    m_axi_rx_tdata;
 
output             m_axi_rx_tvalid;

    // Clock Correction Interface
input              do_cc;
input              warn_cc;
   
    //GT Serial I/O
input   [0:3]      rxp;
input   [0:3]      rxn;
output  [0:3]      txp;
output  [0:3]      txn;

    //GT Reference Clock Interface
input              gt_refclk1;

    //Error Detection Interface
output             hard_err;
output             soft_err;

    //Status
output             channel_up;
output  [0:3]      lane_up;

    //System Interface
input              user_clk;
input              sync_clk;
input              reset;
input              power_down;
input   [2:0]      loopback;
input              gt_reset;
output             tx_out_clk;
    input              init_clk_in;
    input              pll_not_locked;
    output             tx_resetdone_out;
    output             rx_resetdone_out;
    output             link_reset_out;


    //DRP Ports
input             drpclk_in;  
    input   [8:0]     drpaddr_in;  
    input             drpen_in;  
    input   [15:0]    drpdi_in;  
    output            drprdy_out;  
    output  [15:0]    drpdo_out;  
    input             drpwe_in;  
    input   [8:0]     drpaddr_in_lane1;  
    input             drpen_in_lane1;  
    input   [15:0]    drpdi_in_lane1;  
    output            drprdy_out_lane1;  
    output  [15:0]    drpdo_out_lane1;  
    input             drpwe_in_lane1;  
    input   [8:0]     drpaddr_in_lane2;  
    input             drpen_in_lane2;  
    input   [15:0]    drpdi_in_lane2;  
    output            drprdy_out_lane2;  
    output  [15:0]    drpdo_out_lane2;  
    input             drpwe_in_lane2;  
    input   [8:0]     drpaddr_in_lane3;  
    input             drpen_in_lane3;  
    input   [15:0]    drpdi_in_lane3;  
    output            drprdy_out_lane3;  
    output  [15:0]    drpdo_out_lane3;  
    input             drpwe_in_lane3;  

output             tx_lock;

//*********************************Wire Declarations**********************************

wire    [0:3]      TX1N_OUT_unused;
wire    [0:3]      TX1P_OUT_unused;
wire    [0:3]      RX1N_IN_unused;
wire    [0:3]      RX1P_IN_unused;
wire    [3:0]      rx_buf_err_i_unused;
wire    [15:0]     rx_char_is_comma_i_unused;
wire    [15:0]     rx_char_is_k_i_unused;
wire    [127:0]    rx_data_i_unused;
wire    [15:0]     rx_disp_err_i_unused;
wire    [15:0]     rx_not_in_table_i_unused;
wire    [3:0]      rx_realign_i_unused;
wire    [3:0]      tx_buf_err_i_unused;
wire    [3:0]      ch_bond_done_i_unused;

wire    [3:0]      ch_bond_done_i;
reg     [3:0]      ch_bond_done_r1;
reg     [3:0]      ch_bond_done_r2;
wire    [19:0]     rx_status_float_i;    
wire               channel_up_i;
wire               en_chan_sync_i;
wire    [3:0]      ena_comma_align_i;
wire    [0:3]      gen_a_i;
wire               gen_cc_i;
wire               gen_ecp_i;
wire    [0:1]      gen_ecp_striped_i;
wire    [0:15]     gen_k_i;
wire    [0:7]      gen_pad_i;
wire    [0:7]      gen_pad_striped_i;
wire    [0:15]     gen_r_i;
wire               gen_scp_i;
wire    [0:1]      gen_scp_striped_i;
wire    [0:15]     gen_v_i;
wire    [0:15]     got_a_i;
wire    [0:3]      got_v_i;
wire    [0:3]      hard_err_i;
wire    [0:3]      lane_up_i;
wire    [3:0]      pma_rx_lock_i;
wire    [0:3]      raw_tx_out_clk_i;
wire    [0:3]      reset_lanes_i;
wire    [3:0]      rx_buf_err_i;
wire    [15:0]     rx_char_is_comma_i;
wire    [15:0]     rx_char_is_k_i;
wire    [11:0]     rx_clk_cor_cnt_i;
wire    [127:0]    rx_data_i;
wire    [15:0]     rx_disp_err_i;
wire    [0:7]      rx_ecp_i;
wire    [0:7]      rx_ecp_striped_i;
wire    [15:0]     rx_not_in_table_i;
wire    [0:7]      rx_pad_i;
wire    [0:7]      rx_pad_striped_i;
wire    [0:127]    rx_pe_data_i;
wire    [0:127]    rx_pe_data_striped_i;
wire    [0:7]      rx_pe_data_v_i;
wire    [0:7]      rx_pe_data_v_striped_i;
wire    [3:0]      rx_polarity_i;
wire    [3:0]      rx_realign_i;
wire    [3:0]      rx_reset_i;
wire    [0:7]      rx_scp_i;
wire    [0:7]      rx_scp_striped_i;
wire    [0:7]      soft_err_i;
wire    [0:3]      all_soft_err_i;
wire               start_rx_i;
wire               tied_to_ground_i;
wire    [31:0]     tied_to_ground_vec_i;
wire               tied_to_vcc_i;
wire    [3:0]      tx_buf_err_i;
wire    [15:0]     tx_char_is_k_i;
wire    [127:0]    tx_data_i;
wire    [3:0]      tx_lock_i;
wire    [0:3]      tx_out_clk_i;
wire    [0:127]    tx_pe_data_i;
wire    [0:127]    tx_pe_data_striped_i;
wire    [0:7]      tx_pe_data_v_i;
wire    [0:7]      tx_pe_data_v_striped_i;
wire    [3:0]      tx_reset_i;
reg     [0:3]      ch_bond_load_pulse_i;
reg     [0:3]      ch_bond_done_dly_i;

    // TX AXI PDU I/F wires
wire    [0:127]    tx_data;
wire               tx_src_rdy;
wire               tx_dst_rdy;

    // RX AXI PDU I/F wires
wire    [0:127]    rx_data;
wire               rx_src_rdy;
    wire          link_reset_lane0_i;
    wire          link_reset_lane1_i;
    wire          link_reset_lane2_i;
    wire          link_reset_lane3_i;
    wire          link_reset_i;

wire   gtrxreset_i;
wire   system_reset_i;
wire   tx_lock_comb_i;
wire   tx_resetdone_i;
wire   rx_resetdone_i;
reg    rxfsm_data_valid_r;

//*********************************Main Body of Code**********************************



    //Tie off top level constants
    assign          tied_to_ground_vec_i    = 32'd0;
    assign          tied_to_ground_i        = 1'b0;
    assign          tied_to_vcc_i           = 1'b1;

    assign          all_soft_err_i[0] =  soft_err_i[0] | soft_err_i[1]  ;
    assign          all_soft_err_i[1] =  soft_err_i[2] | soft_err_i[3]  ;
    assign          all_soft_err_i[2] =  soft_err_i[4] | soft_err_i[5]  ;
    assign          all_soft_err_i[3] =  soft_err_i[6] | soft_err_i[7]  ;
    assign  link_reset_i   =  link_reset_lane0_i || link_reset_lane1_i || link_reset_lane2_i || link_reset_lane3_i ;

    always @ (posedge user_clk)
      rxfsm_data_valid_r  <= `DLY &lane_up_i;

    assign  link_reset_out = link_reset_i;
   
    //Connect top level logic
    assign          channel_up  =   channel_up_i;
    assign          tx_lock     =   tx_lock_comb_i;
    assign          tx_resetdone_out =  tx_resetdone_i;
    assign          rx_resetdone_out =  rx_resetdone_i;
    assign          sys_reset_out    =  system_reset_i;


    assign  tx_out_clk  =   raw_tx_out_clk_i [0];
    assign  tx_lock_comb_i          = &tx_lock_i;

    // RESET_LOGIC instance
    aurora_8b10b_RESET_LOGIC core_reset_logic_i
    (
        .RESET(reset),
        .USER_CLK(user_clk),
        .INIT_CLK_IN(init_clk_in),
        .TX_LOCK_IN(tx_lock_comb_i),
        .PLL_NOT_LOCKED(pll_not_locked),
	.TX_RESETDONE_IN(tx_resetdone_i),
	.RX_RESETDONE_IN(rx_resetdone_i),
        .LINK_RESET_IN(link_reset_i),
        .SYSTEM_RESET(system_reset_i)
    );

    //_________________________Instantiate Lane 0______________________________




assign          lane_up [0] =   lane_up_i [0];

    //Aurora lane striping rules require each 4-byte lane to carry 2 bytes from the first
    //half of the overall word, and 2 bytes from the second half. This ensures that the
    //data will be ordered correctly if it is send to a 2-byte lane. Here we perform the
    //required concatenation
   
    assign  gen_scp_striped_i       =   {gen_scp_i,1'b0};
    assign  gen_pad_striped_i[0:1]  =  {gen_pad_i[0],gen_pad_i[4]};
    assign  tx_pe_data_striped_i[0:31]   =   {tx_pe_data_i[0:15],tx_pe_data_i[64:79]};
    assign  tx_pe_data_v_striped_i[0:1]  =   {tx_pe_data_v_i[0],tx_pe_data_v_i[4]};
    assign  {rx_pad_i[0],rx_pad_i[4]}    =   rx_pad_striped_i[0:1];
    assign  {rx_pe_data_i[0:15],rx_pe_data_i[64:79]}   =   rx_pe_data_striped_i[0:31];
    assign  {rx_pe_data_v_i[0],rx_pe_data_v_i[4]}  = rx_pe_data_v_striped_i[0:1];
    assign  {rx_scp_i[0],rx_scp_i[4]}  =   rx_scp_striped_i[0:1];
    assign  {rx_ecp_i[0],rx_ecp_i[4]}  =   rx_ecp_striped_i[0:1];
   
   
   



    aurora_8b10b_AURORA_LANE_4BYTE aurora_8b10b_aurora_lane_4byte_0_i
    (
        //GT Interface
        .RX_DATA(rx_data_i[31:0]),
        .RX_NOT_IN_TABLE(rx_not_in_table_i[3:0]),
        .RX_DISP_ERR(rx_disp_err_i[3:0]),
        .RX_CHAR_IS_K(rx_char_is_k_i[3:0]),
        .RX_CHAR_IS_COMMA(rx_char_is_comma_i[3:0]),
        .RX_STATUS(tied_to_ground_vec_i[5:0]),
.TX_BUF_ERR(tx_buf_err_i [0]),
.RX_BUF_ERR(rx_buf_err_i [0]),
.RX_REALIGN(rx_realign_i [0]),
.RX_POLARITY(rx_polarity_i [0]),
.RX_RESET(rx_reset_i [0]),
        .TX_CHAR_IS_K(tx_char_is_k_i[3:0]),
        .TX_DATA(tx_data_i[31:0]),
.TX_RESET(tx_reset_i [0]),
        .INIT_CLK(init_clk_in),
        .LINK_RESET_OUT(link_reset_lane0_i),
       
        //Comma Detect Phase Align Interface
.ENA_COMMA_ALIGN(ena_comma_align_i [0]),


        //TX_LL Interface
        .GEN_SCP(gen_scp_striped_i),
        .GEN_ECP(tied_to_ground_vec_i[1:0]),
        .GEN_PAD(gen_pad_striped_i[0:1]),
        .TX_PE_DATA(tx_pe_data_striped_i[0:31]),
        .TX_PE_DATA_V(tx_pe_data_v_striped_i[0:1]),
        .GEN_CC(gen_cc_i),


        //RX_LL Interface
        .RX_PAD(rx_pad_striped_i[0:1]),
        .RX_PE_DATA(rx_pe_data_striped_i[0:31]),
        .RX_PE_DATA_V(rx_pe_data_v_striped_i[0:1]),
        .RX_SCP(rx_scp_striped_i[0:1]),
        .RX_ECP(rx_ecp_striped_i[0:1]),


        //Global Logic Interface
.GEN_A(gen_a_i [0]),
        .GEN_K(gen_k_i[0:3]),
        .GEN_R(gen_r_i[0:3]),
        .GEN_V(gen_v_i[0:3]),
.LANE_UP(lane_up_i [0]),
        .SOFT_ERR(soft_err_i[0:1]),
.HARD_ERR(hard_err_i [0]),
        .CHANNEL_BOND_LOAD(),
        .GOT_A(got_a_i[0:3]),
.GOT_V(got_v_i [0]),
        .CHANNEL_UP(channel_up_i),


        //System Interface
        .USER_CLK(user_clk),
        .RESET_SYMGEN(system_reset_i),
.RESET(reset_lanes_i [0])
    );

    //_________________________Instantiate Lane 1______________________________




assign          lane_up [1] =   lane_up_i [1];

    //Aurora lane striping rules require each 4-byte lane to carry 2 bytes from the first
    //half of the overall word, and 2 bytes from the second half. This ensures that the
    //data will be ordered correctly if it is send to a 2-byte lane. Here we perform the
    //required concatenation
    assign  gen_pad_striped_i[2:3]  =  {gen_pad_i[1],gen_pad_i[5]};
    assign  tx_pe_data_striped_i[32:63]   =   {tx_pe_data_i[16:31],tx_pe_data_i[80:95]};
    assign  tx_pe_data_v_striped_i[2:3]  =   {tx_pe_data_v_i[1],tx_pe_data_v_i[5]};
    assign  {rx_pad_i[1],rx_pad_i[5]}    =   rx_pad_striped_i[2:3];
    assign  {rx_pe_data_i[16:31],rx_pe_data_i[80:95]}   =   rx_pe_data_striped_i[32:63];
    assign  {rx_pe_data_v_i[1],rx_pe_data_v_i[5]}  = rx_pe_data_v_striped_i[2:3];
    assign  {rx_scp_i[1],rx_scp_i[5]}  =   rx_scp_striped_i[2:3];
    assign  {rx_ecp_i[1],rx_ecp_i[5]}  =   rx_ecp_striped_i[2:3];
   
   
   



    aurora_8b10b_AURORA_LANE_4BYTE aurora_8b10b_aurora_lane_4byte_1_i
    (
        //GT Interface
        .RX_DATA(rx_data_i[63:32]),
        .RX_NOT_IN_TABLE(rx_not_in_table_i[7:4]),
        .RX_DISP_ERR(rx_disp_err_i[7:4]),
        .RX_CHAR_IS_K(rx_char_is_k_i[7:4]),
        .RX_CHAR_IS_COMMA(rx_char_is_comma_i[7:4]),
        .RX_STATUS(tied_to_ground_vec_i[5:0]),
.TX_BUF_ERR(tx_buf_err_i [1]),
.RX_BUF_ERR(rx_buf_err_i [1]),
.RX_REALIGN(rx_realign_i [1]),
.RX_POLARITY(rx_polarity_i [1]),
.RX_RESET(rx_reset_i [1]),
        .TX_CHAR_IS_K(tx_char_is_k_i[7:4]),
        .TX_DATA(tx_data_i[63:32]),
.TX_RESET(tx_reset_i [1]),
        .INIT_CLK(init_clk_in),
        .LINK_RESET_OUT(link_reset_lane1_i),
       
        //Comma Detect Phase Align Interface
.ENA_COMMA_ALIGN(ena_comma_align_i [1]),


        //TX_LL Interface
        .GEN_SCP(tied_to_ground_vec_i[1:0]),
        .GEN_ECP(tied_to_ground_vec_i[1:0]),
        .GEN_PAD(gen_pad_striped_i[2:3]),
        .TX_PE_DATA(tx_pe_data_striped_i[32:63]),
        .TX_PE_DATA_V(tx_pe_data_v_striped_i[2:3]),
        .GEN_CC(gen_cc_i),


        //RX_LL Interface
        .RX_PAD(rx_pad_striped_i[2:3]),
        .RX_PE_DATA(rx_pe_data_striped_i[32:63]),
        .RX_PE_DATA_V(rx_pe_data_v_striped_i[2:3]),
        .RX_SCP(rx_scp_striped_i[2:3]),
        .RX_ECP(rx_ecp_striped_i[2:3]),


        //Global Logic Interface
.GEN_A(gen_a_i [1]),
        .GEN_K(gen_k_i[4:7]),
        .GEN_R(gen_r_i[4:7]),
        .GEN_V(gen_v_i[4:7]),
.LANE_UP(lane_up_i [1]),
        .SOFT_ERR(soft_err_i[2:3]),
.HARD_ERR(hard_err_i [1]),
        .CHANNEL_BOND_LOAD(),
        .GOT_A(got_a_i[4:7]),
.GOT_V(got_v_i [1]),
        .CHANNEL_UP(channel_up_i),


        //System Interface
        .USER_CLK(user_clk),
        .RESET_SYMGEN(system_reset_i),
.RESET(reset_lanes_i [1])
    );

    //_________________________Instantiate Lane 2______________________________




assign          lane_up [2] =   lane_up_i [2];

    //Aurora lane striping rules require each 4-byte lane to carry 2 bytes from the first
    //half of the overall word, and 2 bytes from the second half. This ensures that the
    //data will be ordered correctly if it is send to a 2-byte lane. Here we perform the
    //required concatenation
    assign  gen_pad_striped_i[4:5]  =  {gen_pad_i[2],gen_pad_i[6]};
    assign  tx_pe_data_striped_i[64:95]   =   {tx_pe_data_i[32:47],tx_pe_data_i[96:111]};
    assign  tx_pe_data_v_striped_i[4:5]  =   {tx_pe_data_v_i[2],tx_pe_data_v_i[6]};
    assign  {rx_pad_i[2],rx_pad_i[6]}    =   rx_pad_striped_i[4:5];
    assign  {rx_pe_data_i[32:47],rx_pe_data_i[96:111]}   =   rx_pe_data_striped_i[64:95];
    assign  {rx_pe_data_v_i[2],rx_pe_data_v_i[6]}  = rx_pe_data_v_striped_i[4:5];
    assign  {rx_scp_i[2],rx_scp_i[6]}  =   rx_scp_striped_i[4:5];
    assign  {rx_ecp_i[2],rx_ecp_i[6]}  =   rx_ecp_striped_i[4:5];
   
   
   



    aurora_8b10b_AURORA_LANE_4BYTE aurora_8b10b_aurora_lane_4byte_2_i
    (
        //GT Interface
        .RX_DATA(rx_data_i[95:64]),
        .RX_NOT_IN_TABLE(rx_not_in_table_i[11:8]),
        .RX_DISP_ERR(rx_disp_err_i[11:8]),
        .RX_CHAR_IS_K(rx_char_is_k_i[11:8]),
        .RX_CHAR_IS_COMMA(rx_char_is_comma_i[11:8]),
        .RX_STATUS(tied_to_ground_vec_i[5:0]),
.TX_BUF_ERR(tx_buf_err_i [2]),
.RX_BUF_ERR(rx_buf_err_i [2]),
.RX_REALIGN(rx_realign_i [2]),
.RX_POLARITY(rx_polarity_i [2]),
.RX_RESET(rx_reset_i [2]),
        .TX_CHAR_IS_K(tx_char_is_k_i[11:8]),
        .TX_DATA(tx_data_i[95:64]),
.TX_RESET(tx_reset_i [2]),
        .INIT_CLK(init_clk_in),
        .LINK_RESET_OUT(link_reset_lane2_i),
       
        //Comma Detect Phase Align Interface
.ENA_COMMA_ALIGN(ena_comma_align_i [2]),


        //TX_LL Interface
        .GEN_SCP(tied_to_ground_vec_i[1:0]),
        .GEN_ECP(tied_to_ground_vec_i[1:0]),
        .GEN_PAD(gen_pad_striped_i[4:5]),
        .TX_PE_DATA(tx_pe_data_striped_i[64:95]),
        .TX_PE_DATA_V(tx_pe_data_v_striped_i[4:5]),
        .GEN_CC(gen_cc_i),


        //RX_LL Interface
        .RX_PAD(rx_pad_striped_i[4:5]),
        .RX_PE_DATA(rx_pe_data_striped_i[64:95]),
        .RX_PE_DATA_V(rx_pe_data_v_striped_i[4:5]),
        .RX_SCP(rx_scp_striped_i[4:5]),
        .RX_ECP(rx_ecp_striped_i[4:5]),


        //Global Logic Interface
.GEN_A(gen_a_i [2]),
        .GEN_K(gen_k_i[8:11]),
        .GEN_R(gen_r_i[8:11]),
        .GEN_V(gen_v_i[8:11]),
.LANE_UP(lane_up_i [2]),
        .SOFT_ERR(soft_err_i[4:5]),
.HARD_ERR(hard_err_i [2]),
        .CHANNEL_BOND_LOAD(),
        .GOT_A(got_a_i[8:11]),
.GOT_V(got_v_i [2]),
        .CHANNEL_UP(channel_up_i),


        //System Interface
        .USER_CLK(user_clk),
        .RESET_SYMGEN(system_reset_i),
.RESET(reset_lanes_i [2])
    );

    //_________________________Instantiate Lane 3______________________________




assign          lane_up [3] =   lane_up_i [3];

    //Aurora lane striping rules require each 4-byte lane to carry 2 bytes from the first
    //half of the overall word, and 2 bytes from the second half. This ensures that the
    //data will be ordered correctly if it is send to a 2-byte lane. Here we perform the
    //required concatenation
    assign  gen_ecp_striped_i       =   {1'b0,gen_ecp_i};
    assign  gen_pad_striped_i[6:7]  =  {gen_pad_i[3],gen_pad_i[7]};
    assign  tx_pe_data_striped_i[96:127]   =   {tx_pe_data_i[48:63],tx_pe_data_i[112:127]};
    assign  tx_pe_data_v_striped_i[6:7]  =   {tx_pe_data_v_i[3],tx_pe_data_v_i[7]};
    assign  {rx_pad_i[3],rx_pad_i[7]}    =   rx_pad_striped_i[6:7];
    assign  {rx_pe_data_i[48:63],rx_pe_data_i[112:127]}   =   rx_pe_data_striped_i[96:127];
    assign  {rx_pe_data_v_i[3],rx_pe_data_v_i[7]}  = rx_pe_data_v_striped_i[6:7];
    assign  {rx_scp_i[3],rx_scp_i[7]}  =   rx_scp_striped_i[6:7];
    assign  {rx_ecp_i[3],rx_ecp_i[7]}  =   rx_ecp_striped_i[6:7];
   
   
   



    aurora_8b10b_AURORA_LANE_4BYTE aurora_8b10b_aurora_lane_4byte_3_i
    (
        //GT Interface
        .RX_DATA(rx_data_i[127:96]),
        .RX_NOT_IN_TABLE(rx_not_in_table_i[15:12]),
        .RX_DISP_ERR(rx_disp_err_i[15:12]),
        .RX_CHAR_IS_K(rx_char_is_k_i[15:12]),
        .RX_CHAR_IS_COMMA(rx_char_is_comma_i[15:12]),
        .RX_STATUS(tied_to_ground_vec_i[5:0]),
.TX_BUF_ERR(tx_buf_err_i [3]),
.RX_BUF_ERR(rx_buf_err_i [3]),
.RX_REALIGN(rx_realign_i [3]),
.RX_POLARITY(rx_polarity_i [3]),
.RX_RESET(rx_reset_i [3]),
        .TX_CHAR_IS_K(tx_char_is_k_i[15:12]),
        .TX_DATA(tx_data_i[127:96]),
.TX_RESET(tx_reset_i [3]),
        .INIT_CLK(init_clk_in),
        .LINK_RESET_OUT(link_reset_lane3_i),
       
        //Comma Detect Phase Align Interface
.ENA_COMMA_ALIGN(ena_comma_align_i [3]),


        //TX_LL Interface
        .GEN_SCP(tied_to_ground_vec_i[1:0]),
        .GEN_ECP(gen_ecp_striped_i),
        .GEN_PAD(gen_pad_striped_i[6:7]),
        .TX_PE_DATA(tx_pe_data_striped_i[96:127]),
        .TX_PE_DATA_V(tx_pe_data_v_striped_i[6:7]),
        .GEN_CC(gen_cc_i),


        //RX_LL Interface
        .RX_PAD(rx_pad_striped_i[6:7]),
        .RX_PE_DATA(rx_pe_data_striped_i[96:127]),
        .RX_PE_DATA_V(rx_pe_data_v_striped_i[6:7]),
        .RX_SCP(rx_scp_striped_i[6:7]),
        .RX_ECP(rx_ecp_striped_i[6:7]),


        //Global Logic Interface
.GEN_A(gen_a_i [3]),
        .GEN_K(gen_k_i[12:15]),
        .GEN_R(gen_r_i[12:15]),
        .GEN_V(gen_v_i[12:15]),
.LANE_UP(lane_up_i [3]),
        .SOFT_ERR(soft_err_i[6:7]),
.HARD_ERR(hard_err_i [3]),
        .CHANNEL_BOND_LOAD(),
        .GOT_A(got_a_i[12:15]),
.GOT_V(got_v_i [3]),
        .CHANNEL_UP(channel_up_i),


        //System Interface
        .USER_CLK(user_clk),
        .RESET_SYMGEN(system_reset_i),
.RESET(reset_lanes_i [3])
    );


   

    //_________________________Instantiate GT Wrapper ______________________________


    aurora_8b10b_GT_WRAPPER #
    (
         .SIM_GTRESET_SPEEDUP(SIM_GTRESET_SPEEDUP)
    )

    gt_wrapper_i

    (
        .RXFSM_DATA_VALID            (rxfsm_data_valid_r),

        .gt0_txresetdone_out                (),
        .gt0_rxresetdone_out                (),
        .gt0_rxpmaresetdone_out             (),
        .gt0_txbufstatus_out                (),
        .gt0_rxbufstatus_out                (),
        .gt1_txresetdone_out                (),
        .gt1_rxresetdone_out                (),
        .gt1_rxpmaresetdone_out             (),
        .gt1_txbufstatus_out                (),
        .gt1_rxbufstatus_out                (),
        .gt2_txresetdone_out                (),
        .gt2_rxresetdone_out                (),
        .gt2_rxpmaresetdone_out             (),
        .gt2_txbufstatus_out                (),
        .gt2_rxbufstatus_out                (),
        .gt3_txresetdone_out                (),
        .gt3_rxresetdone_out                (),
        .gt3_rxpmaresetdone_out             (),
        .gt3_txbufstatus_out                (),
        .gt3_rxbufstatus_out                (),
        // DRP I/F
.DRPADDR_IN                     (drpaddr_in),
.DRPCLK_IN                      (drpclk_in),
.DRPDI_IN                       (drpdi_in),
.DRPDO_OUT                      (drpdo_out),
.DRPEN_IN                       (drpen_in),
.DRPRDY_OUT                     (drprdy_out),
.DRPWE_IN                       (drpwe_in),
.DRPADDR_IN_LANE1                     (drpaddr_in_lane1),
.DRPCLK_IN_LANE1                      (drpclk_in),
.DRPDI_IN_LANE1                       (drpdi_in_lane1),
.DRPDO_OUT_LANE1                      (drpdo_out_lane1),
.DRPEN_IN_LANE1                       (drpen_in_lane1),
.DRPRDY_OUT_LANE1                     (drprdy_out_lane1),
.DRPWE_IN_LANE1                       (drpwe_in_lane1),
.DRPADDR_IN_LANE2                     (drpaddr_in_lane2),
.DRPCLK_IN_LANE2                      (drpclk_in),
.DRPDI_IN_LANE2                       (drpdi_in_lane2),
.DRPDO_OUT_LANE2                      (drpdo_out_lane2),
.DRPEN_IN_LANE2                       (drpen_in_lane2),
.DRPRDY_OUT_LANE2                     (drprdy_out_lane2),
.DRPWE_IN_LANE2                       (drpwe_in_lane2),
.DRPADDR_IN_LANE3                     (drpaddr_in_lane3),
.DRPCLK_IN_LANE3                      (drpclk_in),
.DRPDI_IN_LANE3                       (drpdi_in_lane3),
.DRPDO_OUT_LANE3                      (drpdo_out_lane3),
.DRPEN_IN_LANE3                       (drpen_in_lane3),
.DRPRDY_OUT_LANE3                     (drprdy_out_lane3),
.DRPWE_IN_LANE3                       (drpwe_in_lane3),

        .INIT_CLK_IN                    (init_clk_in),   
	.PLL_NOT_LOCKED                 (pll_not_locked),
	.TX_RESETDONE_OUT               (tx_resetdone_i),
	.RX_RESETDONE_OUT               (rx_resetdone_i),

        //Aurora Lane Interface
.RXPOLARITY_IN(rx_polarity_i [0]),
.RXPOLARITY_IN_LANE1(rx_polarity_i [1]),
.RXPOLARITY_IN_LANE2(rx_polarity_i [2]),
.RXPOLARITY_IN_LANE3(rx_polarity_i [3]),
.RXRESET_IN(rx_reset_i [0]),
.RXRESET_IN_LANE1(rx_reset_i [1]),
.RXRESET_IN_LANE2(rx_reset_i [2]),
.RXRESET_IN_LANE3(rx_reset_i [3]),
.TXCHARISK_IN(tx_char_is_k_i[3:0]),
.TXCHARISK_IN_LANE1(tx_char_is_k_i[7:4]),
.TXCHARISK_IN_LANE2(tx_char_is_k_i[11:8]),
.TXCHARISK_IN_LANE3(tx_char_is_k_i[15:12]),
.TXDATA_IN(tx_data_i[31:0]),
.TXDATA_IN_LANE1(tx_data_i[63:32]),
.TXDATA_IN_LANE2(tx_data_i[95:64]),
.TXDATA_IN_LANE3(tx_data_i[127:96]),
.TXRESET_IN(tx_reset_i [0]),
.TXRESET_IN_LANE1(tx_reset_i [1]),
.TXRESET_IN_LANE2(tx_reset_i [2]),
.TXRESET_IN_LANE3(tx_reset_i [3]),
.RXDATA_OUT(rx_data_i[31:0]),
.RXDATA_OUT_LANE1(rx_data_i[63:32]),
.RXDATA_OUT_LANE2(rx_data_i[95:64]),
.RXDATA_OUT_LANE3(rx_data_i[127:96]),
.RXNOTINTABLE_OUT(rx_not_in_table_i[3:0]),
.RXNOTINTABLE_OUT_LANE1(rx_not_in_table_i[7:4]),
.RXNOTINTABLE_OUT_LANE2(rx_not_in_table_i[11:8]),
.RXNOTINTABLE_OUT_LANE3(rx_not_in_table_i[15:12]),
.RXDISPERR_OUT(rx_disp_err_i[3:0]),
.RXDISPERR_OUT_LANE1(rx_disp_err_i[7:4]),
.RXDISPERR_OUT_LANE2(rx_disp_err_i[11:8]),
.RXDISPERR_OUT_LANE3(rx_disp_err_i[15:12]),
.RXCHARISK_OUT(rx_char_is_k_i[3:0]),
.RXCHARISK_OUT_LANE1(rx_char_is_k_i[7:4]),
.RXCHARISK_OUT_LANE2(rx_char_is_k_i[11:8]),
.RXCHARISK_OUT_LANE3(rx_char_is_k_i[15:12]),
.RXCHARISCOMMA_OUT(rx_char_is_comma_i[3:0]),
.RXCHARISCOMMA_OUT_LANE1(rx_char_is_comma_i[7:4]),
.RXCHARISCOMMA_OUT_LANE2(rx_char_is_comma_i[11:8]),
.RXCHARISCOMMA_OUT_LANE3(rx_char_is_comma_i[15:12]),
.RXREALIGN_OUT(rx_realign_i [0]),
.RXREALIGN_OUT_LANE1(rx_realign_i [1]),
.RXREALIGN_OUT_LANE2(rx_realign_i [2]),
.RXREALIGN_OUT_LANE3(rx_realign_i [3]),
.RXBUFERR_OUT(rx_buf_err_i [0]),
.RXBUFERR_OUT_LANE1(rx_buf_err_i [1]),
.RXBUFERR_OUT_LANE2(rx_buf_err_i [2]),
.RXBUFERR_OUT_LANE3(rx_buf_err_i [3]),
.TXBUFERR_OUT(tx_buf_err_i [0]),
.TXBUFERR_OUT_LANE1(tx_buf_err_i [1]),
.TXBUFERR_OUT_LANE2(tx_buf_err_i [2]),
.TXBUFERR_OUT_LANE3(tx_buf_err_i [3]),

        // Reset due to channel initialization watchdog timer expiry  
        .GTRXRESET_IN(gtrxreset_i),

        // reset for hot plug
        .LINK_RESET_IN(link_reset_i),

      // Phase Align Interface
.ENMCOMMAALIGN_IN(ena_comma_align_i [0]),
.ENMCOMMAALIGN_IN_LANE1(ena_comma_align_i [1]),
.ENMCOMMAALIGN_IN_LANE2(ena_comma_align_i [2]),
.ENMCOMMAALIGN_IN_LANE3(ena_comma_align_i [3]),
.ENPCOMMAALIGN_IN(ena_comma_align_i [0]),
.ENPCOMMAALIGN_IN_LANE1(ena_comma_align_i [1]),
.ENPCOMMAALIGN_IN_LANE2(ena_comma_align_i [2]),
.ENPCOMMAALIGN_IN_LANE3(ena_comma_align_i [3]),
        
        //Global Logic Interface
.ENCHANSYNC_IN(tied_to_vcc_i),
.ENCHANSYNC_IN_LANE1(en_chan_sync_i),
.ENCHANSYNC_IN_LANE2(tied_to_vcc_i),
.ENCHANSYNC_IN_LANE3(tied_to_vcc_i),
.CHBONDDONE_OUT(ch_bond_done_i [0]),
.CHBONDDONE_OUT_LANE1(ch_bond_done_i [1]),
.CHBONDDONE_OUT_LANE2(ch_bond_done_i [2]),
.CHBONDDONE_OUT_LANE3(ch_bond_done_i [3]),

        //Serial IO
.RX1N_IN(rxn [0]),
.RX1N_IN_LANE1(rxn [1]),
.RX1N_IN_LANE2(rxn [2]),
.RX1N_IN_LANE3(rxn [3]),
.RX1P_IN(rxp [0]),
.RX1P_IN_LANE1(rxp [1]),
.RX1P_IN_LANE2(rxp [2]),
.RX1P_IN_LANE3(rxp [3]),
.TX1N_OUT(txn [0]),
.TX1N_OUT_LANE1(txn [1]),
.TX1N_OUT_LANE2(txn [2]),
.TX1N_OUT_LANE3(txn [3]),
.TX1P_OUT(txp [0]),
.TX1P_OUT_LANE1(txp [1]),
.TX1P_OUT_LANE2(txp [2]),
.TX1P_OUT_LANE3(txp [3]),

        // Clocks and Clock Status
        .RXUSRCLK_IN(sync_clk),
        .RXUSRCLK2_IN(user_clk),
        .TXUSRCLK_IN(sync_clk),
        .TXUSRCLK2_IN(user_clk),
        .REFCLK(gt_refclk1),

.TXOUTCLK1_OUT(raw_tx_out_clk_i [0]),
.TXOUTCLK1_OUT_LANE1(raw_tx_out_clk_i [1]),
.TXOUTCLK1_OUT_LANE2(raw_tx_out_clk_i [2]),
.TXOUTCLK1_OUT_LANE3(raw_tx_out_clk_i [3]),
.PLLLKDET_OUT(tx_lock_i [0]),
.PLLLKDET_OUT_LANE1(tx_lock_i [1]),
.PLLLKDET_OUT_LANE2(tx_lock_i [2]),
.PLLLKDET_OUT_LANE3(tx_lock_i [3]),

        //System Interface
        .GTRESET_IN(gt_reset),
        .LOOPBACK_IN(loopback),

//------------------{
.gt_common_reset_out    (gt_common_reset_out),
//____________________________COMMON PORTS_______________________________{
.gt0_pll0refclklost_in  (gt0_pll0refclklost_in),
.quad1_common_lock_in (quad1_common_lock_in),
//----------------------- Channel - Ref Clock Ports ------------------------
.gt0_pll0outclk_in       (gt0_pll0outclk_in),
.gt0_pll1outclk_in       (gt0_pll1outclk_in),
.gt0_pll0outrefclk_in    (gt0_pll0outrefclk_in),
.gt0_pll1outrefclk_in    (gt0_pll1outrefclk_in),
//____________________________COMMON PORTS_______________________________}
//------------------}

        .POWERDOWN_IN(power_down)
    );

    //__________Instantiate Global Logic to combine Lanes into a Channel______

  // FF stages added for timing closure
  always @(posedge user_clk)
        ch_bond_done_r1  <=  `DLY    ch_bond_done_i;

  always @(posedge user_clk)
        ch_bond_done_r2  <=  `DLY    ch_bond_done_r1;

  always @(posedge user_clk)
       if (system_reset_i)
         ch_bond_done_dly_i <= 4'b0;
       else if (en_chan_sync_i)
         ch_bond_done_dly_i <= ch_bond_done_r2;
       else
         ch_bond_done_dly_i <= 4'b0;

  always @(posedge user_clk)
      if (system_reset_i)
        ch_bond_load_pulse_i <= 4'b0;
      else if(en_chan_sync_i)
        ch_bond_load_pulse_i <= ch_bond_done_r2 & ~ch_bond_done_dly_i;
      else
        ch_bond_load_pulse_i <= 4'b0;

    aurora_8b10b_GLOBAL_LOGIC    aurora_8b10b_global_logic_i
    (
        //GT Interface
        .CH_BOND_DONE(ch_bond_done_i),
        .EN_CHAN_SYNC(en_chan_sync_i),


        //Aurora Lane Interface
        .LANE_UP(lane_up_i),
        .SOFT_ERR(soft_err_i),
        .HARD_ERR(hard_err_i),
        .CHANNEL_BOND_LOAD(ch_bond_load_pulse_i),
        .GOT_A(got_a_i),
        .GOT_V(got_v_i),
        .GEN_A(gen_a_i),
        .GEN_K(gen_k_i),
        .GEN_R(gen_r_i),
        .GEN_V(gen_v_i),
        .RESET_LANES(reset_lanes_i),
        .GTRXRESET_OUT(gtrxreset_i),

        //System Interface
        .USER_CLK(user_clk),
        .RESET(system_reset_i),
        .POWER_DOWN(power_down),
        .CHANNEL_UP(channel_up_i),
        .START_RX(start_rx_i),
        .CHANNEL_SOFT_ERR(soft_err),
        .CHANNEL_HARD_ERR(hard_err)
    );


    //_____________________________ TX AXI SHIM _______________________________
    aurora_8b10b_AXI_TO_LL #
    (
       .DATA_WIDTH(128),
       .STRB_WIDTH(16),
       .USE_4_NFC (0),
       .REM_WIDTH (4)
    )

    axi_to_ll_pdu_i
    (
     .AXI4_S_IP_TX_TVALID(s_axi_tx_tvalid),
     .AXI4_S_IP_TX_TREADY(s_axi_tx_tready),
     .AXI4_S_IP_TX_TDATA(s_axi_tx_tdata),
     .AXI4_S_IP_TX_TKEEP(),
     .AXI4_S_IP_TX_TLAST(),

     .LL_OP_DATA(tx_data),
     .LL_OP_SOF_N(),
     .LL_OP_EOF_N(),
     .LL_OP_REM(),
     .LL_OP_SRC_RDY_N(tx_src_rdy),
     .LL_IP_DST_RDY_N(tx_dst_rdy),

     // System Interface
     .USER_CLK(user_clk),
     .RESET(system_reset_i), 
     .CHANNEL_UP(channel_up_i)
    );

    //_____________________________Instantiate TX_STREAM___________________________

   
    aurora_8b10b_TX_STREAM aurora_8b10b_tx_stream_i
    (
        // AXI PDU Interface
        .TX_D(tx_data),
        .TX_SRC_RDY_N(tx_src_rdy),
        .TX_DST_RDY_N(tx_dst_rdy),

        // Global Logic Interface
        .CHANNEL_UP(channel_up_i),

        //Clock Correction Interface
        .DO_CC(do_cc),
        .WARN_CC(warn_cc),
       
        // Aurora Lane Interface
        .GEN_SCP(gen_scp_i),
        .GEN_ECP(gen_ecp_i),
        .TX_PE_DATA_V(tx_pe_data_v_i),
        .GEN_PAD(gen_pad_i),
        .TX_PE_DATA(tx_pe_data_i),
        .GEN_CC(gen_cc_i),


        // System Interface
        .USER_CLK(user_clk)
    );

    //_____________________________ RX AXI SHIM _______________________________
    aurora_8b10b_LL_TO_AXI #
    (
       .DATA_WIDTH(128),
       .STRB_WIDTH(16),
       .REM_WIDTH (4)
    )

    ll_to_axi_pdu_i
    (
     .LL_IP_DATA(rx_data),
     .LL_IP_SOF_N(),
     .LL_IP_EOF_N(),
     .LL_IP_REM(),
     .LL_IP_SRC_RDY_N(rx_src_rdy),
     .LL_OP_DST_RDY_N(),

     .AXI4_S_OP_TVALID(m_axi_rx_tvalid),
     .AXI4_S_OP_TDATA(m_axi_rx_tdata),
     .AXI4_S_OP_TKEEP(),
     .AXI4_S_OP_TLAST(),
     .AXI4_S_IP_TREADY()

    );

    //_____________________________ Instantiate RX_STREAM____________________________
   
   
    aurora_8b10b_RX_STREAM aurora_8b10b_rx_stream_i
    (
        // AXI PDU Interface
        .RX_D(rx_data),
        .RX_SRC_RDY_N(rx_src_rdy),
   
        // Global Logic Interface
        .START_RX(start_rx_i),
   
        // Aurora Lane Interface
        .RX_PAD(rx_pad_i),
        .RX_PE_DATA(rx_pe_data_i),
        .RX_PE_DATA_V(rx_pe_data_v_i),
        .RX_SCP(rx_scp_i),
        .RX_ECP(rx_ecp_i),
  
        // System Interface
        .USER_CLK(user_clk)
    );

endmodule 
