package GtxeCommonImport_119;

import Clocks :: *;

interface GtxeCommonIfc;
	interface Clock qpllclk;
	interface Clock qpllrefclk;
endinterface

import "BVI" gt_common_wrapper_119 =
module mkGtxeCommonImport_119#(Clock gtx_clk, Clock init_clk) (GtxeCommonIfc);
	default_clock no_clock;
	default_reset no_reset;

	output_clock qpllclk(gt_qpllclk_quad7_out);
	output_clock qpllrefclk(gt_qpllrefclk_quad7_out);

	input_clock(GT0_GTREFCLK0_COMMON_IN) = gtx_clk;
	input_clock(GT0_QPLLLOCKDETCLK_IN) = init_clk;

endmodule

endpackage: GtxeCommonImport_119
