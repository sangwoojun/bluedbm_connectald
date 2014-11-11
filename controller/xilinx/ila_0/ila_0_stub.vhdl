-- Copyright 1986-2014 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2014.1 (lin64) Build 881834 Fri Apr  4 14:00:25 MDT 2014
-- Date        : Mon Sep 15 21:30:51 2014
-- Host        : appa running 64-bit Ubuntu 12.04.4 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/mingliu/NandController/vivado_2014_1_lin64_GTP/project_2014_1/project_2014_1.srcs/sources_1/ip/ila_0/ila_0_stub.vhdl
-- Design      : ila_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a200tfbg676-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ila_0 is
  Port ( 
    clk : in STD_LOGIC;
    probe0 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe1 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe2 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe3 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe4 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe5 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe6 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe7 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe8 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe9 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe10 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe11 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe12 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe13 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe14 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe15 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe16 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe17 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe18 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe19 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe20 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe21 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe22 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe23 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe24 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe25 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe26 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe27 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe28 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe29 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe30 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe31 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe32 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe33 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe34 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe35 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe36 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe37 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe38 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe39 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe40 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe41 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe42 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe43 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe44 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe45 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe46 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe47 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe48 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe49 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe50 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe51 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe52 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe53 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    probe54 : in STD_LOGIC_VECTOR ( 63 downto 0 );
    probe55 : in STD_LOGIC_VECTOR ( 63 downto 0 )
  );

end ila_0;

architecture stub of ila_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe0[15:0],probe1[15:0],probe2[15:0],probe3[15:0],probe4[15:0],probe5[63:0],probe6[63:0],probe7[15:0],probe8[15:0],probe9[15:0],probe10[15:0],probe11[15:0],probe12[63:0],probe13[63:0],probe14[15:0],probe15[15:0],probe16[15:0],probe17[15:0],probe18[15:0],probe19[63:0],probe20[63:0],probe21[15:0],probe22[15:0],probe23[15:0],probe24[15:0],probe25[15:0],probe26[63:0],probe27[63:0],probe28[15:0],probe29[15:0],probe30[15:0],probe31[15:0],probe32[15:0],probe33[63:0],probe34[63:0],probe35[15:0],probe36[15:0],probe37[15:0],probe38[15:0],probe39[15:0],probe40[63:0],probe41[63:0],probe42[15:0],probe43[15:0],probe44[15:0],probe45[15:0],probe46[15:0],probe47[63:0],probe48[63:0],probe49[15:0],probe50[15:0],probe51[15:0],probe52[15:0],probe53[15:0],probe54[63:0],probe55[63:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "ila,Vivado 2014.1";
begin
end;
