`ifdef BSIM
import DDR3Sim::*;
`endif
import XilinxVC707DDR3::*;
import Xilinx       :: *;
import XilinxCells ::*;
import Clocks :: *;
import DefaultValue    :: *;

typedef Bit#(29) DDR3Address;
typedef Bit#(64) ByteEn;
typedef Bit#(512) DDR3Data;

interface DRAM_User;
	interface Clock clock;
	interface Reset reset_n;
	method Bool init_done;
	method Action request(DDR3Address addr, ByteEn writeen, DDR3Data datain);
	method ActionValue#(DDR3Data) read_data;
endinterface
interface DRAM_Import;
	interface DRAM_User user;
`ifndef BSIM
	interface DDR3_Pins_VC707 ddr3;
`endif
endinterface

(* synthesize *)
module mkDRAMImport#(Clock clk200, Reset rst200) (DRAM_Import);
`ifndef BSIM
	DDR3_Configure ddr3_cfg = defaultValue;
	ddr3_cfg.reads_in_flight = 2;   // adjust as needed
	//ddr3_cfg.reads_in_flight = 24;   // adjust as needed
	//ddr3_cfg.fast_train_sim_only = False; // adjust if simulating
	DDR3_Controller_VC707 ddr3_ctrl <- mkDDR3Controller_VC707(ddr3_cfg, clk200, clocked_by clk200, reset_by rst200);

	// ddr3_ctrl.user needs to connect to user logic and should use ddr3clk and ddr3rstn
	DDR3_User_VC707 ddr3_ctrl_user = ddr3_ctrl.user;
`else
   let ddr3_ctrl_user <- mkDDR3Simulator;
`endif

interface DRAM_User user;
	interface Clock clock = ddr3_ctrl_user.clock;
	interface Reset reset_n = ddr3_ctrl_user.reset_n;
	method init_done = ddr3_ctrl_user.init_done;
	method request = ddr3_ctrl_user.request;
	method read_data = ddr3_ctrl_user.read_data;
endinterface
`ifndef BSIM
interface DDR3_Pins_VC707 ddr3 = ddr3_ctrl.ddr3;
`endif
endmodule
