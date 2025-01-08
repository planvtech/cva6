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


// Copyright 2021 Intel Corporation. 
//
// This reference design file is subject licensed to you by the terms and 
// conditions of the applicable License Terms and Conditions for Hardware 
// Reference Designs and/or Design Examples (either as signed by you or 
// found at https://www.altera.com/common/legal/leg-license_agreement.html ).  
//
// As stated in the license, you agree to only use this reference design 
// solely in conjunction with Intel FPGAs or Intel CPLDs.  
//
// THE REFERENCE DESIGN IS PROVIDED "AS IS" WITHOUT ANY EXPRESS OR IMPLIED
// WARRANTY OF ANY KIND INCLUDING WARRANTIES OF MERCHANTABILITY, 
// NONINFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. Intel does not 
// warrant or assume responsibility for the accuracy or completeness of any
// information, links or other items within the Reference Design and any 
// accompanying materials.
//
// In the event that you do not agree with such terms and conditions, do not
// use the reference design file.
/////////////////////////////////////////////////////////////////////////////

module add_a_b_s0_s1 #(
    parameter SIZE = 5
)(
    input [SIZE-1:0] a,
    input [SIZE-1:0] b,
    input s0,
    input s1,
    output [SIZE-1:0] out
);
    wire [SIZE:0] left;
    wire [SIZE:0] right;
    wire temp;
    
    assign left = {a ^ b, s0};
    assign right = {a[SIZE-2:0] & b[SIZE-2:0], s1, s0};
    assign {out, temp} = left + right;
    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKL0hH0HzOmYPf9lMUU/MQjBmFl0JBtqWoTY5HMbASH6uzUetkF8u5XfYVBjaohyYhp5QuOwcKjKAMfiPH4ftc81Pu90QCFUlH2Q3dGJjFvAL77TRCiMW07RDIAw10KldHcWRtZZa5EA0YGy92LyfSuVtmmNWJZ4xQ0OHk8uLa6KcXK6/4f1Lg+lrzSw+m1DVqnClU7nS1o0uIsKryp02+DHWkJawxAqc9RPan+FsgvrZvvYrBPS7Bs8J+2ThrwEcTukDMzqJ4mfsHWGWu+3IwSCKy9RSn00QJ9zNHbDWdxOFNogKhtrwgqHkpJtqVayspB0AQfe//4qGMuF4IrcUojOelsYW53RPiuZD1omb8JsbqFKQopZW/+6WxNX6BuM7/+QOyGcE/XODvKszZ/SZS4LtivN0VDSn71LQ7BAaap2wNUWMzO6KRRBLAzeCXSkb/u/1wQ9aLMUp0yxnaqungWdABdUUKwivdeEqbI7VvJW9zcYfuLckzqKoEsyGFR4T5tXzI7NcERLtww2gQySyemAvCTJC+KZdKgUYjvNbXmL52UGbG4mgutmkd0jQZETPhYtPFmqkqjNnh+NZGNIhaz7AztcUqhBvwjoWN0FBvGU1OTzm8SP5KGMc4eZ1ys9AFsWpn+mMoPpqnUQnRUptW+H8Xr/HxyG1om1YDYp13j2e0JGRAbe+XAvUYulBXAAuH1iU0lIAMb4HAUZw1dvx9s1x2d5wW1O7uzm2QHXy4V2/koOlzRK21F7MV3kPCoAAO7rJR1awFcllXe9TTQANLIY"
`endif