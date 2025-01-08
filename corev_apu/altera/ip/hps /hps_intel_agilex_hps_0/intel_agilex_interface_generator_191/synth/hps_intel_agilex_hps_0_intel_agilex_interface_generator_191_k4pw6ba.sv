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


module hps_intel_agilex_hps_0_intel_agilex_interface_generator_191_k4pw6ba #(
	parameter F2S_DATA_WIDTH = 0 ,
	parameter F2S_ADDRESS_WIDTH = 32 ,
	parameter S2F_DATA_WIDTH = 64 ,
	parameter S2F_ADDRESS_WIDTH = 32 ,
	parameter LWH2S_DATA_WIDTH = 0 ,
	parameter LWH2S_ADDRESS_WIDTH = 21  
) (
// h2f_reset
  output wire [1 - 1 : 0 ] h2f_rst
// h2f_axi_clock
 ,input wire [1 - 1 : 0 ] h2f_axi_clk
// h2f_axi_reset
 ,input wire [1 - 1 : 0 ] h2f_axi_rst_n
// h2f_axi_master
 ,output wire [4 - 1 : 0 ] h2f_AWID
 ,output wire [32 - 1 : 0 ] h2f_AWADDR
 ,output wire [8 - 1 : 0 ] h2f_AWLEN
 ,output wire [3 - 1 : 0 ] h2f_AWSIZE
 ,output wire [2 - 1 : 0 ] h2f_AWBURST
 ,output wire [1 - 1 : 0 ] h2f_AWLOCK
 ,output wire [4 - 1 : 0 ] h2f_AWCACHE
 ,output wire [3 - 1 : 0 ] h2f_AWPROT
 ,output wire [1 - 1 : 0 ] h2f_AWVALID
 ,input wire [1 - 1 : 0 ] h2f_AWREADY
 ,output wire [64 - 1 : 0 ] h2f_WDATA
 ,output wire [8 - 1 : 0 ] h2f_WSTRB
 ,output wire [1 - 1 : 0 ] h2f_WLAST
 ,output wire [1 - 1 : 0 ] h2f_WVALID
 ,input wire [1 - 1 : 0 ] h2f_WREADY
 ,input wire [4 - 1 : 0 ] h2f_BID
 ,input wire [2 - 1 : 0 ] h2f_BRESP
 ,input wire [1 - 1 : 0 ] h2f_BVALID
 ,output wire [1 - 1 : 0 ] h2f_BREADY
 ,output wire [4 - 1 : 0 ] h2f_ARID
 ,output wire [32 - 1 : 0 ] h2f_ARADDR
 ,output wire [8 - 1 : 0 ] h2f_ARLEN
 ,output wire [3 - 1 : 0 ] h2f_ARSIZE
 ,output wire [2 - 1 : 0 ] h2f_ARBURST
 ,output wire [1 - 1 : 0 ] h2f_ARLOCK
 ,output wire [4 - 1 : 0 ] h2f_ARCACHE
 ,output wire [3 - 1 : 0 ] h2f_ARPROT
 ,output wire [1 - 1 : 0 ] h2f_ARVALID
 ,input wire [1 - 1 : 0 ] h2f_ARREADY
 ,input wire [4 - 1 : 0 ] h2f_RID
 ,input wire [64 - 1 : 0 ] h2f_RDATA
 ,input wire [2 - 1 : 0 ] h2f_RRESP
 ,input wire [1 - 1 : 0 ] h2f_RLAST
 ,input wire [1 - 1 : 0 ] h2f_RVALID
 ,output wire [1 - 1 : 0 ] h2f_RREADY
// hps_io
 ,inout wire [1 - 1 : 0 ] SDMMC_CMD
 ,inout wire [1 - 1 : 0 ] SDMMC_D0
 ,inout wire [1 - 1 : 0 ] SDMMC_D1
 ,inout wire [1 - 1 : 0 ] SDMMC_D2
 ,inout wire [1 - 1 : 0 ] SDMMC_D3
 ,output wire [1 - 1 : 0 ] SDMMC_CCLK
);

wire [7:0] awuser_term;
wire [4:0] wsb_ssd_term;
wire [9:0] wsb_sid_term;

wire [7:0] aruser_term;
wire [4:0] rsb_ssd_term;
wire [9:0] rsb_sid_term;

wire [ 0:0] hps_mpfe_at_clock;
wire [ 0:0] hps_mpfe_at_reset;
wire [ 0:0] atb_clock;
wire [ 0:0] atb_reset;
wire [ 0:0] hps_afready;
wire [ 0:0] hps_afvalid;
wire [ 1:0] hps_atbytes;
wire [31:0] hps_atdata;
wire [ 6:0] hps_atid;
wire [ 0:0] hps_atready;
wire [ 0:0] hps_atvalid;
wire [ 0:0] hps_syncreq;
wire [ 0:0] mpfe_afready;
wire [ 0:0] mpfe_afvalid;
wire [ 1:0] mpfe_atbytes;
wire [31:0] mpfe_atdata;
wire [ 6:0] mpfe_atid;
wire [ 0:0] mpfe_atready;
wire [ 0:0] mpfe_atvalid;
wire [ 0:0] mpfe_syncreq;
wire [ 0:0] atb_afready_m;
wire [ 0:0] atb_afready_s;
wire [ 0:0] atb_afvalid_m;
wire [ 0:0] atb_afvalid_s;
wire [ 1:0] atb_atbytes_m;
wire [ 1:0] atb_atbytes_s;
wire [31:0] atb_atdata_m;
wire [31:0] atb_atdata_s;
wire [ 6:0] atb_atid_m;
wire [ 6:0] atb_atid_s;
wire [ 0:0] atb_atready_m;
wire [ 0:0] atb_atready_s;
wire [ 0:0] atb_atvalid_m;
wire [ 0:0] atb_atvalid_s;
wire [ 0:0] atb_syncreq_m;
wire [ 0:0] atb_syncreq_s;

wire [0:0] SDMMC_CMD_in;
tennm_io_ibuf #(.buffer_usage("HSSI")) hps_SDMMC_CMD_ibuf(
    .i(SDMMC_CMD),
    .o(SDMMC_CMD_in)
);

wire [0:0] SDMMC_CMD_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_CMD_obuf(
    .i(SDMMC_CMD_out),
    .o(SDMMC_CMD),
    .oe(1'b1)
);

wire [0:0] SDMMC_D0_in;
tennm_io_ibuf #(.buffer_usage("HSSI")) hps_SDMMC_D0_ibuf(
    .i(SDMMC_D0),
    .o(SDMMC_D0_in)
);

wire [0:0] SDMMC_D0_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_D0_obuf(
    .i(SDMMC_D0_out),
    .o(SDMMC_D0),
    .oe(1'b1)
);

wire [0:0] SDMMC_D1_in;
tennm_io_ibuf #(.buffer_usage("HSSI")) hps_SDMMC_D1_ibuf(
    .i(SDMMC_D1),
    .o(SDMMC_D1_in)
);

wire [0:0] SDMMC_D1_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_D1_obuf(
    .i(SDMMC_D1_out),
    .o(SDMMC_D1),
    .oe(1'b1)
);

wire [0:0] SDMMC_D2_in;
tennm_io_ibuf #(.buffer_usage("HSSI")) hps_SDMMC_D2_ibuf(
    .i(SDMMC_D2),
    .o(SDMMC_D2_in)
);

wire [0:0] SDMMC_D2_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_D2_obuf(
    .i(SDMMC_D2_out),
    .o(SDMMC_D2),
    .oe(1'b1)
);

wire [0:0] SDMMC_D3_in;
tennm_io_ibuf #(.buffer_usage("HSSI")) hps_SDMMC_D3_ibuf(
    .i(SDMMC_D3),
    .o(SDMMC_D3_in)
);

wire [0:0] SDMMC_D3_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_D3_obuf(
    .i(SDMMC_D3_out),
    .o(SDMMC_D3),
    .oe(1'b1)
);

wire [0:0] SDMMC_CCLK_out;
tennm_io_obuf #(.buffer_usage("HSSI")) hps_SDMMC_CCLK_obuf(
    .i(SDMMC_CCLK_out),
    .o(SDMMC_CCLK),
    .oe(1'b1)
);



tennm_hps_hps_wrapper hps_inst(
 .HPS_IOA_1_O({
    SDMMC_CCLK_out[0:0] // 0:0
  })
,.tpiu_trace_ctl({
    1'b1 // 0:0
  })
,.s2f_rst({
    h2f_rst[0:0] // 0:0
  })
,.HPS_IOA_5_O({
    SDMMC_D2_out[0:0] // 0:0
  })
,.soc2fpga_aw_cache({
    h2f_AWCACHE[3:0] // 3:0
  })
,.soc2fpga_port_size_config_0({
    1'b1 // 0:0
  })
,.soc2fpga_port_size_config_1({
    1'b0 // 0:0
  })
,.pclkendbg({
    1'b0 // 0:0
  })
,.soc2fpga_b_id({
    h2f_BID[3:0] // 3:0
  })
,.soc2fpga_aw_burst({
    h2f_AWBURST[1:0] // 1:0
  })
,.soc2fpga_w_data({
    h2f_WDATA[63:0] // 63:0
  })
,.HPS_IOA_2_I({
    SDMMC_CMD_in[0:0] // 0:0
  })
,.HPS_IOA_6_I({
    SDMMC_D3_in[0:0] // 0:0
  })
,.soc2fpga_r_last({
    h2f_RLAST[0:0] // 0:0
  })
,.HPS_IOA_2_O({
    SDMMC_CMD_out[0:0] // 0:0
  })
,.soc2fpga_ar_cache({
    h2f_ARCACHE[3:0] // 3:0
  })
,.HPS_IOA_6_O({
    SDMMC_D3_out[0:0] // 0:0
  })
,.soc2fpga_ar_burst({
    h2f_ARBURST[1:0] // 1:0
  })
,.soc2fpga_b_resp({
    h2f_BRESP[1:0] // 1:0
  })
,.soc2fpga_ar_lock({
    h2f_ARLOCK[0:0] // 0:0
  })
,.soc2fpga_ar_addr({
    h2f_ARADDR[31:0] // 31:0
  })
,.soc2fpga_r_id({
    h2f_RID[3:0] // 3:0
  })
,.soc2fpga_rst_n({
    h2f_axi_rst_n[0:0] // 0:0
  })
,.soc2fpga_aw_valid({
    h2f_AWVALID[0:0] // 0:0
  })
,.soc2fpga_b_valid({
    h2f_BVALID[0:0] // 0:0
  })
,.HPS_IOA_3_I({
    SDMMC_D0_in[0:0] // 0:0
  })
,.soc2fpga_w_last({
    h2f_WLAST[0:0] // 0:0
  })
,.soc2fpga_aw_len({
    h2f_AWLEN[7:0] // 7:0
  })
,.soc2fpga_w_valid({
    h2f_WVALID[0:0] // 0:0
  })
,.soc2fpga_ar_prot({
    h2f_ARPROT[2:0] // 2:0
  })
,.HPS_IOA_3_O({
    SDMMC_D0_out[0:0] // 0:0
  })
,.soc2fpga_aw_lock({
    h2f_AWLOCK[0:0] // 0:0
  })
,.f2s_pending_rst_ack({
    1'b1 // 0:0
  })
,.soc2fpga_aw_addr({
    h2f_AWADDR[31:0] // 31:0
  })
,.soc2fpga_ar_valid({
    h2f_ARVALID[0:0] // 0:0
  })
,.soc2fpga_r_resp({
    h2f_RRESP[1:0] // 1:0
  })
,.soc2fpga_aw_ready({
    h2f_AWREADY[0:0] // 0:0
  })
,.soc2fpga_ar_size({
    h2f_ARSIZE[2:0] // 2:0
  })
,.soc2fpga_b_ready({
    h2f_BREADY[0:0] // 0:0
  })
,.dbgapbdisable({
    1'b0 // 0:0
  })
,.soc2fpga_r_valid({
    h2f_RVALID[0:0] // 0:0
  })
,.HPS_IOA_4_I({
    SDMMC_D1_in[0:0] // 0:0
  })
,.soc2fpga_w_ready({
    h2f_WREADY[0:0] // 0:0
  })
,.soc2fpga_aw_prot({
    h2f_AWPROT[2:0] // 2:0
  })
,.soc2fpga_ar_ready({
    h2f_ARREADY[0:0] // 0:0
  })
,.HPS_IOA_4_O({
    SDMMC_D1_out[0:0] // 0:0
  })
,.soc2fpga_w_strb({
    h2f_WSTRB[7:0] // 7:0
  })
,.soc2fpga_aw_size({
    h2f_AWSIZE[2:0] // 2:0
  })
,.soc2fpga_aw_id({
    h2f_AWID[3:0] // 3:0
  })
,.soc2fpga_r_ready({
    h2f_RREADY[0:0] // 0:0
  })
,.soc2fpga_ar_id({
    h2f_ARID[3:0] // 3:0
  })
,.soc2fpga_ar_len({
    h2f_ARLEN[7:0] // 7:0
  })
,.f2s_free_clk({
    1'b0 // 0:0
  })
,.soc2fpga_clk({
    h2f_axi_clk[0:0] // 0:0
  })
,.soc2fpga_r_data({
    64'b0000000000000000000000000000000000000000000000000000000000000000 // 127:64
   ,h2f_RDATA[63:0] // 63:0
  })
,.HPS_IOA_5_I({
    SDMMC_D2_in[0:0] // 0:0
  })
);

defparam hps_inst.mpu_free_clk_hz = 32'b01000111100001101000110000000000;
defparam hps_inst.SWDTH = 8;
defparam hps_inst.ADDR = 32;
defparam hps_inst.WDTH = 64;
endmodule

