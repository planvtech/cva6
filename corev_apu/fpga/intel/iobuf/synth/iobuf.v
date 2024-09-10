// iobuf.v

// Generated using ACDS version 24.1 115

`timescale 1 ps / 1 ps
module iobuf (
		output wire [0:0] dout,   //   dout.export, Data output to the FPGA core in input or bidirectional mode, DATA_SIZE depends on the register mode: Bypass or simple register - DATA_SIZE = SIZE DDIO - DATA_SIZE = 2 x SIZE
		input  wire [0:0] din,    //    din.export, Data input from the FPGA core in output or bidirectional mode.
		input  wire [0:0] oe,     //     oe.export, OE input from the FPGA core in output mode with Enable output enable port turned on, or bidirectional mode. OE is active high. When transmitting data, set this signal to 1. When receiving data, set this signal to 0.
		inout  wire [0:0] pad_io  // pad_io.export, Bidirectional signal connection with the pad.
	);

	iobuf_altera_gpio_2210_ck55vhi gpio_0 (
		.dout   (dout),   //  output,  width = 1,   dout.export
		.din    (din),    //   input,  width = 1,    din.export
		.oe     (oe),     //   input,  width = 1,     oe.export
		.pad_io (pad_io)  //   inout,  width = 1, pad_io.export
	);

endmodule