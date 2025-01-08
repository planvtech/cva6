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


`timescale 1ns / 100ps

// this module has zero ready latency input and non zero latency output


module ready_latency_adapter # (
 parameter READY_LATENCY_OUT = 2,
 parameter PAYLOAD_WIDTH = 256,
 parameter LOG_DEPTH = 3


) (  
 output logic         in_ready,
 input  logic            in_valid,
 input  logic   [PAYLOAD_WIDTH-1: 0]  in_data,
 // Interface: out
 input  logic             out_ready,
 output logic          out_valid,
 output logic [PAYLOAD_WIDTH-1: 0] out_data,
  // Interface: clk
 input logic          clk,
 // Interface: reset
 input logic           reset

 /*AUTOARG*/);

   // ---------------------------------------------------------------------
   //| Signal Declarations
   // ---------------------------------------------------------------------
   
   logic [PAYLOAD_WIDTH-1:0]   in_payload;
   logic [PAYLOAD_WIDTH-1:0]   out_payload;
   logic            in_ready_wire;
   logic            out_valid_wire;
   logic [2:0]      fifo_fill;
   logic    rdreq;
   logic empty;   

   logic [READY_LATENCY_OUT-1:0] in_ready_dly_reg;
   logic in_ready_dly;
   assign in_ready_dly = (READY_LATENCY_OUT > 0) ? in_ready_dly_reg[0] : in_ready;
 
   localparam DEPTH = 2 ** LOG_DEPTH -1 ;

   // ---------------------------------------------------------------------
   //| Payload Mapping
   // ---------------------------------------------------------------------
   always @* begin
     in_payload = {in_data};
     {out_data} = out_payload;
   end

   // ---------------------------------------------------------------------
   //| FIFO
   // ---------------------------------------------------------------------                           
    scfifo_s # (
      .LOG_DEPTH (LOG_DEPTH),
      .WIDTH (PAYLOAD_WIDTH),
      .ALMOST_FULL_VALUE (DEPTH-1),
      .SHOW_AHEAD (1),
      .FAMILY ("Agilex")
    ) fifo_inst ( 
       .clock        (clk),
       .aclr       (reset),
       .sclr (1'b0),
       //.in_ready   (),
       .wrreq  (in_valid && in_ready_dly),      
       .data    (in_payload),
      //.out_ready  (out_ready),
       .rdreq      (rdreq),
       .q (out_payload),
       .usedw (fifo_fill),
       .empty (empty),
       .full (full),
       .almost_empty (),
       .almost_full ()
       );

   // ---------------------------------------------------------------------
   //| Ready & valid signals.
   // ---------------------------------------------------------------------
   always @* begin
      in_ready = ( DEPTH- fifo_fill > READY_LATENCY_OUT);
   end

    always @(posedge clk) begin
        in_ready_dly_reg[READY_LATENCY_OUT-1] <= in_ready;
        for (int i = 0; i < READY_LATENCY_OUT - 1; i++) begin
            in_ready_dly_reg[i] <= in_ready_dly_reg[i+1];
        end
    end

assign rdreq = out_ready && !empty;

assign out_valid = !empty;


endmodule


`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKJEjpRsvQgmdyoxEg32wjssVEhx50KiUoQsuYfhHKSner/dX4Opi+leUcCrz/CCMEl4sFWksWCRSP8BY2InGdSITeQP/EPVhEYrqxSKywhirm2DYrPnFqc4QQjoYhKSSDakNG5mNLgKttK0Ch1w/Rjo0MYkM0AqnAWTD3QeEo4aFJxZRUB2dP/TSFBlW3XQ+Td0DX5Xai767jDcYT5gnexT33CpyNSfiHbGx38aPPEErSlfjG0B5vv+oWNG0sBom679OiPcKnbR1tmNH2TDgCnY5afJx5Qb2rrmLv6Eqb0RtWEnub6SF7jz7dW8nB7f+b0S4VREmG6vtiZLlgoNawfkSIlDk/1qSiBQJ1a6j8gb1s/Ql5lSFrOaTDMEIAV2WYZNDx5VvLRsE4ze/51r38knEGLANIDmF+8m1+vY4sITGzfdczMJmBj6Ybl8iG69EB8xMn8cTjQdYHXsBf6JRIZbCNTIscyTsBWf27edgHkVsJP3viXZfXycZd8Wn2G0WJp6MWDURbH0/+oH2pV6YTuPa5XaKQ02jsRnylP9txR1eOOssuF7+YnaZ+QjLTbOBQT7pPD59dZMV2vWEJv7yK8zYA+oRm4fv0VYrQC9K9sLolM4spyaNgb0z2/7q0qgxaZwQAd6VKwn5U4ftM1qkrtRe3R2wPhO/hXSFYRGFdbf+s9EiHOIS1+W+nZO/ds0rXXvGmvlJzbU7o/CeOHE2u7/88sv7YGCpfEj3WWEmJCADJ+e53LQsrZJJ+Nosa8OqEDfnuWzmm7YQoyLrszdd49u"
`endif