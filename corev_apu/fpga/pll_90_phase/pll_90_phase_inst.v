	pll_90_phase u0 (
		.refclk     (_connected_to_refclk_),     //   input,  width = 1,     refclk.clk
		.locked     (_connected_to_locked_),     //  output,  width = 1,     locked.export
		.rst        (_connected_to_rst_),        //   input,  width = 1,      reset.reset
		.permit_cal (_connected_to_permit_cal_), //   input,  width = 1, permit_cal.export
		.outclk_0   (_connected_to_outclk_0_)    //  output,  width = 1,    outclk0.clk
	);

