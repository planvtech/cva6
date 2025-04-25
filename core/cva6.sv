// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 19.03.2017
// Description: CVA6 Top-level module

`include "rvfi_types.svh"
`include "cvxif_types.svh"
`include "ypb_types.svh"

module cva6
  import ariane_pkg::*;
#(
    // CVA6 config
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,

    // RVFI PROBES
    parameter type rvfi_probes_t = logic,

    // NOC Types AXI bus or several OBI bus
    parameter type noc_req_t  = logic,
    parameter type noc_resp_t = logic,

    // CVXIF Types
    localparam type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    localparam type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    localparam type id_t = `ID_T(CVA6Cfg),
    localparam type hartid_t = `HARTID_T(CVA6Cfg),
    localparam type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    localparam type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),
    localparam type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartit_t, id_t),
    localparam type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    localparam type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    localparam type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
    localparam type x_result_t = `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t),
    localparam type cvxif_req_t =
    `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_req_t, x_commit_t),
    localparam type cvxif_resp_t =
    `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t),

    //mkdigitals added for debug
    parameter type ypb_fetch_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH),
    parameter type ypb_fetch_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH),
    parameter type ypb_store_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_store_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_amo_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_amo_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_load_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_load_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_mmu_ptw_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_mmu_ptw_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_zcmt_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN),
    parameter type ypb_zcmt_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN)
    
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Reset boot address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hard ID reflected as CSR - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Inter-processor (async) interrupt - SUBSYSTEM
    input logic ipi_i,
    // Timer (async) interrupt - SUBSYSTEM
    input logic time_irq_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Probes to build RVFI, can be left open when not used - RVFI
    output rvfi_probes_t rvfi_probes_o,
    // CVXIF request - SUBSYSTEM
    output cvxif_req_t cvxif_req_o,
    // CVXIF response - SUBSYSTEM
    input cvxif_resp_t cvxif_resp_i,
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input noc_resp_t noc_resp_i,

    //mkdigitals debugging signals
    output logic obi_cache_status_o,

    output ypb_fetch_req_t ypb_fetch_req_o,
    output ypb_fetch_rsp_t ypb_fetch_rsp_o,

    output ypb_store_req_t ypb_store_req_o,
    output ypb_store_rsp_t ypb_store_rsp_o,

    output ypb_amo_req_t ypb_amo_req_o,
    output ypb_amo_rsp_t ypb_amo_rsp_o,

    output ypb_load_req_t ypb_load_req_o,
    output ypb_load_rsp_t ypb_load_rsp_o,

    output ypb_mmu_ptw_req_t ypb_mmu_ptw_req_o,
    output ypb_mmu_ptw_rsp_t ypb_mmu_ptw_rsp_o,

    output ypb_zcmt_req_t ypb_zcmt_req_o,
    output ypb_zcmt_rsp_t ypb_zcmt_rsp_o
);

  //mkdigitals commented out
  // localparam type ypb_fetch_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH);
  // localparam type ypb_fetch_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.FETCH_WIDTH);
  // localparam type ypb_store_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_store_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_amo_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_amo_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_load_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_load_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_mmu_ptw_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_mmu_ptw_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_zcmt_req_t = `YPB_REQ_T(CVA6Cfg, CVA6Cfg.XLEN);
  // localparam type ypb_zcmt_rsp_t = `YPB_RSP_T(CVA6Cfg, CVA6Cfg.XLEN);


  logic icache_enable;
  logic icache_flush;
  logic icache_miss;

  logic dcache_enable;
  logic dcache_flush;
  logic dcache_flush_ack;
  logic dcache_miss;

  logic wbuffer_empty;
  logic wbuffer_not_ni;


  ypb_fetch_req_t ypb_fetch_req;
  ypb_fetch_rsp_t ypb_fetch_rsp;

  ypb_store_req_t ypb_store_req;
  ypb_store_rsp_t ypb_store_rsp;

  ypb_amo_req_t ypb_amo_req;
  ypb_amo_rsp_t ypb_amo_rsp;

  ypb_load_req_t ypb_load_req;
  ypb_load_rsp_t ypb_load_rsp;

  ypb_mmu_ptw_req_t ypb_mmu_ptw_req;
  ypb_mmu_ptw_rsp_t ypb_mmu_ptw_rsp;

  ypb_zcmt_req_t ypb_zcmt_req;
  ypb_zcmt_rsp_t ypb_zcmt_rsp;

  //notes : 
  //CVA6Cfg.NrFetchBufEntries : 1; for fetch_req
  //NrLoadBufEntries: unsigned'(2) for load_req
  //assign ypb_store_req_o.aid = '0; for store_req
  //assign ypb_amo_req_o.aid = '0;
  //assign ypb_mmu_ptw_req_o.aid = '0;
  //ypb_zcmt_req_o.aid      = 1'b1;

  // -------------------
  // Pipeline
  // -------------------

  cva6_pipeline #(
      // CVA6 config
      .CVA6Cfg            (CVA6Cfg),
      // RVFI PROBES
      .rvfi_probes_t      (rvfi_probes_t),
      // YPB 
      .ypb_fetch_req_t    (ypb_fetch_req_t),
      .ypb_fetch_rsp_t    (ypb_fetch_rsp_t),
      .ypb_store_req_t    (ypb_store_req_t),
      .ypb_store_rsp_t    (ypb_store_rsp_t),
      .ypb_amo_req_t      (ypb_amo_req_t),
      .ypb_amo_rsp_t      (ypb_amo_rsp_t),
      .ypb_load_req_t     (ypb_load_req_t),
      .ypb_load_rsp_t     (ypb_load_rsp_t),
      .ypb_mmu_ptw_req_t  (ypb_mmu_ptw_req_t),
      .ypb_mmu_ptw_rsp_t  (ypb_mmu_ptw_rsp_t),
      .ypb_zcmt_req_t     (ypb_zcmt_req_t),
      .ypb_zcmt_rsp_t     (ypb_zcmt_rsp_t),
      // CVXIF
      .readregflags_t     (readregflags_t),
      .writeregflags_t    (writeregflags_t),
      .id_t               (id_t),
      .hartid_t           (hartid_t),
      .x_compressed_req_t (x_compressed_req_t),
      .x_compressed_resp_t(x_compressed_resp_t),
      .x_issue_req_t      (x_issue_req_t),
      .x_issue_resp_t     (x_issue_resp_t),
      .x_register_t       (x_register_t),
      .x_commit_t         (x_commit_t),
      .x_result_t         (x_result_t),
      .cvxif_req_t        (cvxif_req_t),
      .cvxif_resp_t       (cvxif_resp_t)
      //
  ) i_cva6_pipeline (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .boot_addr_i(boot_addr_i),
      .hart_id_i(hart_id_i),
      .irq_i(irq_i),
      .ipi_i(ipi_i),
      .time_irq_i(time_irq_i),
      .debug_req_i(debug_req_i),
      .rvfi_probes_o(rvfi_probes_o),
      .cvxif_req_o(cvxif_req_o),
      .cvxif_resp_i(cvxif_resp_i),

      // FROM/TO ICACHE SUBSYSTEM

      .icache_enable_o(icache_enable),
      .icache_flush_o (icache_flush),
      .icache_miss_i  (icache_miss),

      .ypb_fetch_req_o(ypb_fetch_req),
      .ypb_fetch_rsp_i(ypb_fetch_rsp),

      // FROM/TO DCACHE SUBSYSTEM

      .dcache_enable_o   (dcache_enable),
      .dcache_flush_o    (dcache_flush),
      .dcache_flush_ack_i(dcache_flush_ack),
      .dcache_miss_i     (dcache_miss),

      .ypb_store_req_o  (ypb_store_req),
      .ypb_store_rsp_i  (ypb_store_rsp),
      .ypb_amo_req_o    (ypb_amo_req),
      .ypb_amo_rsp_i    (ypb_amo_rsp),
      .ypb_load_req_o   (ypb_load_req),
      .ypb_load_rsp_i   (ypb_load_rsp),
      .ypb_mmu_ptw_req_o(ypb_mmu_ptw_req),
      .ypb_mmu_ptw_rsp_i(ypb_mmu_ptw_rsp),
      .ypb_zcmt_req_o   (ypb_zcmt_req),
      .ypb_zcmt_rsp_i   (ypb_zcmt_rsp),

      .dcache_wbuffer_empty_i (wbuffer_empty),
      .dcache_wbuffer_not_ni_i(wbuffer_not_ni)
  );


  if (CVA6Cfg.PipelineOnly) begin : gen_obi_adapter

    // -------------------
    // OBI Adapter
    // -------------------

    cva6_obi_adapter_subsystem #(
        .CVA6Cfg          (CVA6Cfg),
        .ypb_fetch_req_t  (ypb_fetch_req_t),
        .ypb_fetch_rsp_t  (ypb_fetch_rsp_t),
        .ypb_store_req_t  (ypb_store_req_t),
        .ypb_store_rsp_t  (ypb_store_rsp_t),
        .ypb_amo_req_t    (ypb_amo_req_t),
        .ypb_amo_rsp_t    (ypb_amo_rsp_t),
        .ypb_load_req_t   (ypb_load_req_t),
        .ypb_load_rsp_t   (ypb_load_rsp_t),
        .ypb_mmu_ptw_req_t(ypb_mmu_ptw_req_t),
        .ypb_mmu_ptw_rsp_t(ypb_mmu_ptw_rsp_t),
        .ypb_zcmt_req_t   (ypb_zcmt_req_t),
        .ypb_zcmt_rsp_t   (ypb_zcmt_rsp_t),
        .noc_req_t        (noc_req_t),
        .noc_resp_t       (noc_resp_t)

    ) i_cva6_obi_adapter_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        // FROM/TO PIPELINE (YPB)

        .ypb_fetch_req_i  (ypb_fetch_req),
        .ypb_fetch_rsp_o  (ypb_fetch_rsp),
        .ypb_store_req_i  (ypb_store_req),
        .ypb_store_rsp_o  (ypb_store_rsp),
        .ypb_amo_req_i    (ypb_amo_req),
        .ypb_amo_rsp_o    (ypb_amo_rsp),
        .ypb_load_req_i   (ypb_load_req),
        .ypb_load_rsp_o   (ypb_load_rsp),
        .ypb_mmu_ptw_req_i(ypb_mmu_ptw_req),
        .ypb_mmu_ptw_rsp_o(ypb_mmu_ptw_rsp),
        .ypb_zcmt_req_i   (ypb_zcmt_req),
        .ypb_zcmt_rsp_o   (ypb_zcmt_rsp),

        // CACHE CONTROL (NO USED)

        .icache_en_i       (icache_enable),
        .icache_flush_i    (icache_flush),
        .icache_miss_o     (icache_miss),
        .dcache_enable_i   (dcache_enable),
        .dcache_flush_i    (dcache_flush),
        .dcache_flush_ack_o(dcache_flush_ack),
        .dcache_miss_o     (dcache_miss),
        .wbuffer_empty_o   (wbuffer_empty),
        .wbuffer_not_ni_o  (wbuffer_not_ni),

        // FROM/TO NOC (OBI)

        .noc_req_o (noc_req_o),
        .noc_resp_i(noc_resp_i)
    );
    // assign obi_cache_status_o = 1'b0;

  end else begin : gen_cache_subsystem

    // -------------------
    // Cache Subsystem
    // -------------------

    cva6_hpdcache_subsystem #(
        .CVA6Cfg          (CVA6Cfg),
        .ypb_fetch_req_t  (ypb_fetch_req_t),
        .ypb_fetch_rsp_t  (ypb_fetch_rsp_t),
        .ypb_store_req_t  (ypb_store_req_t),
        .ypb_store_rsp_t  (ypb_store_rsp_t),
        .ypb_amo_req_t    (ypb_amo_req_t),
        .ypb_amo_rsp_t    (ypb_amo_rsp_t),
        .ypb_load_req_t   (ypb_load_req_t),
        .ypb_load_rsp_t   (ypb_load_rsp_t),
        .ypb_mmu_ptw_req_t(ypb_mmu_ptw_req_t),
        .ypb_mmu_ptw_rsp_t(ypb_mmu_ptw_rsp_t),
        .ypb_zcmt_req_t   (ypb_zcmt_req_t),
        .ypb_zcmt_rsp_t   (ypb_zcmt_rsp_t),
        .noc_req_t        (noc_req_t),
        .noc_resp_t       (noc_resp_t),
        .cmo_req_t        (logic  /*FIXME*/),
        .cmo_rsp_t        (logic  /*FIXME*/)
    ) i_cache_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        // FROM/TO FETCH

        .icache_enable_i(icache_enable),
        .icache_flush_i (icache_flush),
        .icache_miss_o  (icache_miss),

        // FETCH FROM/TO PIPELINE (YPB)

        .ypb_fetch_req_i(ypb_fetch_req),
        .ypb_fetch_rsp_o(ypb_fetch_rsp),

        // FROM/TO LSU

        .dcache_enable_i   (dcache_enable),
        .dcache_flush_i    (dcache_flush),
        .dcache_flush_ack_o(dcache_flush_ack),
        .dcache_miss_o     (dcache_miss),

        // DATA FROM/TO PIPELINE (YPB)

        .ypb_store_req_i  (ypb_store_req),
        .ypb_store_rsp_o  (ypb_store_rsp),
        .ypb_amo_req_i    (ypb_amo_req),
        .ypb_amo_rsp_o    (ypb_amo_rsp),
        .ypb_load_req_i   (ypb_load_req),
        .ypb_load_rsp_o   (ypb_load_rsp),
        .ypb_mmu_ptw_req_i(ypb_mmu_ptw_req),
        .ypb_mmu_ptw_rsp_o(ypb_mmu_ptw_rsp),
        .ypb_zcmt_req_i   (ypb_zcmt_req),
        .ypb_zcmt_rsp_o   (ypb_zcmt_rsp),

        .wbuffer_empty_o (wbuffer_empty),
        .wbuffer_not_ni_o(wbuffer_not_ni),

        // FROM/TO CMO

        .dcache_cmo_req_i('0  /*FIXME*/),
        .dcache_cmo_rsp_o(  /*FIXME*/),

        // FROM/TO HW PREFETCHER

        .hwpf_base_set_i    ('0  /*FIXME*/),
        .hwpf_base_i        ('0  /*FIXME*/),
        .hwpf_base_o        (  /*FIXME*/),
        .hwpf_param_set_i   ('0  /*FIXME*/),
        .hwpf_param_i       ('0  /*FIXME*/),
        .hwpf_param_o       (  /*FIXME*/),
        .hwpf_throttle_set_i('0  /*FIXME*/),
        .hwpf_throttle_i    ('0  /*FIXME*/),
        .hwpf_throttle_o    (  /*FIXME*/),
        .hwpf_status_o      (  /*FIXME*/),

        // FROM/TO NOC (AXI)

        .noc_req_o (noc_req_o),
        .noc_resp_i(noc_resp_i)
    );
    // assign obi_cache_status_o = 1'b1;
  end

  // //mkdigidtals_debugging signals
  assign ypb_fetch_req_o   = ypb_fetch_req;
  assign ypb_fetch_rsp_o   = ypb_fetch_rsp;
  assign ypb_store_req_o   = ypb_store_req;
  assign ypb_store_rsp_o   = ypb_store_rsp;
  assign ypb_amo_req_o     = ypb_amo_req;
  assign ypb_amo_rsp_o     = ypb_amo_rsp;
  assign ypb_load_req_o    = ypb_load_req;
  assign ypb_load_rsp_o    = ypb_load_rsp;
  assign ypb_mmu_ptw_req_o = ypb_mmu_ptw_req;
  assign ypb_mmu_ptw_rsp_o = ypb_mmu_ptw_rsp;
  assign ypb_zcmt_req_o    = ypb_zcmt_req;
  assign ypb_zcmt_rsp_o    = ypb_zcmt_rsp;
  
  // ----------------
  // Accelerator
  // ----------------

  if (CVA6Cfg.EnableAccelerator) begin : gen_accelerator
    acc_dispatcher #(
        .CVA6Cfg           (CVA6Cfg),
        .fu_data_t         (fu_data_t),
        .dcache_req_i_t    (dcache_req_i_t),
        .dcache_req_o_t    (dcache_req_o_t),
        .exception_t       (exception_t),
        .scoreboard_entry_t(scoreboard_entry_t),
        .acc_cfg_t         (acc_cfg_t),
        .AccCfg            (AccCfg),
        .acc_req_t         (cvxif_req_t),
        .acc_resp_t        (cvxif_resp_t),
        .accelerator_req_t (accelerator_req_t),
        .accelerator_resp_t(accelerator_resp_t),
        .acc_mmu_req_t     (acc_mmu_req_t),
        .acc_mmu_resp_t    (acc_mmu_resp_t)
    ) i_acc_dispatcher (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),
        .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
        .flush_ex_i            (flush_ctrl_ex),
        .flush_pipeline_o      (flush_acc),
        .single_step_o         (single_step_acc_commit),
        .acc_cons_en_i         (acc_cons_en_csr),
        .acc_fflags_valid_o    (acc_resp_fflags_valid),
        .acc_fflags_o          (acc_resp_fflags),
        .ld_st_priv_lvl_i      (ld_st_priv_lvl_csr_ex),
        .sum_i                 (sum_csr_ex),
        .pmpcfg_i              (pmpcfg),
        .pmpaddr_i             (pmpaddr),
        .fcsr_frm_i            (frm_csr_id_issue_ex),
        .acc_mmu_en_i          (enable_translation_csr_ex),
        .dirty_v_state_o       (dirty_v_state),
        .issue_instr_i         (issue_instr_id_acc),
        .issue_instr_hs_i      (issue_instr_hs_id_acc),
        .issue_stall_o         (stall_acc_id),
        .fu_data_i             (fu_data_id_ex[0]),
        .commit_instr_i        (commit_instr_id_commit),
        .commit_st_barrier_i   (fence_i_commit_controller | fence_commit_controller),
        .acc_trans_id_o        (acc_trans_id_ex_id),
        .acc_result_o          (acc_result_ex_id),
        .acc_valid_o           (acc_valid_ex_id),
        .acc_exception_o       (acc_exception_ex_id),
        .acc_valid_ex_o        (acc_valid_acc_ex),
        .commit_ack_i          (commit_ack),
        .acc_stall_st_pending_o(stall_st_pending_ex),
        .acc_no_st_pending_i   (no_st_pending_commit),
        .dcache_req_ports_i    (dcache_req_ports_ex_cache),
        .acc_mmu_req_o         (acc_mmu_req),
        .acc_mmu_resp_i        (acc_mmu_resp),
        .ctrl_halt_o           (halt_acc_ctrl),
        .csr_addr_i            (csr_addr_ex_csr),
        .acc_dcache_req_ports_o(dcache_req_ports_acc_cache),
        .acc_dcache_req_ports_i(dcache_req_ports_cache_acc),
        .inval_ready_i         (inval_ready),
        .inval_valid_o         (inval_valid),
        .inval_addr_o          (inval_addr),
        .acc_req_o             (cvxif_req_o),
        .acc_resp_i            (cvxif_resp_i)
    );
  end : gen_accelerator
  else begin : gen_no_accelerator
    assign acc_trans_id_ex_id         = '0;
    assign acc_result_ex_id           = '0;
    assign acc_valid_ex_id            = '0;
    assign acc_exception_ex_id        = '0;
    assign acc_resp_fflags            = '0;
    assign acc_resp_fflags_valid      = '0;
    assign stall_acc_id               = '0;
    assign dirty_v_state              = '0;
    assign acc_valid_acc_ex           = '0;
    assign halt_acc_ctrl              = '0;
    assign stall_st_pending_ex        = '0;
    assign flush_acc                  = '0;
    assign single_step_acc_commit     = '0;

    // D$ connection is unused
    assign dcache_req_ports_acc_cache = '0;

    // MMU access is unused
    assign acc_mmu_req                = '0;

    // No invalidation interface
    assign inval_valid                = '0;
    assign inval_addr                 = '0;

    // Feed through cvxif
    assign cvxif_req_o                = cvxif_req;
  end : gen_no_accelerator

  // -------------------
  // Parameter Check
  // -------------------
  // pragma translate_off
  initial config_pkg::check_cfg(CVA6Cfg);
  // pragma translate_on

  // -------------------
  // Instruction Tracer
  // -------------------

  //pragma translate_off
`ifdef PITON_ARIANE
  localparam PC_QUEUE_DEPTH = 16;

  logic                                               piton_pc_vld;
  logic [         CVA6Cfg.VLEN-1:0]                   piton_pc;
  logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.VLEN-1:0] pc_data;
  logic [CVA6Cfg.NrCommitPorts-1:0] pc_pop, pc_empty;

  for (genvar i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin : gen_pc_fifo
    fifo_v3 #(
        .DATA_WIDTH(64),
        .DEPTH(PC_QUEUE_DEPTH),
        .FPGA_EN(CVA6Cfg.FpgaEn)
    ) i_pc_fifo (
        .clk_i     (clk_i),
        .rst_ni    (rst_ni),
        .flush_i   ('0),
        .testmode_i('0),
        .full_o    (),
        .empty_o   (pc_empty[i]),
        .usage_o   (),
        .data_i    (commit_instr_id_commit[i].pc),
        .push_i    (commit_ack[i] & ~commit_instr_id_commit[i].ex.valid),
        .data_o    (pc_data[i]),
        .pop_i     (pc_pop[i])
    );
  end

  rr_arb_tree #(
      .NumIn(CVA6Cfg.NrCommitPorts),
      .DataWidth(64)
  ) i_rr_arb_tree (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .flush_i('0),
      .rr_i   ('0),
      .req_i  (~pc_empty),
      .gnt_o  (pc_pop),
      .data_i (pc_data),
      .gnt_i  (piton_pc_vld),
      .req_o  (piton_pc_vld),
      .data_o (piton_pc),
      .idx_o  ()
  );
`endif  // PITON_ARIANE

`ifndef VERILATOR

  logic [31:0] fetch_instructions[CVA6Cfg.NrIssuePorts-1:0];

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; ++i) begin
    assign fetch_instructions[i] = fetch_entry_if_id[i].instruction;
  end

  instr_tracer #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .interrupts_t(interrupts_t),
      .exception_t(exception_t),
      .INTERRUPTS(INTERRUPTS)
  ) instr_tracer_i (
      // .tracer_if(tracer_if),
      .pck(clk_i),
      .rstn(rst_ni),
      .flush_unissued(flush_unissued_instr_ctrl_id),
      .flush_all(flush_ctrl_ex),
      .instruction(fetch_instructions),
      .fetch_valid(id_stage_i.fetch_entry_valid_i),
      .fetch_ack(id_stage_i.fetch_entry_ready_o),
      .issue_ack(issue_stage_i.i_scoreboard.issue_ack_i),
      .issue_sbe(issue_stage_i.i_scoreboard.issue_instr_o),
      .waddr(waddr_commit_id),
      .wdata(wdata_commit_id),
      .we_gpr(we_gpr_commit_id),
      .we_fpr(we_fpr_commit_id),
      .commit_instr(commit_instr_id_commit),
      .commit_ack(commit_ack),
      .st_valid(ex_stage_i.lsu_i.i_store_unit.store_buffer_i.valid_i),
      .st_paddr(ex_stage_i.lsu_i.i_store_unit.store_buffer_i.paddr_i),
      .ld_valid(ex_stage_i.lsu_i.i_load_unit.req_port_o.tag_valid),
      .ld_kill(ex_stage_i.lsu_i.i_load_unit.req_port_o.kill_req),
      .ld_paddr(ex_stage_i.lsu_i.i_load_unit.paddr_i),
      .resolve_branch(resolved_branch),
      .commit_exception(commit_stage_i.exception_o),
      .priv_lvl(priv_lvl),
      .debug_mode(debug_mode),
      .hart_id_i(hart_id_i)
  );

  // mock tracer for Verilator, to be used with spike-dasm
`else

  int f;
  logic [63:0] cycles;

  initial begin
    string fn;
    $sformat(fn, "trace_hart_%0.0f.dasm", hart_id_i);
    f = $fopen(fn, "w");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cycles <= 0;
    end else begin
      byte mode = "";
      if (CVA6Cfg.DebugEn && debug_mode) mode = "D";
      else begin
        case (priv_lvl)
          riscv::PRIV_LVL_M: mode = "M";
          riscv::PRIV_LVL_S: if (CVA6Cfg.RVS) mode = "S";
          riscv::PRIV_LVL_U: mode = "U";
          default: ;  // Do nothing
        endcase
      end
      for (int i = 0; i < CVA6Cfg.NrCommitPorts; i++) begin
        if (commit_ack[i] && !commit_instr_id_commit[i].ex.valid) begin
          $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc, mode,
                  commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].ex.tval[31:0]);
        end else if (commit_ack[i] && commit_instr_id_commit[i].ex.valid) begin
          if (commit_instr_id_commit[i].ex.cause == 2) begin
            $fwrite(f, "Exception Cause: Illegal Instructions, DASM(%h) PC=%h\n",
                    commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].pc);
          end else begin
            if (CVA6Cfg.DebugEn && debug_mode) begin
              $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc,
                      mode, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].ex.tval[31:0]);
            end else begin
              $fwrite(f, "Exception Cause: %5d, DASM(%h) PC=%h\n",
                      commit_instr_id_commit[i].ex.cause, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].pc);
            end
          end
        end
      end
      cycles <= cycles + 1;
    end
  end

  final begin
    $fclose(f);
  end
`endif  // VERILATOR
  //pragma translate_on


  //RVFI INSTR
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] rvfi_fetch_instr;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign rvfi_fetch_instr[i] = fetch_entry_if_id[i].instruction;
  end

  cva6_rvfi_probes #(
      .CVA6Cfg            (CVA6Cfg),
      .exception_t        (exception_t),
      .scoreboard_entry_t (scoreboard_entry_t),
      .lsu_ctrl_t         (lsu_ctrl_t),
      .bp_resolve_t       (bp_resolve_t),
      .rvfi_probes_instr_t(rvfi_probes_instr_t),
      .rvfi_probes_csr_t  (rvfi_probes_csr_t),
      .rvfi_probes_t      (rvfi_probes_t)
  ) i_cva6_rvfi_probes (

      .flush_i            (flush_ctrl_if),
      .issue_instr_ack_i  (issue_instr_issue_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .instruction_i      (rvfi_fetch_instr),
      .is_compressed_i    (rvfi_is_compressed),

      .issue_pointer_i (rvfi_issue_pointer),
      .commit_pointer_i(rvfi_commit_pointer),

      .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
      .decoded_instr_valid_i (issue_entry_valid_id_issue),
      .decoded_instr_ack_i   (issue_instr_issue_id),

      .rs1_i(rvfi_rs1),
      .rs2_i(rvfi_rs2),

      .commit_instr_i(commit_instr_id_commit),
      .commit_drop_i (commit_drop_id_commit),
      .ex_commit_i   (ex_commit),
      .priv_lvl_i    (priv_lvl),

      .lsu_ctrl_i  (rvfi_lsu_ctrl),
      .wbdata_i    (wbdata_ex_id),
      .commit_ack_i(commit_ack),
      .mem_paddr_i (rvfi_mem_paddr),
      .debug_mode_i(debug_mode),
      .wdata_i     (wdata_commit_id),

      .csr_i(rvfi_csr),
      .irq_i(irq_i),
      .resolved_branch_i(resolved_branch),
      .flu_trans_id_ex_id_i(flu_trans_id_ex_id),
      .rvfi_probes_o(rvfi_probes_o)

  );

  //pragma translate_off
  initial begin
    assert (!(CVA6Cfg.SuperscalarEn && CVA6Cfg.EnableAccelerator))
    else $fatal(1, "Accelerator is not supported by superscalar pipeline");
  end
  //pragma translate_on

endmodule  // ariane
