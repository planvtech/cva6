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


module hps_ready_latency_ace_adp # (

parameter LOG_DEPTH =3 ,
parameter NUM_PIPELINES =2,
parameter ID_WIDTH = 9,
parameter ADDR_WIDTH =44,
parameter DATA_WIDTH = 256,
parameter STRB_WIDTH = 32,
parameter AUSER_WIDTH = 8

 ) (

input logic clk,
input logic reset,

// aw channel

 input  logic awready,
 output logic awvalid_r,
 output logic [ID_WIDTH-1:0] awid_r,
 output logic [ADDR_WIDTH-1:0] awaddr_r,
 output logic [7:0] awlen_r,
 output logic [2:0] awsize_r,
 output logic [1:0] awburst_r,
 output logic awlock_r,
 output logic [AUSER_WIDTH-1:0] awuser_r,
 output logic [3:0] awqos_r,
 output logic [1:0] awbar_r,
 output logic [3:0] awcache_r,
 output logic [1:0] awdomain_r,
 output logic [2:0] awprot_r,
 output logic [2:0] awsnoop_r,



 output logic  awready_r,
 input logic awvalid,
 input logic [ID_WIDTH-1:0] awid,
 input logic [ADDR_WIDTH-1:0] awaddr,
 input logic [7:0] awlen,
 input logic [2:0] awsize,
 input logic [1:0] awburst,
 input logic awlock,
 input logic [AUSER_WIDTH-1:0] awuser,
 input logic [3:0] awqos,
 input logic [1:0] awbar,
 input logic [3:0] awcache,
 input logic [1:0] awdomain,
 input logic [2:0] awprot,
 input logic [2:0] awsnoop,


 // ar channel

 input  logic arready,
 output logic arvalid_r,
 output logic [ID_WIDTH-1:0] arid_r,
 output logic [ADDR_WIDTH-1:0] araddr_r,
 output logic [7:0] arlen_r,
 output logic [2:0] arsize_r,
 output logic [1:0] arburst_r,
 output logic arlock_r,
 output logic [AUSER_WIDTH-1:0] aruser_r,
 output logic [3:0] arqos_r,
 output logic [1:0] arbar_r,
 output logic [3:0] arcache_r,
 output logic [1:0] ardomain_r,
 output logic [2:0] arprot_r,
 output logic [3:0] arsnoop_r,



 output logic arready_r,
 input logic arvalid,
 input logic [ID_WIDTH-1:0] arid,
 input logic [ADDR_WIDTH-1:0] araddr,
 input logic [7:0] arlen,
 input logic [2:0] arsize,
 input logic [1:0] arburst,
 input logic arlock,
 input logic [AUSER_WIDTH-1:0] aruser,
 input logic [3:0] arqos,
 input logic [1:0] arbar,
 input logic [3:0] arcache,
 input logic [1:0] ardomain,
 input logic [2:0] arprot,
 input logic [3:0] arsnoop,

 //w channel

 input logic wready,
 
 output logic wvalid_r,
 output logic [DATA_WIDTH-1:0] wdata_r,
 output logic wlast_r,
 output logic [STRB_WIDTH-1:0] wstrb_r,


 output logic wready_r,
 
 input logic wvalid,
 input logic [DATA_WIDTH-1:0] wdata,
 input logic wlast,
 input logic [STRB_WIDTH-1:0] wstrb,




 // response channel

  input logic bvalid ,
  input logic [ID_WIDTH-1:0] bid,
  input logic [1:0] bresp,

  output logic  bready_r,

  output logic  bvalid_r ,
  output logic  [ID_WIDTH-1:0] bid_r,
  output logic  [1:0] bresp_r,

  input logic bready ,


  input logic rvalid,
  input logic [ID_WIDTH-1:0] rid,
  input logic [DATA_WIDTH-1:0] rdata,
  input logic [3:0] rresp,
  input logic rlast,

  output logic rready_r,


  output logic rvalid_r,
  output logic [ID_WIDTH-1:0] rid_r,
  output logic [DATA_WIDTH-1:0] rdata_r,
  output logic [3:0] rresp_r,
  output logic rlast_r,

  input logic rready





 );

 // awready,awvalid,awlen(8),awsize(3),awburst(2),awlock,awqos(4)
 localparam FIXED_WIDTH_AW =20;
 // awbar(2),awcache(4),awdomain(2),awprot(3),awsnoop(3)
 localparam ACE_WIDTH_AW =14;
 localparam DATA_WIDTH_AW = ID_WIDTH + ADDR_WIDTH + AUSER_WIDTH + ACE_WIDTH_AW + FIXED_WIDTH_AW;
 // arready,arvalid,arlen(8),arsize(3),arburst(2),arlock,arqos(4)
 localparam FIXED_WIDTH_AR =20;
 // arbar(2),arcache(4),ardomain(2),arprot(3),arsnoop(4)
 localparam ACE_WIDTH_AR =15;
 localparam DATA_WIDTH_AR = ID_WIDTH + ADDR_WIDTH + AUSER_WIDTH + ACE_WIDTH_AR + FIXED_WIDTH_AR;
 // 2: bresp(2) -- this does not include bready & bvalid
 localparam DATA_WIDTH_B = ID_WIDTH + 2;
 // 3: wlast,wready,wvalid
 localparam DATA_WIDTH_W = DATA_WIDTH + STRB_WIDTH + 3;
 // 5: rlast,rresp(4) -- does not include rready & rvalid
 localparam DATA_WIDTH_R = DATA_WIDTH + ID_WIDTH + 5;

 localparam FLOP_DEPTH = NUM_PIPELINES/2; // half flops on cmd, rest on rsp path

  logic bvalid_b, rvalid_b;
  logic [DATA_WIDTH_AW-1:0] indata_aw, outdata_aw;
  logic [DATA_WIDTH_AR-1:0] indata_ar, outdata_ar;
  logic [DATA_WIDTH_B -1 :0] indata_b,tempdata_b, bdata_f;

  logic [DATA_WIDTH_R -1 :0] indata_r,tempdata_r, rdata_f;


  logic [DATA_WIDTH_W -1 :0] indata_w, outdata_w;


  generate if ( NUM_PIPELINES == 0 ) begin : no_pipeline

    assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awuser_r,awqos_r,awbar_r,awcache_r,awdomain_r,awprot_r,awsnoop_r} ={awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awuser,awqos,awbar,awcache,awdomain,awprot,awsnoop}; 

    assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,aruser_r,arqos_r,arbar_r,arcache_r,ardomain_r,arprot_r,arsnoop_r} ={arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,aruser,arqos,arbar,arcache,ardomain,arprot,arsnoop};

    assign {wready_r,wvalid_r,wdata_r,wstrb_r,wlast_r} = {wready,wvalid,wdata,wstrb,wlast};

    assign {bready_r,bvalid_r,bid_r,bresp_r} = {bready,bvalid,bid,bresp};
    
    assign {rready_r,rvalid_r,rid_r,rresp_r,rdata_r,rlast_r} = {rready,rvalid,rid,rresp,rdata,rlast}; 

  end
  else begin


 // aw channel 

  assign indata_aw = {awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awuser,awqos,awbar,awcache,awdomain,awprot,awsnoop};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AW)

  ) aw_inst (

  .clk (clk),
  .in_data (indata_aw),
  .out_data ( outdata_aw)

  );

  assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awuser_r,awqos_r,awbar_r,awcache_r,awdomain_r,awprot_r,awsnoop_r} = outdata_aw;


 // ar channel 

 assign indata_ar = {arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,aruser,arqos,arbar,arcache,ardomain,arprot,arsnoop};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AR)

  ) ar_inst (

  .clk (clk),
  .in_data (indata_ar),
  .out_data ( outdata_ar)

  );

  assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,aruser_r,arqos_r,arbar_r,arcache_r,ardomain_r,arprot_r,arsnoop_r} = outdata_ar;
 

 // w channel 

 assign indata_w = {wready,wvalid,wdata,wlast,wstrb};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_W)

  ) w_inst (

  .clk (clk),
  .in_data (indata_w),
  .out_data ( outdata_w)

  );

  assign {wready_r,wvalid_r,wdata_r,wlast_r,wstrb_r} = outdata_w;
 


  // write response channel

  assign indata_b = {bid,bresp};

  // data 
  
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_B)

  ) b_inst_data (

  .clk (clk),
  .in_data (indata_b),
  .out_data (tempdata_b)

  );

   
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (2)

  ) b_inst_ctl (

  .clk (clk),
  .in_data ({bready_f,bvalid}),
  .out_data ({bready_r,bvalid_b})

  );


  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_B),
     .LOG_DEPTH (LOG_DEPTH) 
    ) bresp_inst (
     .clk (clk),
     .reset (reset),
     .in_ready (bready_f), // noc ready output 
     .in_valid (bvalid_b),
     .in_data (tempdata_b),

     .out_ready (bready), // axi ready 0 latency
     .out_valid (bvalid_f),
     .out_data (bdata_f)
 
    );


 assign bvalid_r = bvalid_f;
 assign {bid_r,bresp_r} = bdata_f;



 // read response channel

  assign indata_r = {rid,rresp,rdata,rlast};

  // data 
  
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_R)

  ) r_inst_data (

  .clk (clk),
  .in_data (indata_r),
  .out_data (tempdata_r)

  );

   
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (2)

  ) r_inst_ctl (

  .clk (clk),
  .in_data ({rready_f,rvalid}),
  .out_data ({rready_r,rvalid_b})

  );


  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_R),
     .LOG_DEPTH (LOG_DEPTH) 
    ) rresp_inst (
     .clk (clk),
     .reset (reset),
     .in_ready (rready_f), // noc ready output 
     .in_valid (rvalid_b),
     .in_data (tempdata_r),

     .out_ready (rready), // axi ready 0 latency
     .out_valid (rvalid_f),
     .out_data (rdata_f)
 
    );


 assign rvalid_r = rvalid_f;
 assign {rid_r,rresp_r,rdata_r,rlast_r} = rdata_f;

 end
 endgenerate



  



endmodule 




module hps_ready_latency_axi4_adp # (

parameter LOG_DEPTH =3 ,
parameter NUM_PIPELINES =2,
parameter ID_WIDTH = 9,
parameter ADDR_WIDTH =44,
parameter DATA_WIDTH = 256,
parameter STRB_WIDTH = 32,
parameter AUSER_WIDTH = 8

 ) (

input logic clk,
input logic reset,

// aw channel

 input  logic awready,
 output logic awvalid_r,
 output logic [ID_WIDTH-1:0] awid_r,
 output logic [ADDR_WIDTH-1:0] awaddr_r,
 output logic [7:0] awlen_r,
 output logic [2:0] awsize_r,
 output logic [1:0] awburst_r,
 output logic awlock_r,
 output logic [AUSER_WIDTH-1:0] awuser_r,
 output logic [3:0] awqos_r,
// output logic [1:0] awbar_r,
 output logic [3:0] awcache_r,
// output logic [1:0] awdomain_r,
 output logic [2:0] awprot_r,
// output logic [2:0] awsnoop_r,



 output logic  awready_r,
 input logic awvalid,
 input logic [ID_WIDTH-1:0] awid,
 input logic [ADDR_WIDTH-1:0] awaddr,
 input logic [7:0] awlen,
 input logic [2:0] awsize,
 input logic [1:0] awburst,
 input logic awlock,
 input logic [AUSER_WIDTH-1:0] awuser,
 input logic [3:0] awqos,
// input logic [1:0] awbar,
 input logic [3:0] awcache,
// input logic [1:0] awdomain,
 input logic [2:0] awprot,
// input logic [2:0] awsnoop,


 // ar channel

 input  logic arready,
 output logic arvalid_r,
 output logic [ID_WIDTH-1:0] arid_r,
 output logic [ADDR_WIDTH-1:0] araddr_r,
 output logic [7:0] arlen_r,
 output logic [2:0] arsize_r,
 output logic [1:0] arburst_r,
 output logic arlock_r,
 output logic [AUSER_WIDTH-1:0] aruser_r,
 output logic [3:0] arqos_r,
// output logic [1:0] arbar_r,
 output logic [3:0] arcache_r,
// output logic [1:0] ardomain_r,
 output logic [2:0] arprot_r,
// output logic [3:0] arsnoop_r,



 output logic arready_r,
 input logic arvalid,
 input logic [ID_WIDTH-1:0] arid,
 input logic [ADDR_WIDTH-1:0] araddr,
 input logic [7:0] arlen,
 input logic [2:0] arsize,
 input logic [1:0] arburst,
 input logic arlock,
 input logic [AUSER_WIDTH-1:0] aruser,
 input logic [3:0] arqos,
// input logic [1:0] arbar,
 input logic [3:0] arcache,
// input logic [1:0] ardomain,
 input logic [2:0] arprot,
// input logic [3:0] arsnoop,

 //w channel

 input logic wready,
 
 output logic wvalid_r,
 output logic [DATA_WIDTH-1:0] wdata_r,
 output logic wlast_r,
 output logic [STRB_WIDTH-1:0] wstrb_r,


 output logic wready_r,
 
 input logic wvalid,
 input logic [DATA_WIDTH-1:0] wdata,
 input logic wlast,
 input logic [STRB_WIDTH-1:0] wstrb,




 // response channel

  input logic bvalid ,
  input logic [ID_WIDTH-1:0] bid,
  input logic [1:0] bresp,

  output logic  bready_r,

  output logic  bvalid_r ,
  output logic  [ID_WIDTH-1:0] bid_r,
  output logic  [1:0] bresp_r,

  input logic bready ,


  input logic rvalid,
  input logic [ID_WIDTH-1:0] rid,
  input logic [DATA_WIDTH-1:0] rdata,
  input logic [3:0] rresp,
  input logic rlast,

  output logic rready_r,


  output logic rvalid_r,
  output logic [ID_WIDTH-1:0] rid_r,
  output logic [DATA_WIDTH-1:0] rdata_r,
  output logic [3:0] rresp_r,
  output logic rlast_r,

  input logic rready





 );

 // awready,awvalid,awlen(8),awsize(3),awburst(2),awlock,awqos(4)
 localparam FIXED_WIDTH_AW =20;
 // awcache(4),awprot(3)
 localparam ACE_WIDTH_AW =7;
 localparam DATA_WIDTH_AW = ID_WIDTH + ADDR_WIDTH + AUSER_WIDTH + ACE_WIDTH_AW + FIXED_WIDTH_AW;
 // arready,arvalid,arlen(8),arsize(3),arburst(2),arlock,arqos(4)
 localparam FIXED_WIDTH_AR =20;
 // arcache(4),arprot(3)
 localparam ACE_WIDTH_AR =7;
 localparam DATA_WIDTH_AR = ID_WIDTH + ADDR_WIDTH + AUSER_WIDTH + ACE_WIDTH_AR + FIXED_WIDTH_AR;
 // 2: bresp(2) -- this does not include bready & bvalid
 localparam DATA_WIDTH_B = ID_WIDTH + 2;
 // 3: wlast,wready,wvalid
 localparam DATA_WIDTH_W = DATA_WIDTH + STRB_WIDTH + 3;
 // 5: rlast,rresp(4) -- does not include rready & rvalid
 localparam DATA_WIDTH_R = DATA_WIDTH + ID_WIDTH + 5;

 localparam FLOP_DEPTH = NUM_PIPELINES/2; // half flops on cmd, rest on rsp path

  logic bvalid_b, rvalid_b;
  logic [DATA_WIDTH_AW-1:0] indata_aw, outdata_aw;
  logic [DATA_WIDTH_AR-1:0] indata_ar, outdata_ar;
  logic [DATA_WIDTH_B -1 :0] indata_b,tempdata_b, bdata_f;

  logic [DATA_WIDTH_R -1 :0] indata_r,tempdata_r, rdata_f;


  logic [DATA_WIDTH_W -1 :0] indata_w, outdata_w;


  generate if ( NUM_PIPELINES == 0 ) begin : no_pipeline

    assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awuser_r,awqos_r,awcache_r,awprot_r} ={awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awuser,awqos,awcache,awprot}; 

    assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,aruser_r,arqos_r,arcache_r,arprot_r} ={arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,aruser,arqos,arcache,arprot};

    assign {wready_r,wvalid_r,wdata_r,wstrb_r,wlast_r} = {wready,wvalid,wdata,wstrb,wlast};

    assign {bready_r,bvalid_r,bid_r,bresp_r} = {bready,bvalid,bid,bresp};
    
    assign {rready_r,rvalid_r,rid_r,rresp_r,rdata_r,rlast_r} = {rready,rvalid,rid,rresp,rdata,rlast}; 

  end
  else begin


 // aw channel 

  assign indata_aw = {awready,awvalid,awid,awaddr,awlen,awsize,awburst,awlock,awuser,awqos,awcache,awprot};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AW)

  ) aw_inst (

  .clk (clk),
  .in_data (indata_aw),
  .out_data ( outdata_aw)

  );

  assign {awready_r,awvalid_r,awid_r,awaddr_r,awlen_r,awsize_r,awburst_r,awlock_r,awuser_r,awqos_r,awcache_r,awprot_r} = outdata_aw;


 // ar channel 

 assign indata_ar = {arready,arvalid,arid,araddr,arlen,arsize,arburst,arlock,aruser,arqos,arcache,arprot};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_AR)

  ) ar_inst (

  .clk (clk),
  .in_data (indata_ar),
  .out_data ( outdata_ar)

  );

  assign {arready_r,arvalid_r,arid_r,araddr_r,arlen_r,arsize_r,arburst_r,arlock_r,aruser_r,arqos_r,arcache_r,arprot_r} = outdata_ar;
 

 // w channel 

 assign indata_w = {wready,wvalid,wdata,wlast,wstrb};
 

  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_W)

  ) w_inst (

  .clk (clk),
  .in_data (indata_w),
  .out_data ( outdata_w)

  );

  assign {wready_r,wvalid_r,wdata_r,wlast_r,wstrb_r} = outdata_w;
 


  // write response channel

  assign indata_b = {bid,bresp};

  // data 
  
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_B)

  ) b_inst_data (

  .clk (clk),
  .in_data (indata_b),
  .out_data (tempdata_b)

  );

   
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (2)

  ) b_inst_ctl (

  .clk (clk),
  .in_data ({bready_f,bvalid}),
  .out_data ({bready_r,bvalid_b})

  );


  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_B),
     .LOG_DEPTH (LOG_DEPTH) 
    ) bresp_inst (
     .clk (clk),
     .reset (reset),
     .in_ready (bready_f), // noc ready output 
     .in_valid (bvalid_b),
     .in_data (tempdata_b),

     .out_ready (bready), // axi ready 0 latency
     .out_valid (bvalid_f),
     .out_data (bdata_f)
 
    );


 assign bvalid_r = bvalid_f;
 assign {bid_r,bresp_r} = bdata_f;



 // read response channel

  assign indata_r = {rid,rresp,rdata,rlast};

  // data 
  
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (DATA_WIDTH_R)

  ) r_inst_data (

  .clk (clk),
  .in_data (indata_r),
  .out_data (tempdata_r)

  );

   
  ff_macro # (
  .NUM_FLOPS (FLOP_DEPTH),

  .DATA_WIDTH (2)

  ) r_inst_ctl (

  .clk (clk),
  .in_data ({rready_f,rvalid}),
  .out_data ({rready_r,rvalid_b})

  );


  ready_latency_adapter # (
     .READY_LATENCY_OUT (NUM_PIPELINES),
     .PAYLOAD_WIDTH (DATA_WIDTH_R),
     .LOG_DEPTH (LOG_DEPTH) 
    ) rresp_inst (
     .clk (clk),
     .reset (reset),
     .in_ready (rready_f), // noc ready output 
     .in_valid (rvalid_b),
     .in_data (tempdata_r),

     .out_ready (rready), // axi ready 0 latency
     .out_valid (rvalid_f),
     .out_data (rdata_f)
 
    );


 assign rvalid_r = rvalid_f;
 assign {rid_r,rresp_r,rdata_r,rlast_r} = rdata_f;

 end
 endgenerate



  



endmodule 

















`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKKeHcVxlZq49VW4ezSSAqZPkPPc0eDyvFvwlcXATGC1xrsLZWq6vhXASztqOjmQJp4vmfRI62dVDoeUNsgrBFvLRX+kHdb68K+D/fwGXb4AvFVadz98BRH0KifR+82s+Mo6t7ZaYwmq2ihwNOjSMWDmrHfiFyrTnAG162sI0gEQn3bv6vGio9nZFStsfMgNblu6hyBQGQUQM6MsbxzKMpp9O3FJEo5cGNgCdjwmMG8Cf8Bn1cxV99+7zbUuW+FJPA8FQ9d6Zeg2q3a7D7T41PYW+Gea4xsOMVwlwseUzmYmYnSyZL3cAg00i/ynx0MH8PViJ74c4SLT3bA89RJm/pgCBNkbJaVooDujPc3ZnwXnnRLpVsS28pULkK2kvMxVin6l8bTIM1sB32UZql7orw0ki61nxce+dGOCchhFJAf1HxYPYkIa6vnAmGuV+UL+bfAtgXkPXxFolxGbvjbSHFuCtS248YCP1PNGabZS/IBFVXhsAMF9CRkhNIgJP/IUGw07/9ZAC8L8Ea4HLH4DIl+EwDOvxeXsoJ7BYXU7yNu/SrxwXsfvc33Lm3sItq8ntVZNqmnBGUNM+lpJA20vGRPHnU8jeKutfbmiBdWLZ8Dfi1ICrl57M5Q2V4pis60zT4dXuE9R21S95Nt+2gCAMY+dk96Hp7A3YlKV32pRKiolsjrqU2rvECr/jJ9evCUEsYUfM5WqA69sY88aTQZ0ZevrO6TZNVdCjR6ag/8RhG6OFgnKGY57LqVQKMxbZ8HWaFtoEdMdqavcLLi6j7rR/hAm"
`endif