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



//
// Intel Agilex FP HPS AXI Soft IP wrappers.
//

`timescale 1 ps / 1 ps
module tennm_fp_soc_mpfe_wrapper #( parameter DATA_WIDTH = 256, parameter STRB_WIDTH = 32, parameter ADDR_WIDTH = 32, parameter WIDTH_ENUM = "MPFE_ACELITE_PORT_WIDTH_DATA_WIDTH_128" )(
    // FPGA2HPS ACELite
    input  wire [           39:0] f2s_araddr,
    input  wire [            1:0] f2s_arbar,
    input  wire [            1:0] f2s_arburst,
    input  wire [            3:0] f2s_arcache,
    input  wire [            1:0] f2s_ardomain,
    input  wire [            4:0] f2s_arid,
    input  wire [            7:0] f2s_arlen,
    input  wire                   f2s_arlock,
    input  wire [            2:0] f2s_arprot,
    input  wire [            3:0] f2s_arqos,
    input  wire [            2:0] f2s_arsize,
    input  wire [            3:0] f2s_arsnoop,
    input  wire [            7:0] f2s_aruser,
    input  wire                   f2s_arvalid,
    input  wire [           39:0] f2s_awaddr,
    input  wire [            1:0] f2s_awbar,
    input  wire [            1:0] f2s_awburst,
    input  wire [            3:0] f2s_awcache,
    input  wire [            1:0] f2s_awdomain,
    input  wire [            4:0] f2s_awid,
    input  wire [            7:0] f2s_awlen,
    input  wire                   f2s_awlock,
    input  wire [            2:0] f2s_awprot,
    input  wire [            3:0] f2s_awqos,
    input  wire [            2:0] f2s_awsize,
    input  wire [            2:0] f2s_awsnoop,
    input  wire [            7:0] f2s_awuser,
    input  wire                   f2s_awvalid,
    input  wire                   f2s_bready,
    input  wire                   f2s_rready,
    input  wire [            9:0] f2s_rsb_sid,
    input  wire [            4:0] f2s_rsb_ssd,
    input  wire [          255:0] f2s_wdata,
    input  wire                   f2s_wlast,
    input  wire [            9:0] f2s_wsb_sid,
    input  wire [            4:0] f2s_wsb_ssd,
    input  wire [           31:0] f2s_wstrb,
    input  wire                   f2s_wvalid,
    input  wire                   f2s_clk,
    input  wire [            1:0] f2s_port_size_config,
    output wire                   f2s_arready,
    output wire                   f2s_awready,
    output wire [            4:0] f2s_bid,
    output wire [            1:0] f2s_bresp,
    output wire                   f2s_bvalid,
    output wire [ DATA_WIDTH-1:0] f2s_rdata,
    output wire [            4:0] f2s_rid,
    output wire                   f2s_rlast,
    output wire [            3:0] f2s_rresp,
    output wire                   f2s_rvalid,
    output wire                   f2s_wready,
    // reset input for Ready Latency only -- actual bridge reset is internal
    input  wire                   f2s_rst,
    
    // ATB
    input  wire          atb_mpfe_afvalid,
    input  wire          atb_mpfe_atready,
    input  wire          atb_mpfe_clkenm,
    input  wire          atb_mpfe_syncreqm,
    input  wire          atclk_atb_mpfe,
    input  wire          atresetn_atb_mpfe,
    output wire          atb_mpfe_afready,
    output wire [   1:0] atb_mpfe_atbytes,
    output wire [  31:0] atb_mpfe_atdata,
    output wire [   6:0] atb_mpfe_atid,
    output wire          atb_mpfe_atvalid,
    
    // NOC clocks
    input  wire          cnoc_clk,
    input  wire          hnoc_clk,
    
    // HNOC-facing Ch0 256-AXI
    input  wire          s2n0_arready,
    input  wire          s2n0_awready,
    input  wire [   6:0] s2n0_bid,
    input  wire [   1:0] s2n0_bresp,
    input  wire          s2n0_bvalid,
    input  wire [ 255:0] s2n0_rdata,
    input  wire [   6:0] s2n0_rid,
    input  wire          s2n0_rlast,
    input  wire [   1:0] s2n0_rresp,
    //input  wire [  31:0] s2n0_ruser,
    input  wire          s2n0_rvalid,
    input  wire          s2n0_wready,
    output wire [  43:0] s2n0_araddr,
    output wire [   1:0] s2n0_arburst,
    output wire [   6:0] s2n0_arid,
    output wire [   7:0] s2n0_arlen,
    output wire          s2n0_arlock,
    output wire [   3:0] s2n0_arqos,
    output wire [   2:0] s2n0_arsize,
    //output wire [  13:0] s2n0_aruser,
    output wire          s2n0_arvalid,
    output wire [  43:0] s2n0_awaddr,
    output wire [   1:0] s2n0_awburst,
    output wire [   6:0] s2n0_awid,
    output wire [   7:0] s2n0_awlen,
    output wire          s2n0_awlock,
    output wire [   3:0] s2n0_awqos,
    output wire [   2:0] s2n0_awsize,
    //output wire [  13:0] s2n0_awuser,
    output wire          s2n0_awvalid,
    output wire          s2n0_bready,
    output wire          s2n0_rready,
    output wire [ 255:0] s2n0_wdata,
    output wire          s2n0_wlast,
    output wire [  31:0] s2n0_wstrb,
    //output wire [  31:0] s2n0_wuser,
    output wire          s2n0_wvalid,
    output wire          s2n0_clk,
    // fake ports -- required for AXI by Qsys
    output wire          s2n0_rst,
    output wire [   2:0] s2n0_arprot,
    output wire [   2:0] s2n0_awprot,

    
    // HNOC-facing Ch1 256-AXI
    input  wire          s2n1_arready,
    input  wire          s2n1_awready,
    input  wire [   6:0] s2n1_bid,
    input  wire [   1:0] s2n1_bresp,
    input  wire          s2n1_bvalid,
    input  wire [ 255:0] s2n1_rdata,
    input  wire [   6:0] s2n1_rid,
    input  wire          s2n1_rlast,
    input  wire [   1:0] s2n1_rresp,
    //input  wire [  31:0] s2n1_ruser,
    input  wire          s2n1_rvalid,
    input  wire          s2n1_wready,
    output wire [  43:0] s2n1_araddr,
    output wire [   1:0] s2n1_arburst,
    output wire [   6:0] s2n1_arid,
    output wire [   7:0] s2n1_arlen,
    output wire          s2n1_arlock,
    output wire [   3:0] s2n1_arqos,
    output wire [   2:0] s2n1_arsize,
    //output wire [  13:0] s2n1_aruser,
    output wire          s2n1_arvalid,
    output wire [  43:0] s2n1_awaddr,
    output wire [   1:0] s2n1_awburst,
    output wire [   6:0] s2n1_awid,
    output wire [   7:0] s2n1_awlen,
    output wire          s2n1_awlock,
    output wire [   3:0] s2n1_awqos,
    output wire [   2:0] s2n1_awsize,
    //output wire [  13:0] s2n1_awuser,
    output wire          s2n1_awvalid,
    output wire          s2n1_bready,
    output wire          s2n1_rready,
    output wire [ 255:0] s2n1_wdata,
    output wire          s2n1_wlast,
    output wire [  31:0] s2n1_wstrb,
    //output wire [  31:0] s2n1_wuser,
    output wire          s2n1_wvalid,
    output wire          s2n1_clk,
    // fake ports -- required for AXI by Qsys
    output wire          s2n1_rst,
    output wire [   2:0] s2n1_arprot,
    output wire [   2:0] s2n1_awprot,
    
    // HNOC-facing MEM 32-AXI channel
    input  wire          s2n_mem_cfg_arready,
    input  wire          s2n_mem_cfg_awready,
    input  wire [   1:0] s2n_mem_cfg_bresp,
    input  wire          s2n_mem_cfg_bvalid,
    input  wire [  31:0] s2n_mem_cfg_rdata,
    input  wire [   1:0] s2n_mem_cfg_rresp,
    input  wire          s2n_mem_cfg_rvalid,
    input  wire          s2n_mem_cfg_wready,
    output wire [  31:0] s2n_mem_cfg_araddr,
    output wire          s2n_mem_cfg_arvalid,
    output wire [  31:0] s2n_mem_cfg_awaddr,
    output wire          s2n_mem_cfg_awvalid,
    output wire          s2n_mem_cfg_bready,
    output wire          s2n_mem_cfg_rready,
    output wire [  31:0] s2n_mem_cfg_wdata,
    output wire [   3:0] s2n_mem_cfg_wstrb,
    output wire          s2n_mem_cfg_wvalid,
    output wire          s2n_mem_cfg_clk,
    // fake ports -- required for AXILite by Qsys
    output wire          s2n_mem_cfg_rst,
    output wire [   2:0] s2n_mem_cfg_arprot,
    output wire [   2:0] s2n_mem_cfg_awprot
);

wire [7:0] f2soc_arlen;
wire [7:0] f2soc_awlen;
if (DATA_WIDTH == 128) begin
    assign f2soc_arlen[7:0] = f2s_arlen[7:0];
    assign f2soc_awlen[7:0] = f2s_awlen[7:0];
end
if (DATA_WIDTH == 256) begin
    assign f2soc_arlen[7] = 1'b0;
    assign f2soc_awlen[7] = 1'b0;
    assign f2soc_arlen[6:0] = f2s_arlen[6:0];
    assign f2soc_awlen[6:0] = f2s_awlen[6:0];
end

wire [   0:0] mpfe_arready;
wire [   0:0] mpfe_arvalid;
wire [   4:0] mpfe_arid;
wire [  39:0] mpfe_araddr;
wire [   7:0] mpfe_arlen;
wire [   2:0] mpfe_arsize;
wire [   1:0] mpfe_arburst;
wire [   0:0] mpfe_arlock;
wire [   7:0] mpfe_aruser;
wire [   3:0] mpfe_arqos;
wire [   1:0] mpfe_arbar;
wire [   3:0] mpfe_arcache;
wire [   1:0] mpfe_ardomain;
wire [   2:0] mpfe_arprot;
wire [   3:0] mpfe_arsnoop;
wire [   0:0] mpfe_awready;
wire [   0:0] mpfe_awvalid;
wire [   4:0] mpfe_awid;
wire [  39:0] mpfe_awaddr;
wire [   7:0] mpfe_awlen;
wire [   2:0] mpfe_awsize;
wire [   1:0] mpfe_awburst;
wire [   0:0] mpfe_awlock;
wire [   7:0] mpfe_awuser;
wire [   3:0] mpfe_awqos;
wire [   1:0] mpfe_awbar;
wire [   3:0] mpfe_awcache;
wire [   1:0] mpfe_awdomain;
wire [   2:0] mpfe_awprot;
wire [   2:0] mpfe_awsnoop;
wire [   0:0] mpfe_wready;
wire [   0:0] mpfe_wvalid;
wire [ 255:0] mpfe_wdata;
wire [   0:0] mpfe_wlast;
wire [  31:0] mpfe_wstrb;
wire [   4:0] mpfe_bid;
wire [   1:0] mpfe_bresp;
wire [   0:0] mpfe_bready;
wire [   0:0] mpfe_bvalid;
wire [   0:0] mpfe_rvalid;
wire [   4:0] mpfe_rid;
wire [ 255:0] mpfe_rdata;
wire [   3:0] mpfe_rresp;
wire [   0:0] mpfe_rlast;
wire [   0:0] mpfe_rready;

// Ready Latency Adapter
hps_ready_latency_ace_adp #(
    .ID_WIDTH    (5),
    .DATA_WIDTH  (DATA_WIDTH),
    .STRB_WIDTH  (STRB_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .AUSER_WIDTH (8)
) hps_f2s_rdyl (
    .clk(f2s_clk),
    // expected to connect to active low h2f_reset output
    .reset(~f2s_rst),
    // RL Input
    .awready(mpfe_awready),
    .awvalid(f2s_awvalid),
    .awid(f2s_awid),
    .awaddr(f2s_awaddr[ADDR_WIDTH-1:0]),
    .awlen(f2soc_awlen),
    .awsize(f2s_awsize),
    .awburst(f2s_awburst),
    .awlock(f2s_awlock),
    .awuser(f2s_awuser),
    .awqos(f2s_awqos),
    .awbar(f2s_awbar),
    .awcache(f2s_awcache),
    .awdomain(f2s_awdomain),
    .awprot(f2s_awprot),
    .awsnoop(f2s_awsnoop),
    .arready(mpfe_arready),
    .arvalid(f2s_arvalid),
    .arid(f2s_arid),
    .araddr(f2s_araddr[ADDR_WIDTH-1:0]),
    .arlen(f2soc_arlen),
    .arsize(f2s_arsize),
    .arburst(f2s_arburst),
    .arlock(f2s_arlock),
    .aruser(f2s_aruser),
    .arqos(f2s_arqos),
    .arbar(f2s_arbar),
    .arcache(f2s_arcache),
    .ardomain(f2s_ardomain),
    .arprot(f2s_arprot),
    .arsnoop(f2s_arsnoop),
    .wready(mpfe_wready),
    .wvalid(f2s_wvalid),
    .wdata(f2s_wdata[DATA_WIDTH-1:0]),
    .wlast(f2s_wlast),
    .wstrb(f2s_wstrb[STRB_WIDTH-1:0]),
    .bvalid(mpfe_bvalid),
    .bid(mpfe_bid),
    .bresp(mpfe_bresp),
    .bready(f2s_bready),
    .rvalid(mpfe_rvalid),
    .rid(mpfe_rid),
    .rdata(mpfe_rdata[DATA_WIDTH-1:0]),
    .rresp(mpfe_rresp),
    .rlast(mpfe_rlast),
    .rready(f2s_rready),
    // RL Output
    .awready_r(f2s_awready),
    .awvalid_r(mpfe_awvalid),
    .awid_r(mpfe_awid),
    .awaddr_r(mpfe_awaddr[ADDR_WIDTH-1:0]),
    .awlen_r(mpfe_awlen),
    .awsize_r(mpfe_awsize),
    .awburst_r(mpfe_awburst),
    .awlock_r(mpfe_awlock),
    .awuser_r(mpfe_awuser),
    .awqos_r(mpfe_awqos),
    .awbar_r(mpfe_awbar),
    .awcache_r(mpfe_awcache),
    .awdomain_r(mpfe_awdomain),
    .awprot_r(mpfe_awprot),
    .awsnoop_r(mpfe_awsnoop),
    .arready_r(f2s_arready),
    .arvalid_r(mpfe_arvalid),
    .arid_r(mpfe_arid),
    .araddr_r(mpfe_araddr[ADDR_WIDTH-1:0]),
    .arlen_r(mpfe_arlen),
    .arsize_r(mpfe_arsize),
    .arburst_r(mpfe_arburst),
    .arlock_r(mpfe_arlock),
    .aruser_r(mpfe_aruser),
    .arqos_r(mpfe_arqos),
    .arbar_r(mpfe_arbar),
    .arcache_r(mpfe_arcache),
    .ardomain_r(mpfe_ardomain),
    .arprot_r(mpfe_arprot),
    .arsnoop_r(mpfe_arsnoop),
    .wready_r(f2s_wready),
    .wvalid_r(mpfe_wvalid),
    .wdata_r(mpfe_wdata[DATA_WIDTH-1:0]),
    .wlast_r(mpfe_wlast),
    .wstrb_r(mpfe_wstrb[STRB_WIDTH-1:0]),
    .bvalid_r(f2s_bvalid),
    .bid_r(f2s_bid),
    .bresp_r(f2s_bresp),
    .bready_r(mpfe_bready),
    .rvalid_r(f2s_rvalid),
    .rid_r(f2s_rid),
    .rdata_r(f2s_rdata[DATA_WIDTH-1:0]),
    .rresp_r(f2s_rresp),
    .rlast_r(f2s_rlast),
    .rready_r(mpfe_rready)
    );

// Tie-off extra Qsys bits
assign s2n0_arlen[7] = 1'b0;
assign s2n0_awlen[7] = 1'b0;
assign s2n0_arqos[3:2] = 2'b0;
assign s2n0_awqos[3:2] = 2'b0;
assign s2n1_arlen[7] = 1'b0;
assign s2n1_awlen[7] = 1'b0;
assign s2n1_arqos[3:2] = 2'b00;
assign s2n1_awqos[3:2] = 2'b00;


// Tie-off fake output ports
assign s2n_mem_cfg_arprot = 3'b000;
assign s2n_mem_cfg_awprot = 3'b000;
assign s2n0_arprot = 3'b000;
assign s2n0_awprot = 3'b000;
assign s2n1_arprot = 3'b000;
assign s2n1_awprot = 3'b000;


(* altera_attribute = "-name PRESERVE_FANOUT_FREE_WYSIWYG ON" *)  tennm_fp_soc_mpfe #(
    .mpfe_enable("MPFE_ENABLE_ENABLE"),
    .mpfe_acelite_port_width(WIDTH_ENUM)
) fp_f2s_module (
    // FPGA2HPS ACELite
    .f2s_0_ARADDR(mpfe_araddr),
    .f2s_0_ARBAR(mpfe_arbar),
    .f2s_0_ARBURST(mpfe_arburst),
    .f2s_0_ARCACHE(mpfe_arcache),
    .f2s_0_ARDOMAIN(mpfe_ardomain),
    .f2s_0_ARID(mpfe_arid),
    .f2s_0_ARLEN(mpfe_arlen),
    .f2s_0_ARLOCK(mpfe_arlock),
    .f2s_0_ARPROT(mpfe_arprot),
    .f2s_0_ARQOS(mpfe_arqos),
    .f2s_0_ARSIZE(mpfe_arsize),
    .f2s_0_ARSNOOP(mpfe_arsnoop),
    .f2s_0_ARUSER(mpfe_aruser),
    .f2s_0_ARVALID(mpfe_arvalid),
    .f2s_0_AWADDR(mpfe_awaddr),
    .f2s_0_AWBAR(mpfe_awbar),
    .f2s_0_AWBURST(mpfe_awburst),
    .f2s_0_AWCACHE(mpfe_awcache),
    .f2s_0_AWDOMAIN(mpfe_awdomain),
    .f2s_0_AWID(mpfe_awid),
    .f2s_0_AWLEN(mpfe_awlen),
    .f2s_0_AWLOCK(mpfe_awlock),
    .f2s_0_AWPROT(mpfe_awprot),
    .f2s_0_AWQOS(mpfe_awqos),
    .f2s_0_AWSIZE(mpfe_awsize),
    .f2s_0_AWSNOOP(mpfe_awsnoop),
    .f2s_0_AWUSER(mpfe_awuser),
    .f2s_0_AWVALID(mpfe_awvalid),
    .f2s_0_BREADY(mpfe_bready),
    .f2s_0_RREADY(mpfe_rready),
    .f2s_0_RSB_SID(f2s_rsb_sid),
    .f2s_0_RSB_SSD(f2s_rsb_ssd),
    .f2s_0_WDATA(mpfe_wdata),
    .f2s_0_WLAST(mpfe_wlast),
    .f2s_0_WSB_SID(f2s_wsb_sid),
    .f2s_0_WSB_SSD(f2s_wsb_ssd),
    .f2s_0_WSTRB(mpfe_wstrb),
    .f2s_0_WVALID(mpfe_wvalid),
    .f2s_0_clk(f2s_clk),
    .f2s_0_port_size_config(f2s_port_size_config),
    .f2s_0_ARREADY(mpfe_arready),
    .f2s_0_AWREADY(mpfe_awready),
    .f2s_0_BID(mpfe_bid),
    .f2s_0_BRESP(mpfe_bresp),
    .f2s_0_BVALID(mpfe_bvalid),
    .f2s_0_RDATA(mpfe_rdata),
    .f2s_0_RID(mpfe_rid),
    .f2s_0_RLAST(mpfe_rlast),
    .f2s_0_RRESP(mpfe_rresp),
    .f2s_0_RVALID(mpfe_rvalid),
    .f2s_0_WREADY(mpfe_wready),
    // ATB
    .atb_mpfe_afvalid(atb_mpfe_afvalid),
    .atb_mpfe_atready(atb_mpfe_atready),
    .atb_mpfe_clkenm(atb_mpfe_clkenm),
    .atb_mpfe_syncreqm(atb_mpfe_syncreqm),
    .atclk_atb_mpfe(atclk_atb_mpfe),
    .atresetn_atb_mpfe(atresetn_atb_mpfe),
    .atb_mpfe_afready(atb_mpfe_afready),
    .atb_mpfe_atbytes(atb_mpfe_atbytes),
    .atb_mpfe_atdata(atb_mpfe_atdata),
    .atb_mpfe_atid(atb_mpfe_atid),
    .atb_mpfe_atvalid(atb_mpfe_atvalid),
    // NOC clocks
    .cnoc_clk(cnoc_clk),
    .hnoc_clk(hnoc_clk),
    // HNOC Ch0
    .s2n_emif_ch0_ARREADY(s2n0_arready),
    .s2n_emif_ch0_AWREADY(s2n0_awready),
    .s2n_emif_ch0_BID(s2n0_bid),
    .s2n_emif_ch0_BRESP(s2n0_bresp),
    .s2n_emif_ch0_BVALID(s2n0_bvalid),
    .s2n_emif_ch0_RDATA(s2n0_rdata),
    .s2n_emif_ch0_RID(s2n0_rid),
    .s2n_emif_ch0_RLAST(s2n0_rlast),
    .s2n_emif_ch0_RRESP(s2n0_rresp),
    //.s2n_emif_ch0_RUSER(s2n0_ruser),
    .s2n_emif_ch0_RVALID(s2n0_rvalid),
    .s2n_emif_ch0_WREADY(s2n0_wready),
    .s2n_emif_ch0_ARADDR(s2n0_araddr),
    .s2n_emif_ch0_ARBURST(s2n0_arburst),
    .s2n_emif_ch0_ARID(s2n0_arid),
    .s2n_emif_ch0_ARLEN(s2n0_arlen[6:0]),
    .s2n_emif_ch0_ARLOCK(s2n0_arlock),
    .s2n_emif_ch0_ARQOS(s2n0_arqos[1:0]),
    .s2n_emif_ch0_ARSIZE(s2n0_arsize),
    //.s2n_emif_ch0_ARUSER(s2n0_aruser),
    .s2n_emif_ch0_ARVALID(s2n0_arvalid),
    .s2n_emif_ch0_AWADDR(s2n0_awaddr),
    .s2n_emif_ch0_AWBURST(s2n0_awburst),
    .s2n_emif_ch0_AWID(s2n0_awid),
    .s2n_emif_ch0_AWLEN(s2n0_awlen[6:0]),
    .s2n_emif_ch0_AWLOCK(s2n0_awlock),
    .s2n_emif_ch0_AWQOS(s2n0_awqos[1:0]),
    .s2n_emif_ch0_AWSIZE(s2n0_awsize),
    //.s2n_emif_ch0_AWUSER(s2n0_awuser),
    .s2n_emif_ch0_AWVALID(s2n0_awvalid),
    .s2n_emif_ch0_BREADY(s2n0_bready),
    .s2n_emif_ch0_RREADY(s2n0_rready),
    .s2n_emif_ch0_WDATA(s2n0_wdata),
    .s2n_emif_ch0_WLAST(s2n0_wlast),
    .s2n_emif_ch0_WSTRB(s2n0_wstrb),
    //.s2n_emif_ch0_WUSER(s2n0_wuser),
    .s2n_emif_ch0_WVALID(s2n0_wvalid),
    .emif_ch0_clk(s2n0_clk),
    // HNOC Ch1
    .s2n_emif_ch1_ARREADY(s2n1_arready),
    .s2n_emif_ch1_AWREADY(s2n1_awready),
    .s2n_emif_ch1_BID(s2n1_bid),
    .s2n_emif_ch1_BRESP(s2n1_bresp),
    .s2n_emif_ch1_BVALID(s2n1_bvalid),
    .s2n_emif_ch1_RDATA(s2n1_rdata),
    .s2n_emif_ch1_RID(s2n1_rid),
    .s2n_emif_ch1_RLAST(s2n1_rlast),
    .s2n_emif_ch1_RRESP(s2n1_rresp),
    //.s2n_emif_ch1_RUSER(s2n1_ruser),
    .s2n_emif_ch1_RVALID(s2n1_rvalid),
    .s2n_emif_ch1_WREADY(s2n1_wready),
    .s2n_emif_ch1_ARADDR(s2n1_araddr),
    .s2n_emif_ch1_ARBURST(s2n1_arburst),
    .s2n_emif_ch1_ARID(s2n1_arid),
    .s2n_emif_ch1_ARLEN(s2n1_arlen[6:0]),
    .s2n_emif_ch1_ARLOCK(s2n1_arlock),
    .s2n_emif_ch1_ARQOS(s2n1_arqos[1:0]),
    .s2n_emif_ch1_ARSIZE(s2n1_arsize),
    //.s2n_emif_ch1_ARUSER(s2n1_aruser),
    .s2n_emif_ch1_ARVALID(s2n1_arvalid),
    .s2n_emif_ch1_AWADDR(s2n1_awaddr),
    .s2n_emif_ch1_AWBURST(s2n1_awburst),
    .s2n_emif_ch1_AWID(s2n1_awid),
    .s2n_emif_ch1_AWLEN(s2n1_awlen[6:0]),
    .s2n_emif_ch1_AWLOCK(s2n1_awlock),
    .s2n_emif_ch1_AWQOS(s2n1_awqos[1:0]),
    .s2n_emif_ch1_AWSIZE(s2n1_awsize),
    //.s2n_emif_ch1_AWUSER(s2n1_awuser),
    .s2n_emif_ch1_AWVALID(s2n1_awvalid),
    .s2n_emif_ch1_BREADY(s2n1_bready),
    .s2n_emif_ch1_RREADY(s2n1_rready),
    .s2n_emif_ch1_WDATA(s2n1_wdata),
    .s2n_emif_ch1_WLAST(s2n1_wlast),
    .s2n_emif_ch1_WSTRB(s2n1_wstrb),
    //.s2n_emif_ch1_WUSER(s2n1_wuser),
    .s2n_emif_ch1_WVALID(s2n1_wvalid),
    .emif_ch1_clk(s2n1_clk),
    // EMIF MEM CFG
    .s2n_mem_cfg_ARREADY(s2n_mem_cfg_arready),
    .s2n_mem_cfg_AWREADY(s2n_mem_cfg_awready),
    .s2n_mem_cfg_BRESP(s2n_mem_cfg_bresp),
    .s2n_mem_cfg_BVALID(s2n_mem_cfg_bvalid),
    .s2n_mem_cfg_RDATA(s2n_mem_cfg_rdata),
    .s2n_mem_cfg_RRESP(s2n_mem_cfg_rresp),
    .s2n_mem_cfg_RVALID(s2n_mem_cfg_rvalid),
    .s2n_mem_cfg_WREADY(s2n_mem_cfg_wready),
    .s2n_mem_cfg_ARADDR(s2n_mem_cfg_araddr),
    .s2n_mem_cfg_ARVALID(s2n_mem_cfg_arvalid),
    .s2n_mem_cfg_AWADDR(s2n_mem_cfg_awaddr),
    .s2n_mem_cfg_AWVALID(s2n_mem_cfg_awvalid),
    .s2n_mem_cfg_BREADY(s2n_mem_cfg_bready),
    .s2n_mem_cfg_RREADY(s2n_mem_cfg_rready),
    .s2n_mem_cfg_WDATA(s2n_mem_cfg_wdata),
    .s2n_mem_cfg_WSTRB(s2n_mem_cfg_wstrb),
    .s2n_mem_cfg_WVALID(s2n_mem_cfg_wvalid),
    .mem_cfg_clk(s2n_mem_cfg_clk));
    
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKIHc5Lgq6nmQuz8PrQIjykks9U8312MIWH0mOTlXH/bL+8X2a3eCHEAcuhtUz6MO24n5tqWpxNQi/KfILJcBdgAgP7YJVZ1tKpm+yK5Aa4KzXTFKRBdLxW8CeHzmBlVOZy3KBII7vTd8AfZlap4oEZLT62JAGhBjcrEba1ppiAjQm5vIw05PlVMUw/uvYjE5rPysHjRu+hYaZ1iTTMmUD8oDeQCCPpvUqjmkuEKQ327laPDOwggxw14RKONpuH+NK7C6sG8E3mVn8KM7xhrHXd8sLEw2q/uNm1xpAvQslKDr4EgF+8pB8N6noaZyUgPyM/qRmMorp6xrekioLI7OUPBg0FonJi+xhLnUlaA3Rsqd+hWdyawqdWT61PjTFOTJJ1+xLfs129M/aDRQQRO5Sq3LvYanPYhpLoFjVw/eZurw8Vf7P/jCwHaYiFrta5PMBAAMjsK4v7ijGTOIe1iF/eHBi9be9W8SKv7l7tt+eoEIJFVffjuuL1mMjBiU8cP/3JMRNjYAOZsRvZp71OkH2T5p7sKOMrWev5RnGUsLA2YWvObN9lIxZGD+tHb2ufC6Lz22zfZ9U4s18Tn5ka/1gpwYImyvbMq2kT6eQd/0XBWUHICleo5cfynNr5kLfFisoIIxTg+uy7G2ORUApVv8AwGg5LD8BjTOOpKoVd3rtBERSxYUFXzjaMe81V07wpScuSIjnSPMFyduZKWORpqDU9BB8ScOyZngvzO9y1pYVtsKBHeN109VGFMGW879PPJBnlQF5xPotpgzunHXpWRB+Ku"
`endif