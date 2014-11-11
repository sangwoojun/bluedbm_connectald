// Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
// Date        : Mon Sep 15 21:25:32 2014
// Host        : appa running 64-bit Ubuntu 12.04.4 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/mingliu/NandController/vivado_2014_1_lin64_GTP/project_2014_1/project_2014_1.srcs/sources_1/ip/vio_0/vio_0_stub.v
// Design      : vio_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2014.1" *)
module vio_0(clk, probe_in0, probe_out0)
/* synthesis syn_black_box black_box_pad_pin="clk,probe_in0[63:0],probe_out0[63:0]" */;
  input clk;
  input [63:0]probe_in0;
  output [63:0]probe_out0;
endmodule
