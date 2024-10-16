// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.





`timescale 1 ps / 1 ps

module fmiohmc_ecc_sv_112 (
   input  wire [7:0] di,  
   output reg  [111:0] dout 
);

always @*
  begin
  case(di)
	8'b11100000 : dout = 112'h0000000000000000000000000001;
	8'b11010000 : dout = 112'h0000000000000000000000000002;
	8'b10110000 : dout = 112'h0000000000000000000000000004;
	8'b01110000 : dout = 112'h0000000000000000000000000008;
	8'b11001000 : dout = 112'h0000000000000000000000000010;
	8'b10101000 : dout = 112'h0000000000000000000000000020;
	8'b01101000 : dout = 112'h0000000000000000000000000040;
	8'b10011000 : dout = 112'h0000000000000000000000000080;
	8'b01011000 : dout = 112'h0000000000000000000000000100;
	8'b00111000 : dout = 112'h0000000000000000000000000200;
	8'b11000100 : dout = 112'h0000000000000000000000000400;
	8'b10100100 : dout = 112'h0000000000000000000000000800;
	8'b01100100 : dout = 112'h0000000000000000000000001000;
	8'b10010100 : dout = 112'h0000000000000000000000002000;
	8'b01010100 : dout = 112'h0000000000000000000000004000;
	8'b00110100 : dout = 112'h0000000000000000000000008000;
	8'b10001100 : dout = 112'h0000000000000000000000010000;
	8'b01001100 : dout = 112'h0000000000000000000000020000;
	8'b00101100 : dout = 112'h0000000000000000000000040000;
	8'b00011100 : dout = 112'h0000000000000000000000080000;
	8'b11000010 : dout = 112'h0000000000000000000000100000;
	8'b10100010 : dout = 112'h0000000000000000000000200000;
	8'b01100010 : dout = 112'h0000000000000000000000400000;
	8'b10010010 : dout = 112'h0000000000000000000000800000;
	8'b01010010 : dout = 112'h0000000000000000000001000000;
	8'b00110010 : dout = 112'h0000000000000000000002000000;
	8'b10001010 : dout = 112'h0000000000000000000004000000;
	8'b01001010 : dout = 112'h0000000000000000000008000000;
	8'b00101010 : dout = 112'h0000000000000000000010000000;
	8'b00011010 : dout = 112'h0000000000000000000020000000;
	8'b10000110 : dout = 112'h0000000000000000000040000000;
	8'b01000110 : dout = 112'h0000000000000000000080000000;
	8'b00100110 : dout = 112'h0000000000000000000100000000;
	8'b00010110 : dout = 112'h0000000000000000000200000000;
	8'b00001110 : dout = 112'h0000000000000000000400000000;
	8'b11000001 : dout = 112'h0000000000000000000800000000;
	8'b10100001 : dout = 112'h0000000000000000001000000000;
	8'b01100001 : dout = 112'h0000000000000000002000000000;
	8'b10010001 : dout = 112'h0000000000000000004000000000;
	8'b01010001 : dout = 112'h0000000000000000008000000000;
	8'b00110001 : dout = 112'h0000000000000000010000000000;
	8'b10001001 : dout = 112'h0000000000000000020000000000;
	8'b01001001 : dout = 112'h0000000000000000040000000000;
	8'b00101001 : dout = 112'h0000000000000000080000000000;
	8'b00011001 : dout = 112'h0000000000000000100000000000;
	8'b10000101 : dout = 112'h0000000000000000200000000000;
	8'b01000101 : dout = 112'h0000000000000000400000000000;
	8'b00100101 : dout = 112'h0000000000000000800000000000;
	8'b00010101 : dout = 112'h0000000000000001000000000000;
	8'b00001101 : dout = 112'h0000000000000002000000000000;
	8'b10000011 : dout = 112'h0000000000000004000000000000;
	8'b01000011 : dout = 112'h0000000000000008000000000000;
	8'b00100011 : dout = 112'h0000000000000010000000000000;
	8'b00010011 : dout = 112'h0000000000000020000000000000;
	8'b00001011 : dout = 112'h0000000000000040000000000000;
	8'b00000111 : dout = 112'h0000000000000080000000000000;
	8'b11111000 : dout = 112'h0000000000000100000000000000;
	8'b11110100 : dout = 112'h0000000000000200000000000000;
	8'b11101100 : dout = 112'h0000000000000400000000000000;
	8'b11011100 : dout = 112'h0000000000000800000000000000;
	8'b10111100 : dout = 112'h0000000000001000000000000000;
	8'b01111100 : dout = 112'h0000000000002000000000000000;
	8'b11110010 : dout = 112'h0000000000004000000000000000;
	8'b11101010 : dout = 112'h0000000000008000000000000000;
	8'b11011010 : dout = 112'h0000000000010000000000000000;
	8'b10111010 : dout = 112'h0000000000020000000000000000;
	8'b01111010 : dout = 112'h0000000000040000000000000000;
	8'b11100110 : dout = 112'h0000000000080000000000000000;
	8'b11010110 : dout = 112'h0000000000100000000000000000;
	8'b10110110 : dout = 112'h0000000000200000000000000000;
	8'b01110110 : dout = 112'h0000000000400000000000000000;
	8'b11001110 : dout = 112'h0000000000800000000000000000;
	8'b10101110 : dout = 112'h0000000001000000000000000000;
	8'b01101110 : dout = 112'h0000000002000000000000000000;
	8'b10011110 : dout = 112'h0000000004000000000000000000;
	8'b01011110 : dout = 112'h0000000008000000000000000000;
	8'b00111110 : dout = 112'h0000000010000000000000000000;
	8'b11110001 : dout = 112'h0000000020000000000000000000;
	8'b11101001 : dout = 112'h0000000040000000000000000000;
	8'b11011001 : dout = 112'h0000000080000000000000000000;
	8'b10111001 : dout = 112'h0000000100000000000000000000;
	8'b01111001 : dout = 112'h0000000200000000000000000000;
	8'b11100101 : dout = 112'h0000000400000000000000000000;
	8'b11010101 : dout = 112'h0000000800000000000000000000;
	8'b10110101 : dout = 112'h0000001000000000000000000000;
	8'b01110101 : dout = 112'h0000002000000000000000000000;
	8'b11001101 : dout = 112'h0000004000000000000000000000;
	8'b10101101 : dout = 112'h0000008000000000000000000000;
	8'b01101101 : dout = 112'h0000010000000000000000000000;
	8'b10011101 : dout = 112'h0000020000000000000000000000;
	8'b01011101 : dout = 112'h0000040000000000000000000000;
	8'b00111101 : dout = 112'h0000080000000000000000000000;
	8'b11100011 : dout = 112'h0000100000000000000000000000;
	8'b11010011 : dout = 112'h0000200000000000000000000000;
	8'b10110011 : dout = 112'h0000400000000000000000000000;
	8'b01110011 : dout = 112'h0000800000000000000000000000;
	8'b11001011 : dout = 112'h0001000000000000000000000000;
	8'b10101011 : dout = 112'h0002000000000000000000000000;
	8'b01101011 : dout = 112'h0004000000000000000000000000;
	8'b10011011 : dout = 112'h0008000000000000000000000000;
	8'b01011011 : dout = 112'h0010000000000000000000000000;
	8'b00111011 : dout = 112'h0020000000000000000000000000;
	8'b11000111 : dout = 112'h0040000000000000000000000000;
	8'b10100111 : dout = 112'h0080000000000000000000000000;
	8'b01100111 : dout = 112'h0100000000000000000000000000;
	8'b10010111 : dout = 112'h0200000000000000000000000000;
	8'b01010111 : dout = 112'h0400000000000000000000000000;
	8'b00110111 : dout = 112'h0800000000000000000000000000;
	8'b10001111 : dout = 112'h1000000000000000000000000000;
	8'b01001111 : dout = 112'h2000000000000000000000000000;
	8'b00101111 : dout = 112'h4000000000000000000000000000;
	8'b00011111 : dout = 112'h800000000000_0000_0000_0000_0000;
	default: dout = 112'd0;
  endcase
  end
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "sfv4CgBD2gRw66FfSic/D/DxyUF4ju6abSGjNZTz+XJ5wNcp1RmzgamT61rscvjMkkNKCYCGE4Hkry++3eL2fSJkmOtrYLQextJ2AFr2kX/6sa63SwNG1Dg8CndZgqHpcPsbI8J/52/6EA/5eQJiUNmwpEDzzugi2WpUBRBy4gGrSJ7A8zUzUrkHlWNSHE1mVOTkuXrL/BUqA6hBwwkS7qZD/J3TRyAu6L9p+9tB0EDL+Kx1GJswSvO1FgFTTjrA44zRAvW3/bEUybBOO+NfkRaG0GKBzL2u+ogyIoumTowmacKTR2HRLYTQe466P2Hgcau1jtQ6MJxXJ2UpsO+xMCjjdlBASlnmIu3qCugpXDlFRqIZ29TfArwtTw0sHh2dKobs9FzuIya12sMn7tOKm6aIPjqK7Qv74khUIaG8QRqnTyTpxAA+Fea26tX7MCNnvqim8dOsuxz4ODAM2TZjueBbkkiKo1r+iBLUwyPkZFvpzkFJloDgZCLexdVenh64OFCIAMVAFIRyHNbqmpFN5BnERRk3TXg0hhUORZV3RjY42/caeCnXa+vqFS8ZZeTePVPTsR1MV9h49lsitF8+A+urw/AF12N1qeum0bnawHm+BOHDA1z6IQCzi+1zLRXWXnWfxR+o1pWo/NPndibqKesfCXCK0Vbe/oarWWVqAoNxmpD1f1vA7KK7/8j4eR0uDngOLFixaCPcZlOaXbnxocYukqaWETf8uyPWq3iYvNqrEJAnA2A3+w9Pw9SFbsdH3Gx91eK1IuS2hVLErW/YhvfjdsfWzgMHMag1DOnvh1UTXslLxlFatlo81sbo0CsyoBWfwQLEVeyYI6m4xLm8T7VQyjZ66hh3WrmYlXHNOeCQk4j43muuPhOZINp7AmkmNxsrGVcjtWbv97aKdoYBV0/RL5LHZ1d7hzflVQo1c8r2S8un9Zay/jaNSQpJkfKOziUKRJh+ZyokBTeQFyx3lRjwETQV4xLU99ROBlHtk8d0agPOmZNbT/pnZ242EiaB"
`endif