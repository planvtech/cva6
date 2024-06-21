// io_pll.v

// Generated using ACDS version 24.1 115

`timescale 1 ps / 1 ps
module io_pll (
		input  wire  refclk,   //  refclk.clk
		output wire  locked,   //  locked.export
		input  wire  rst,      //   reset.reset
		output wire  outclk_0, // outclk0.clk
		output wire  outclk_1, // outclk1.clk
		output wire  outclk_2  // outclk2.clk
	);

	io_pll_altera_iopll_1931_il4ft3y iopll_0 (
		.refclk   (refclk),   //   input,  width = 1,  refclk.clk
		.locked   (locked),   //  output,  width = 1,  locked.export
		.rst      (rst),      //   input,  width = 1,   reset.reset
		.outclk_0 (outclk_0), //  output,  width = 1, outclk0.clk
		.outclk_1 (outclk_1), //  output,  width = 1, outclk1.clk
		.outclk_2 (outclk_2)  //  output,  width = 1, outclk2.clk
	);

endmodule
