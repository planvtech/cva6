// Copyright 2018 ETH Zurich and University of Bologna.
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
// Date: 19/04/2017
// Description: Memory Management Unit for Ariane, contains TLB and
//              address translation unit. SV39 as defined in RISC-V
//              privilege specification 1.11-WIP


module cva6_mmu
import ariane_pkg::*;
#(
  parameter config_pkg::cva6_cfg_t CVA6Cfg           = config_pkg::cva6_cfg_empty,
  parameter int unsigned           INSTR_TLB_ENTRIES = 4,
  parameter int unsigned           DATA_TLB_ENTRIES  = 4,
  parameter int unsigned           ASID_WIDTH        = 1,
  parameter int unsigned           ASID_LEN = 1,
  parameter int unsigned           VPN_LEN = 1,
  parameter int unsigned           PT_LEVELS = 1
) (
  input logic clk_i,
  input logic rst_ni,
  input logic flush_i,
  input logic enable_translation_i,
  input logic en_ld_st_translation_i,  // enable virtual memory translation for load/stores
  // IF interface
  input icache_arsp_t icache_areq_i,
  output icache_areq_t icache_areq_o,
  // LSU interface
  // this is a more minimalistic interface because the actual addressing logic is handled
  // in the LSU as we distinguish load and stores, what we do here is simple address translation
  input exception_t misaligned_ex_i,
  input logic lsu_req_i,  // request address translation
  input logic [riscv::VLEN-1:0] lsu_vaddr_i,  // virtual address in
  input logic lsu_is_store_i,  // the translation is requested by a store
  // if we need to walk the page table we can't grant in the same cycle
  // Cycle 0
  output logic                            lsu_dtlb_hit_o,   // sent in the same cycle as the request if translation hits in the DTLB
  output logic [riscv::PPNW-1:0] lsu_dtlb_ppn_o,  // ppn (send same cycle as hit)
  // Cycle 1
  output logic lsu_valid_o,  // translation is valid
  output logic [riscv::PLEN-1:0] lsu_paddr_o,  // translated address
  output exception_t lsu_exception_o,  // address translation threw an exception
  // General control signals
  input riscv::priv_lvl_t priv_lvl_i,
  input riscv::priv_lvl_t ld_st_priv_lvl_i,
  input logic sum_i,
  input logic mxr_i,
  // input logic flag_mprv_i,
  input logic [riscv::PPNW-1:0] satp_ppn_i,
  input logic [ASID_WIDTH-1:0] asid_i,
  input logic [ASID_WIDTH-1:0] asid_to_be_flushed_i,
  input logic [riscv::VLEN-1:0] vaddr_to_be_flushed_i,
  input logic flush_tlb_i,
  // Performance counters
  output logic itlb_miss_o,
  output logic dtlb_miss_o,
  // PTW memory interface
  input dcache_req_o_t req_port_i,
  output dcache_req_i_t req_port_o,
  // PMP
  input riscv::pmpcfg_t [15:0] pmpcfg_i,
  input logic [15:0][riscv::PLEN-3:0] pmpaddr_i
);

logic                   iaccess_err;  // insufficient privilege to access this instruction page
logic                   daccess_err;  // insufficient privilege to access this data page
logic                   ptw_active;  // PTW is currently walking a page table
logic                   walking_instr;  // PTW is walking because of an ITLB miss
logic                   ptw_error;  // PTW threw an exception
logic                   ptw_access_exception;  // PTW threw an access exception (PMPs)
logic [riscv::PLEN-1:0] ptw_bad_paddr;  // PTW PMP exception bad physical addr

logic [riscv::VLEN-1:0] update_vaddr;
tlb_update_t update_ptw_itlb, update_ptw_dtlb;
tlb_update_cva6_t update_itlb, update_dtlb, update_shared_tlb;

logic                               itlb_lu_access;
riscv::pte_cva6_t                   itlb_content;
logic [PT_LEVELS-2:0]               itlb_is_page;
logic                               itlb_lu_hit;

logic                               dtlb_lu_access;
riscv::pte_cva6_t                   dtlb_content;
logic [PT_LEVELS-2:0]               dtlb_is_page;
logic                               dtlb_lu_hit;

logic                               shared_tlb_access;
logic             [riscv::VLEN-1:0] shared_tlb_vaddr;
logic                               shared_tlb_hit;


// Assignments
assign itlb_lu_access = icache_areq_i.fetch_req;
assign dtlb_lu_access = lsu_req_i;


cva6_tlb #(
  .CVA6Cfg    (CVA6Cfg),
  .TLB_ENTRIES(INSTR_TLB_ENTRIES),
  .ASID_WIDTH (ASID_WIDTH),
  .ASID_LEN (ASID_LEN),
  .VPN_LEN(VPN_LEN),
  .PT_LEVELS(PT_LEVELS)
) i_itlb (
  .clk_i  (clk_i),
  .rst_ni (rst_ni),
  .flush_i(flush_tlb_i),

  .update_i(update_itlb),

  .lu_access_i          (itlb_lu_access),
  .lu_asid_i            (asid_i),
  .asid_to_be_flushed_i (asid_to_be_flushed_i),
  .vaddr_to_be_flushed_i(vaddr_to_be_flushed_i),
  .lu_vaddr_i           (icache_areq_i.fetch_vaddr),
  .lu_content_o         (itlb_content),

  .lu_is_page_o(itlb_is_page),
  .lu_hit_o  (itlb_lu_hit)
);

cva6_tlb #(
  .CVA6Cfg    (CVA6Cfg),
  .TLB_ENTRIES(DATA_TLB_ENTRIES),
  .ASID_WIDTH (ASID_WIDTH),
  .ASID_LEN (ASID_LEN),
  .VPN_LEN(VPN_LEN),
  .PT_LEVELS(PT_LEVELS)
) i_dtlb (
  .clk_i  (clk_i),
  .rst_ni (rst_ni),
  .flush_i(flush_tlb_i),

  .update_i(update_dtlb),

  .lu_access_i          (dtlb_lu_access),
  .lu_asid_i            (asid_i),
  .asid_to_be_flushed_i (asid_to_be_flushed_i),
  .vaddr_to_be_flushed_i(vaddr_to_be_flushed_i),
  .lu_vaddr_i           (lsu_vaddr_i),
  .lu_content_o         (dtlb_content),

  .lu_is_page_o(dtlb_is_page),
  .lu_hit_o  (dtlb_lu_hit)
);

// cva6_shared_tlb #(
//       .CVA6Cfg         (CVA6Cfg),
//       .SHARED_TLB_DEPTH(64),
//       .SHARED_TLB_WAYS (2),
//       .ASID_WIDTH      (ASID_WIDTH),
//       .ASID_LEN (ASID_LEN),
//       .VPN_LEN(VPN_LEN),
//       .PT_LEVELS(PT_LEVELS)
//   ) i_shared_tlb (
//       .clk_i  (clk_i),
//       .rst_ni (rst_ni),
//       .flush_i(flush_tlb_i),

//       .enable_translation_i  (enable_translation_i),
//       .en_ld_st_translation_i(en_ld_st_translation_i),

//       .asid_i       (asid_i),
//       // from TLBs
//       // did we miss?
//       .itlb_access_i(itlb_lu_access),
//       .itlb_hit_i   (itlb_lu_hit),
//       .itlb_vaddr_i (icache_areq_i.fetch_vaddr),

//       .dtlb_access_i(dtlb_lu_access),
//       .dtlb_hit_i   (dtlb_lu_hit),
//       .dtlb_vaddr_i (lsu_vaddr_i),

//       // to TLBs, update logic
//       .itlb_update_o(update_itlb),
//       .dtlb_update_o(update_dtlb),

//       // Performance counters
//       .itlb_miss_o(itlb_miss_o),
//       .dtlb_miss_o(dtlb_miss_o),

//       .shared_tlb_access_o(shared_tlb_access),
//       .shared_tlb_hit_o   (shared_tlb_hit),
//       .shared_tlb_vaddr_o (shared_tlb_vaddr),

//       .itlb_req_o         (itlb_req),
//       // to update shared tlb
//       .shared_tlb_update_i(update_shared_tlb)
//   );

//   cva6_ptw #(
//       .CVA6Cfg   (CVA6Cfg),
//       .ASID_WIDTH(ASID_WIDTH),
//       .VPN_LEN(VPN_LEN),
//       .PT_LEVELS(PT_LEVELS)
//   ) i_ptw (
//       .clk_i  (clk_i),
//       .rst_ni (rst_ni),
//       .flush_i(flush_i),

//       .ptw_active_o          (ptw_active),
//       .walking_instr_o       (walking_instr),
//       .ptw_error_o           (ptw_error),
//       .ptw_access_exception_o(ptw_access_exception),

//       .lsu_is_store_i(lsu_is_store_i),
//       // PTW memory interface
//       .req_port_i    (req_port_i),
//       .req_port_o    (req_port_o),

//       // to Shared TLB, update logic
//       .shared_tlb_update_o(update_shared_tlb),

//       .update_vaddr_o(update_vaddr),

//       .asid_i(asid_i),

//       // from shared TLB
//       // did we miss?
//       .shared_tlb_access_i(shared_tlb_access),
//       .shared_tlb_hit_i   (shared_tlb_hit),
//       .shared_tlb_vaddr_i (shared_tlb_vaddr),

//       .itlb_req_i(itlb_req),

//       // from CSR file
//       .satp_ppn_i(satp_ppn_i),  // ppn from satp
//       .mxr_i     (mxr_i),

//       // Performance counters
//       .shared_tlb_miss_o(),  //open for now

//       // PMP
//       .pmpcfg_i   (pmpcfg_i),
//       .pmpaddr_i  (pmpaddr_i),
//       .bad_paddr_o(ptw_bad_paddr)

//   );

ptw #(
    .CVA6Cfg   (CVA6Cfg),
    .ASID_WIDTH(ASID_WIDTH)
) i_ptw (
    .clk_i                 (clk_i),
    .rst_ni                (rst_ni),
    .ptw_active_o          (ptw_active),
    .walking_instr_o       (walking_instr),
    .ptw_error_o           (ptw_error),
    .ptw_access_exception_o(ptw_access_exception),
    .enable_translation_i  (enable_translation_i),

    .update_vaddr_o(update_vaddr),
    .itlb_update_o (update_ptw_itlb),
    .dtlb_update_o (update_ptw_dtlb),

    .itlb_access_i(itlb_lu_access),
    .itlb_hit_i   (itlb_lu_hit),
    .itlb_vaddr_i (icache_areq_i.fetch_vaddr),

    .dtlb_access_i(dtlb_lu_access),
    .dtlb_hit_i   (dtlb_lu_hit),
    .dtlb_vaddr_i (lsu_vaddr_i),

    .req_port_i (req_port_i),
    .req_port_o (req_port_o),
    .pmpcfg_i,
    .pmpaddr_i,
    .bad_paddr_o(ptw_bad_paddr),
    .*
);

assign update_dtlb.valid        = update_ptw_dtlb.valid;
assign update_dtlb.is_page[1]   = update_ptw_dtlb.is_2M;
assign update_dtlb.is_page[0]   = update_ptw_dtlb.is_1G;
assign update_dtlb.vpn          = update_ptw_dtlb.vpn;
assign update_dtlb.asid         = update_ptw_dtlb.asid;
assign update_dtlb.content.ppn  = update_ptw_dtlb.content.ppn;
assign update_dtlb.content.rsw  = update_ptw_dtlb.content.rsw;
assign update_dtlb.content.d    = update_ptw_dtlb.content.d;
assign update_dtlb.content.a    = update_ptw_dtlb.content.a;
assign update_dtlb.content.g    = update_ptw_dtlb.content.g;
assign update_dtlb.content.u    = update_ptw_dtlb.content.u;
assign update_dtlb.content.x    = update_ptw_dtlb.content.x;
assign update_dtlb.content.w    = update_ptw_dtlb.content.w;
assign update_dtlb.content.r    = update_ptw_dtlb.content.r;
assign update_dtlb.content.v    = update_ptw_dtlb.content.v;

assign update_itlb.valid        = update_ptw_itlb.valid;
assign update_itlb.is_page[1]   = update_ptw_itlb.is_2M;
assign update_itlb.is_page[0]   = update_ptw_itlb.is_1G;
assign update_itlb.vpn          = update_ptw_itlb.vpn;
assign update_itlb.asid         = update_ptw_itlb.asid;
assign update_itlb.content.ppn  = update_ptw_itlb.content.ppn;
assign update_itlb.content.rsw  = update_ptw_itlb.content.rsw;
assign update_itlb.content.d    = update_ptw_itlb.content.d;
assign update_itlb.content.a    = update_ptw_itlb.content.a;
assign update_itlb.content.g    = update_ptw_itlb.content.g;
assign update_itlb.content.u    = update_ptw_itlb.content.u;
assign update_itlb.content.x    = update_ptw_itlb.content.x;
assign update_itlb.content.w    = update_ptw_itlb.content.w;
assign update_itlb.content.r    = update_ptw_itlb.content.r;
assign update_itlb.content.v    = update_ptw_itlb.content.v;

// ila_1 i_ila_1 (
//     .clk(clk_i), // input wire clk
//     .probe0({req_port_o.address_tag, req_port_o.address_index}),
//     .probe1(req_port_o.data_req), // input wire [63:0]  probe1
//     .probe2(req_port_i.data_gnt), // input wire [0:0]  probe2
//     .probe3(req_port_i.data_rdata), // input wire [0:0]  probe3
//     .probe4(req_port_i.data_rvalid), // input wire [0:0]  probe4
//     .probe5(ptw_error), // input wire [1:0]  probe5
//     .probe6(update_vaddr), // input wire [0:0]  probe6
//     .probe7(update_ptw_itlb.valid), // input wire [0:0]  probe7
//     .probe8(update_ptw_dtlb.valid), // input wire [0:0]  probe8
//     .probe9(dtlb_lu_access), // input wire [0:0]  probe9
//     .probe10(lsu_vaddr_i), // input wire [0:0]  probe10
//     .probe11(dtlb_lu_hit), // input wire [0:0]  probe11
//     .probe12(itlb_lu_access), // input wire [0:0]  probe12
//     .probe13(icache_areq_i.fetch_vaddr), // input wire [0:0]  probe13
//     .probe14(itlb_lu_hit) // input wire [0:0]  probe13
// );

  //-----------------------
  // Instruction Interface
  //-----------------------
logic match_any_execute_region;
logic pmp_instr_allow;
localparam PPNWMin = (riscv::PPNW - 1 > 29) ? 29 : riscv::PPNW - 1;

assign icache_areq_o.fetch_paddr    [11:0] = icache_areq_i.fetch_vaddr[11:0];
assign icache_areq_o.fetch_paddr [riscv::PLEN-1:PPNWMin+1]   = //
                          (enable_translation_i) ? //
                          itlb_content.ppn[riscv::PPNW-1:(riscv::PPNW - (riscv::PLEN - PPNWMin-1))] : //
                          riscv::PLEN'(icache_areq_i.fetch_vaddr[((riscv::PLEN > riscv::VLEN) ? riscv::VLEN : riscv::PLEN )-1:PPNWMin+1]);

genvar a;
generate
  
    for (a=0; a < PT_LEVELS-1; a++) begin  
     assign icache_areq_o.fetch_paddr [PPNWMin-((VPN_LEN/PT_LEVELS)*(a)):PPNWMin-((VPN_LEN/PT_LEVELS)*(a+1))+1] = //
                          (enable_translation_i && (|itlb_is_page[a:0]==0)) ? //
                          itlb_content.ppn  [(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(a))-1):(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(a+1)))] : //
                          icache_areq_i.fetch_vaddr[PPNWMin-((VPN_LEN/PT_LEVELS)*(a)):PPNWMin-((VPN_LEN/PT_LEVELS)*(a+1))+1];
    end

endgenerate

// The instruction interface is a simple request response interface
always_comb begin : instr_interface
  // MMU disabled: just pass through
  icache_areq_o.fetch_valid = icache_areq_i.fetch_req;
  // two potential exception sources:
  // 1. HPTW threw an exception -> signal with a page fault exception
  // 2. We got an access error because of insufficient permissions -> throw an access exception
  icache_areq_o.fetch_exception = '0;
  // Check whether we are allowed to access this memory region from a fetch perspective
  iaccess_err   = icache_areq_i.fetch_req && enable_translation_i
                                               && (((priv_lvl_i == riscv::PRIV_LVL_U) && ~itlb_content.u)
                                               || ((priv_lvl_i == riscv::PRIV_LVL_S) && itlb_content.u));

  // MMU enabled: address from TLB, request delayed until hit. Error when TLB
  // hit and no access right or TLB hit and translated address not valid (e.g.
  // AXI decode error), or when PTW performs walk due to ITLB miss and raises
  // an error.
  if (enable_translation_i) begin
    // we work with SV39 or SV32, so if VM is enabled, check that all bits [riscv::VLEN-1:riscv::SV-1] are equal
    if (icache_areq_i.fetch_req && !((&icache_areq_i.fetch_vaddr[riscv::VLEN-1:riscv::SV-1]) == 1'b1 || (|icache_areq_i.fetch_vaddr[riscv::VLEN-1:riscv::SV-1]) == 1'b0)) begin
      icache_areq_o.fetch_exception = {
        riscv::INSTR_ACCESS_FAULT,
        {{riscv::XLEN - riscv::VLEN{1'b0}}, icache_areq_i.fetch_vaddr},
        1'b1
      };
    end

    icache_areq_o.fetch_valid = 1'b0;

    // ---------
    // ITLB Hit
    // --------
    // if we hit the ITLB output the request signal immediately
    if (itlb_lu_hit) begin
      icache_areq_o.fetch_valid = icache_areq_i.fetch_req;
      // we got an access error
      if (iaccess_err) begin
        // throw a page fault
        icache_areq_o.fetch_exception = {
          riscv::INSTR_PAGE_FAULT,
          {{riscv::XLEN - riscv::VLEN{1'b0}}, icache_areq_i.fetch_vaddr},
          1'b1
        };
      end else if (!pmp_instr_allow) begin
        icache_areq_o.fetch_exception = {
          riscv::INSTR_ACCESS_FAULT,
          {{riscv::XLEN - riscv::PLEN{1'b0}}, icache_areq_i.fetch_vaddr},
          1'b1
        };
      end
    end else
    // ---------
    // ITLB Miss
    // ---------
    // watch out for exceptions happening during walking the page table
    if (ptw_active && walking_instr) begin
      icache_areq_o.fetch_valid = ptw_error | ptw_access_exception;
      if (ptw_error)
        icache_areq_o.fetch_exception = {
          riscv::INSTR_PAGE_FAULT, {{riscv::XLEN - riscv::VLEN{1'b0}}, update_vaddr}, 1'b1
        };
      else
        icache_areq_o.fetch_exception = {
          riscv::INSTR_ACCESS_FAULT, {{riscv::XLEN - riscv::VLEN{1'b0}}, update_vaddr}, 1'b1
        };
    end
  end
  // if it didn't match any execute region throw an `Instruction Access Fault`
  // or: if we are not translating, check PMPs immediately on the paddr
  if ((!match_any_execute_region && !ptw_error) || (!enable_translation_i && !pmp_instr_allow)) begin
    icache_areq_o.fetch_exception = {
      riscv::INSTR_ACCESS_FAULT,
      {{riscv::XLEN - riscv::PLEN{1'b0}}, icache_areq_o.fetch_paddr},
      1'b1
    };
  end
end

// check for execute flag on memory
assign match_any_execute_region = config_pkg::is_inside_execute_regions(
    CVA6Cfg, {{64 - riscv::PLEN{1'b0}}, icache_areq_o.fetch_paddr}
);

// Instruction fetch
pmp #(
    .CVA6Cfg   (CVA6Cfg),
    .PLEN      (riscv::PLEN),
    .PMP_LEN   (riscv::PLEN - 2),
    .NR_ENTRIES(CVA6Cfg.NrPMPEntries)
) i_pmp_if (
    .addr_i       (icache_areq_o.fetch_paddr),
    .priv_lvl_i,
    // we will always execute on the instruction fetch port
    .access_type_i(riscv::ACCESS_EXEC),
    // Configuration
    .conf_addr_i  (pmpaddr_i),
    .conf_i       (pmpcfg_i),
    .allow_o      (pmp_instr_allow)
);

//-----------------------
// Data Interface
//-----------------------
logic [riscv::VLEN-1:0] lsu_vaddr_n, lsu_vaddr_q;
riscv::pte_t dtlb_pte_n, dtlb_pte_q;
exception_t misaligned_ex_n, misaligned_ex_q;
logic lsu_req_n, lsu_req_q;
logic lsu_is_store_n, lsu_is_store_q;
logic dtlb_hit_n, dtlb_hit_q;
logic [PT_LEVELS-2:0] dtlb_is_page_n, dtlb_is_page_q;

// check if we need to do translation or if we are always ready (e.g.: we are not translating anything)
assign lsu_dtlb_hit_o = (en_ld_st_translation_i) ? dtlb_lu_hit : 1'b1;

// Wires to PMP checks
riscv::pmp_access_t pmp_access_type;
logic               pmp_data_allow;


assign lsu_paddr_o    [11:0] = lsu_vaddr_q[11:0];
assign lsu_paddr_o [riscv::PLEN-1:PPNWMin+1]   = 
                            (en_ld_st_translation_i && !misaligned_ex_q.valid) ? //
                            dtlb_pte_q.ppn[riscv::PPNW-1:(riscv::PPNW - (riscv::PLEN - PPNWMin-1))] : // 
                            riscv::PLEN'(lsu_vaddr_q[((riscv::PLEN > riscv::VLEN) ? riscv::VLEN : riscv::PLEN )-1:PPNWMin+1]);
                            
genvar i;
  generate
    
      for (i=0; i < PT_LEVELS-1; i++) begin  
       assign lsu_paddr_o   [PPNWMin-((VPN_LEN/PT_LEVELS)*(i)):PPNWMin-((VPN_LEN/PT_LEVELS)*(i+1))+1] = //
                            (en_ld_st_translation_i && !misaligned_ex_q.valid && (|dtlb_is_page_q[i:0]==0)) ? //
                            dtlb_pte_q.ppn  [(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(i))-1):(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(i+1)))] : //
                            lsu_vaddr_q[PPNWMin-((VPN_LEN/PT_LEVELS)*(i)):PPNWMin-((VPN_LEN/PT_LEVELS)*(i+1))+1];

       assign lsu_dtlb_ppn_o[PPNWMin-((VPN_LEN/PT_LEVELS)*(i)):PPNWMin-((VPN_LEN/PT_LEVELS)*(i+1))+1] = //
                            (en_ld_st_translation_i && !misaligned_ex_q.valid && (|dtlb_is_page_q[i:0]==0)) ? //
                            dtlb_content.ppn[(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(i))-1):(riscv::PPNW - (riscv::PLEN - PPNWMin-1)-((VPN_LEN/PT_LEVELS)*(i+1)))] : //
                            lsu_vaddr_n[PPNWMin-((VPN_LEN/PT_LEVELS)*(i)):PPNWMin-((VPN_LEN/PT_LEVELS)*(i+1))+1];
      end
      if(riscv::IS_XLEN64) begin
        assign lsu_dtlb_ppn_o[riscv::PPNW-1:PPNWMin+1] = (en_ld_st_translation_i && !misaligned_ex_q.valid) ? 
                            dtlb_content.ppn[riscv::PPNW-1:PPNWMin+1] : 
                            lsu_vaddr_n[riscv::PPNW-1:PPNWMin+1] ;
      end

  endgenerate  // The data interface is simpler and only consists of a request/response interface
always_comb begin : data_interface
  // save request and DTLB response
  lsu_vaddr_n = lsu_vaddr_i;
  lsu_req_n = lsu_req_i;
  misaligned_ex_n = misaligned_ex_i;
  dtlb_pte_n = dtlb_content;
  dtlb_hit_n = dtlb_lu_hit;
  lsu_is_store_n = lsu_is_store_i;
  dtlb_is_page_n = dtlb_is_page;
  lsu_valid_o = lsu_req_q;
  lsu_exception_o = misaligned_ex_q;
  pmp_access_type = lsu_is_store_q ? riscv::ACCESS_WRITE : riscv::ACCESS_READ;

  // mute misaligned exceptions if there is no request otherwise they will throw accidental exceptions
  misaligned_ex_n.valid = misaligned_ex_i.valid & lsu_req_i;

  // Check if the User flag is set, then we may only access it in supervisor mode
  // if SUM is enabled
  daccess_err = en_ld_st_translation_i && ((ld_st_priv_lvl_i == riscv::PRIV_LVL_S && !sum_i && dtlb_pte_q.u) || // SUM is not set and we are trying to access a user page in supervisor mode
  (ld_st_priv_lvl_i == riscv::PRIV_LVL_U && !dtlb_pte_q.u));            // this is not a user page but we are in user mode and trying to access it
  // translation is enabled and no misaligned exception occurred
  if (en_ld_st_translation_i && !misaligned_ex_q.valid) begin
    lsu_valid_o = 1'b0;

    // ---------
    // DTLB Hit
    // --------
    if (dtlb_hit_q && lsu_req_q) begin
      lsu_valid_o = 1'b1;
      // exception priority:
      // PAGE_FAULTS have higher priority than ACCESS_FAULTS
      // virtual memory based exceptions are PAGE_FAULTS
      // physical memory based exceptions are ACCESS_FAULTS (PMA/PMP)

      // this is a store
      if (lsu_is_store_q) begin
        // check if the page is write-able and we are not violating privileges
        // also check if the dirty flag is set
        if (!dtlb_pte_q.w || daccess_err || !dtlb_pte_q.d) begin
          lsu_exception_o = {
            riscv::STORE_PAGE_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, lsu_vaddr_q},
            1'b1
          };
          // Check if any PMPs are violated
        end else if (!pmp_data_allow) begin
          lsu_exception_o = {
            riscv::ST_ACCESS_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, lsu_vaddr_q},
            1'b1
          };
        else
          icache_areq_o.fetch_exception = {
            riscv::INSTR_ACCESS_FAULT, ptw_bad_paddr[riscv::PLEN-1:(riscv::PLEN > riscv::VLEN) ? (riscv::PLEN - riscv::VLEN) : 0], 1'b1
          };
      end
    end
    // if it didn't match any execute region throw an `Instruction Access Fault`
    // or: if we are not translating, check PMPs immediately on the paddr
    if (!match_any_execute_region || (!enable_translation_i && !pmp_instr_allow)) begin
      icache_areq_o.fetch_exception = {
        riscv::INSTR_ACCESS_FAULT, riscv::VLEN'(icache_areq_o.fetch_paddr[riscv::PLEN-1:(riscv::PLEN > riscv::VLEN) ? (riscv::PLEN - riscv::VLEN) : 0]), 1'b1
      };  //to check on wave --> not connected
    end
  end

  // check for execute flag on memory
  assign match_any_execute_region = config_pkg::is_inside_execute_regions(
      CVA6Cfg, {{64 - riscv::PLEN{1'b0}}, icache_areq_o.fetch_paddr}
  );

  // Instruction fetch
  pmp #(
      .PLEN      (riscv::PLEN),
      .PMP_LEN   (riscv::PLEN - 2),
      .NR_ENTRIES(CVA6Cfg.NrPMPEntries)
  ) i_pmp_if (
      .addr_i       (icache_areq_o.fetch_paddr),
      .priv_lvl_i,
      // we will always execute on the instruction fetch port
      .access_type_i(riscv::ACCESS_EXEC),
      // Configuration
      .conf_addr_i  (pmpaddr_i),
      .conf_i       (pmpcfg_i),
      .allow_o      (pmp_instr_allow)
  );

  //-----------------------
  // Data Interface
  //-----------------------
  logic [riscv::VLEN-1:0] lsu_vaddr_n, lsu_vaddr_q;
  riscv::pte_cva6_t dtlb_pte_n, dtlb_pte_q;
  exception_t misaligned_ex_n, misaligned_ex_q;
  logic lsu_req_n, lsu_req_q;
  logic lsu_is_store_n, lsu_is_store_q;
  logic dtlb_hit_n, dtlb_hit_q;
  logic [PT_LEVELS-2:0] dtlb_is_page_n, dtlb_is_page_q;

  // check if we need to do translation or if we are always ready (e.g.: we are not translating anything)
  assign lsu_dtlb_hit_o = (en_ld_st_translation_i) ? dtlb_lu_hit : 1'b1;

  // Wires to PMP checks
  riscv::pmp_access_t pmp_access_type;
  logic               pmp_data_allow;

  assign lsu_paddr_o    [11:0] = lsu_vaddr_q[11:0];
  assign lsu_paddr_o [riscv::PLEN-1:PPNWMin+1]   = 
                              (en_ld_st_translation_i && !misaligned_ex_q.valid) ? //
                              dtlb_pte_q.ppn[riscv::PPNW-1:(riscv::PPNW - (riscv::PLEN - PPNWMin-1))] : // 
                              riscv::PLEN'(lsu_vaddr_q[((riscv::PLEN > riscv::VLEN) ? riscv::VLEN : riscv::PLEN )-1:PPNWMin+1]);
                              


  genvar i;
    generate
      
        for (i=0; i < PT_LEVELS-1; i++) begin  
         assign lsu_paddr_o   [12+((VPN_LEN/PT_LEVELS)*(i+1))-1:12+((VPN_LEN/PT_LEVELS)*(i))] = //
                              (en_ld_st_translation_i && !misaligned_ex_q.valid && (|dtlb_is_page_q[PT_LEVELS-2:i]==0)) ? //
                              dtlb_pte_q.ppn  [((VPN_LEN/PT_LEVELS)*(i+1))-1:((VPN_LEN/PT_LEVELS)*(i))] : //
                              lsu_vaddr_q[12+((VPN_LEN/PT_LEVELS)*(i+1))-1:12+((VPN_LEN/PT_LEVELS)*(i))];

         assign lsu_dtlb_ppn_o[12+((VPN_LEN/PT_LEVELS)*(i+1))-1:12+((VPN_LEN/PT_LEVELS)*(i))] = //
                              (en_ld_st_translation_i && !misaligned_ex_q.valid && (|dtlb_is_page_q[PT_LEVELS-2:i]==0)) ? //
                              dtlb_content.ppn[((VPN_LEN/PT_LEVELS)*(i+1))-1:((VPN_LEN/PT_LEVELS)*(i))] : //
                              lsu_vaddr_n[12+((VPN_LEN/PT_LEVELS)*(i+1))-1:12+((VPN_LEN/PT_LEVELS)*(i))];
        end
        if(riscv::IS_XLEN64) begin
          assign lsu_dtlb_ppn_o[riscv::PPNW-1:PPNWMin+1] = (en_ld_st_translation_i && !misaligned_ex_q.valid) ? 
                              dtlb_content.ppn[riscv::PPNW-1:PPNWMin+1] : 
                              lsu_vaddr_n[riscv::PPNW-1:PPNWMin+1] ;
        end

        // this is a load
      end else begin
        // check for sufficient access privileges - throw a page fault if necessary
        if (daccess_err) begin
          lsu_exception_o = {
            riscv::LOAD_PAGE_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, lsu_vaddr_q},
            1'b1
          };
          // Check if any PMPs are violated
        end else if (!pmp_data_allow) begin
          lsu_exception_o = {
            riscv::LD_ACCESS_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, lsu_vaddr_q},
            1'b1
          };
        end
      end
    end else

    // ---------
    // DTLB Miss
    // ---------
    // watch out for exceptions
    if (ptw_active && !walking_instr) begin
      // page table walker threw an exception
      if (ptw_error) begin
        // an error makes the translation valid
        lsu_valid_o = 1'b1;
        // the page table walker can only throw page faults
        if (lsu_is_store_q) begin
          lsu_exception_o = {
            riscv::STORE_PAGE_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, update_vaddr},
            1'b1
          };
        end else begin
          lsu_exception_o = {
            riscv::LOAD_PAGE_FAULT,
            {{riscv::XLEN - riscv::VLEN{lsu_vaddr_q[riscv::VLEN-1]}}, update_vaddr},
            1'b1
          };
        end
      end

      if (ptw_access_exception) begin
        // an error makes the translation valid
        lsu_valid_o = 1'b1;
        // Any fault of the page table walk should be based of the original access type
        if (lsu_is_store_q) begin
          lsu_exception_o = {
            riscv::ST_ACCESS_FAULT, {{riscv::XLEN - riscv::VLEN{1'b0}}, lsu_vaddr_n}, 1'b1
          };
        end else begin
          lsu_exception_o = {
            riscv::LD_ACCESS_FAULT, {{riscv::XLEN - riscv::VLEN{1'b0}}, lsu_vaddr_n}, 1'b1
          };
        end
      end
    end
  end  // If translation is not enabled, check the paddr immediately against PMPs
  else if (lsu_req_q && !misaligned_ex_q.valid && !pmp_data_allow) begin
    if (lsu_is_store_q) begin
      lsu_exception_o = {
        riscv::ST_ACCESS_FAULT, {{riscv::XLEN - riscv::PLEN{1'b0}}, lsu_paddr_o}, 1'b1
      };
    end else begin
      lsu_exception_o = {
        riscv::LD_ACCESS_FAULT, {{riscv::XLEN - riscv::PLEN{1'b0}}, lsu_paddr_o}, 1'b1
      };
    end
  end
end

// Load/store PMP check
pmp #(
    .CVA6Cfg   (CVA6Cfg),
    .PLEN      (riscv::PLEN),
    .PMP_LEN   (riscv::PLEN - 2),
    .NR_ENTRIES(CVA6Cfg.NrPMPEntries)
) i_pmp_data (
    .addr_i       (lsu_paddr_o),
    .priv_lvl_i   (ld_st_priv_lvl_i),
    .access_type_i(pmp_access_type),
    // Configuration
    .conf_addr_i  (pmpaddr_i),
    .conf_i       (pmpcfg_i),
    .allow_o      (pmp_data_allow)
);

// ----------
// Registers
// ----------
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin
    lsu_vaddr_q     <= '0;
    lsu_req_q       <= '0;
    misaligned_ex_q <= '0;
    dtlb_pte_q      <= '0;
    dtlb_hit_q      <= '0;
    lsu_is_store_q  <= '0;
    dtlb_is_page_q  <= '0;
  end else begin
    lsu_vaddr_q     <= lsu_vaddr_n;
    lsu_req_q       <= lsu_req_n;
    misaligned_ex_q <= misaligned_ex_n;
    dtlb_pte_q      <= dtlb_pte_n;
    dtlb_hit_q      <= dtlb_hit_n;
    lsu_is_store_q  <= lsu_is_store_n;
    dtlb_is_page_q  <= dtlb_is_page_n;
  end
end
endmodule