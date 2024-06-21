module pll_90_phase (
		input  wire  refclk,     //     refclk.clk
		output wire  locked,     //     locked.export
		input  wire  rst,        //      reset.reset
		input  wire  permit_cal, // permit_cal.export
		output wire  outclk_0    //    outclk0.clk
	);
endmodule

