// Copyright (c) 2014 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Vector            :: *;
import Connectable       :: *;
import Xilinx            :: *;
import Portal            :: *;
import Leds              :: *;
import Top               :: *;
import PcieTopDbm           :: *;

import XilinxVC707DDR3 :: *;
import AuroraImportVC707:: *;

(* synthesize *)
module mkSynthesizeablePortalTop#(Clock clk, Reset rst, 
			  Vector#(QuadCount, Clock) gtx_clk_p,
			  Vector#(QuadCount, Clock) gtx_clk_n
		) (PortalTop#(40, 64, BlueDBMTopPins, 1));
   let top <- mkPortalTop(clk, rst, gtx_clk_p, gtx_clk_n);
   interface masters = top.masters;
   interface slave = top.slave;
   interface interrupt = top.interrupt;
   interface leds = top.leds;
   interface pins = top.pins;
endmodule

module mkPcieTop #(Clock pci_sys_clk_p, Clock pci_sys_clk_n,
   Clock sys_clk_p,     Clock sys_clk_n,
   Reset pci_sys_reset_n,
   Clock gtx_clk_0_p, Clock gtx_clk_0_n,
   Clock gtx_clk_1_0_p, Clock gtx_clk_1_0_n/*,
   Clock gtx_clk_116_p, Clock gtx_clk_116_n*/
   )
   (PcieTop#(BlueDBMTopPins));

   Vector#(QuadCount,Clock) gtx_clk_p;
   gtx_clk_p[0] = gtx_clk_0_p;
   gtx_clk_p[1] = gtx_clk_1_0_p;
   //gtx_clk_p[2] = gtx_clk_116_p;
   Vector#(QuadCount,Clock) gtx_clk_n;
   gtx_clk_n[0] = gtx_clk_0_n;
   gtx_clk_n[1] = gtx_clk_1_0_n;
   //gtx_clk_n[2] = gtx_clk_116_n;

   let top <- mkPcieTopFromPortal(pci_sys_clk_p, pci_sys_clk_n, sys_clk_p, sys_clk_n, pci_sys_reset_n, gtx_clk_p, gtx_clk_n,
				  mkSynthesizeablePortalTop);
   return top;
endmodule: mkPcieTop
