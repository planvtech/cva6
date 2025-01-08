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


module ff_macro # (
 parameter DATA_WIDTH = 256,
 parameter NUM_FLOPS = 1 // based on number of flops you need in 1 dir 
 ) (
 input logic clk,

 input [DATA_WIDTH -1:0] in_data ,

 output [DATA_WIDTH -1:0] out_data

);


 (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_CORE_PERIPHERY_TRANSFER ON" *)
    reg [DATA_WIDTH-1:0] in_data_reg [NUM_FLOPS:0];    

    assign in_data_reg[0] = in_data;


    genvar i;
    
    generate 
    for (i=0 ; i<NUM_FLOPS ; i=i+1 ) begin
      always @(posedge clk) begin
          in_data_reg[i+1] <= in_data_reg[i];
      end
    end
    endgenerate

    assign out_data = in_data_reg[NUM_FLOPS];



    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKJ0LTNCw8llDChvl1b4Y3JK62R29709VKKUY4BfoU7XPjJpnn9VtdL90gMmW2riYf0Fpou2Hy/USPpkykeRNi4GRgRQPJ/HGkepfBUop5uesXDbQsKDYgdwANAgYMUgrRuM1xKhBul8J2BNvJSmf+fp/wM+GH1wNbfmdXcWVOSvXVoXm7+Q8KtOmN3eoK4/089qTpz7wWLYGwy8s2vdqerd9PR32spn+lN0l7MHPItr+iSSZ0L8afcgnhi/gyxdgdxdu+y3CCAkyj0YMaIS74sy8O0afJkv6TIAdVLg814HJCDrqaZGZUQ4wTjT7zqjeaw8ykA7HAhmCAQU6ePgHvAcJy6bX1BebMQJAAHB0bNL2q6VLTvHs4JzdnvLJw+hdivx3OUoxIQ94nO7Pil9bt7h+n2SmPOJCW7JbsGiiTbehg80yx5yslF4WGtU3MGaz8tfU8xsSmMI4gJX5E8H1RKuVjDI5auZJxmu3aMZokBptRjqjrbUJhLcoKVXDDlZtFyHrH4cQITtkT146tqWOb7V1uUZ893EvfkRIWQmNKNeboW0mIwnEytcq7UxmNgjycOO1u6Y78LjYLw71VNnFFB3bTiegzA/bJ9U80zTNkXShHjpK3V5iCBqeT/VzYJStqHvU0slsT4IR/FPFr02KvJOY4ELTLhF4x1COEtJjr8C7OFGi0f0YK11dFHhpVwQ4+n/sWFo4fdfz47/ImrrNN34Xz6fpD1HKci9PRWU91Z7cx2/jN7OzCKqoqnYa0rgDE58X6JtR80HQ9jRDQ4SR9WY"
`endif