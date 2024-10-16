// oddr_intel.v

// Generated using ACDS version 24.1 115

`timescale 1 ps / 1 ps
module oddr_intel (
		input  wire       ck,      //      ck.export, In input and output paths, this clock feeds a packed register or DDIO. In bidirectional mode, this clock is the unique clock for the input and output paths if you turn off the Separate input/output Clocks parameter.
		input  wire [1:0] din,     //     din.export, Data input from the FPGA core in output or bidirectional mode.
		output wire [0:0] pad_out  // pad_out.export, Output signal to the pad.Output signal to the pad.
	);

	oddr_intel_altera_gpio_2210_djxpcyq gpio_0 (
		.ck      (ck),      //   input,  width = 1,      ck.export
		.din     (din),     //   input,  width = 2,     din.export
		.pad_out (pad_out)  //  output,  width = 1, pad_out.export
	);

endmodule