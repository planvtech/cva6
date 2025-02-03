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
// Description: Ariane Top-level module

`ifdef DROMAJO
import "DPI-C" function void dromajo_trap(int     hart_id,
                                          longint cause);
import "DPI-C" function void dromajo_step(int     hart_id,
                                          longint pc,
                                          int     insn,
                                          longint wdata, longint cycle);
import "DPI-C" function void init_dromajo(string cfg_f_name);
`endif


module ariane import ariane_pkg::*; #(
  parameter ariane_pkg::ariane_cfg_t ArianeCfg     = ariane_pkg::ArianeDefaultConfig
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,
  // Core ID, Cluster ID and boot address are considered more or less static
  input  logic [63:0]                  boot_addr_i,  // reset boot address
  input  logic [63:0]                  hart_id_i,    // hart id in a multicore environment (reflected in a CSR)

  // Interrupt inputs
  input  logic [1:0]                   irq_i,        // level sensitive IR lines, mip & sip (async)
  input  logic                         ipi_i,        // inter-processor interrupts (async)
  // Timer facilities
  input  logic                         time_irq_i,   // timer interrupt in (async)
  input  logic [63:0]                  time_i,       // copy of the system mtime
  input  logic                         debug_req_i,  // debug request (async)
`ifdef FIRESIM_TRACE
  // firesim trace port
  output traced_instr_pkg::trace_port_t trace_o,
`endif
`ifdef PITON_ARIANE
  // L15 (memory side)
  output wt_cache_pkg::l15_req_t       l15_req_o,
  input  wt_cache_pkg::l15_rtrn_t      l15_rtrn_i
`else
  // memory side, AXI Master
  output ariane_axi::req_t             axi_req_o,
  input  ariane_axi::resp_t            axi_resp_i
`endif
);

  // ------------------------------------------
  // Global Signals
  // Signals connecting more than one module
  // ------------------------------------------
  riscv::priv_lvl_t           priv_lvl;
  exception_t                 ex_commit; // exception from commit stage
  bp_resolve_t                resolved_branch_ex_several;
  bp_resolve_t                resolved_branch_ctrl_frontend;
  
  logic [riscv::VLEN-1:0]     pc_commit_ctrl;
  logic [riscv::VLEN-1:0]     pc_ctrl_frontend;
  
  logic                       eret;
  logic [NR_COMMIT_PORTS-1:0] commit_ack;

  // --------------
  // PCGEN <-> CSR
  // --------------
  logic [riscv::VLEN-1:0]     trap_vector_base_commit_pcgen;
  logic [riscv::VLEN-1:0]     epc_commit_ctrl;
  logic [riscv::VLEN-1:0]     epc_ctrl_pcgen;
  // --------------
  // IF <-> ID
  // --------------
  fetch_entry_t             fetch_entry_if_id;
  logic                     fetch_valid_if_id;
  logic                     fetch_ready_id_if;

  // --------------
  // ID <-> ISSUE
  // --------------
  id_entry_t                issue_entry_id_issue;
  logic                     issue_entry_valid_id_issue;
  logic                     is_ctrl_fow_id_issue;
  logic                     issue_instr_issue_id;

  // --------------
  // ISSUE <-> EX
  // --------------

  fu_data_t                 fu_data_id_ex;
  logic [riscv::VLEN-1:0]   pc_id_ex;
  logic                     is_compressed_instr_id_ex;
  
  
  // MULT
  logic mult_ready_ex_id;
  logic mult_valid_id_ex;
  logic [63:0] mult_result_ex_id;
  logic [TRANS_ID_BITS-1:0] mult_trans_id_ex_id;
  logic  mult_valid_ex_id;
  exception_t mult_exception_ex_id;
 
  // fixed latency units
  logic                     flu_ready_ex_id;
  logic [TRANS_ID_BITS-1:0] flu_trans_id_ex_id;
  logic                     flu_valid_ex_id;
  riscv::xlen_t             flu_result_ex_id;
  exception_t               flu_exception_ex_id;
  // ALU
  logic                     alu_valid_id_ex;
  // Branches and Jumps
  logic                     branch_valid_id_ex;

  branchpredict_entry_t       branch_predict_id_ex;
  // LSU
  logic                     lsu_valid_id_ex;
  logic                     lsu_ready_ex_id;

  logic [TRANS_ID_BITS-1:0] load_trans_id_ex_id;
  riscv::xlen_t             load_result_ex_id;
  logic                     load_valid_ex_id;
  exception_t               load_exception_ex_id;

  riscv::xlen_t             store_result_ex_id;
  logic [TRANS_ID_BITS-1:0] store_trans_id_ex_id;
  logic                     store_valid_ex_id;
  exception_t               store_exception_ex_id;
  // FPU
  logic                     fpu_ready_ex_id;
  logic                     fpu_valid_id_ex;
  logic [1:0]               fpu_fmt_id_ex;
  logic [2:0]               fpu_rm_id_ex;
  logic [TRANS_ID_BITS-1:0] fpu_trans_id_ex_id;
  riscv::xlen_t             fpu_result_ex_id;
  logic                     fpu_valid_ex_id;
  
  exception_t               fpu_exception_ex_id;
  // CSR
  logic                     csr_valid_id_ex;
  // --------------
  // EX <-> COMMIT
  // --------------
  // CSR Commit
  logic                     csr_commit_commit_ex;
  logic                     dirty_fp_state;
  // LSU Commit
  logic                     lsu_commit_commit_ex;
  logic                     lsu_commit_ready_ex_commit;
  logic [TRANS_ID_BITS-1:0] lsu_commit_trans_id;
  logic                     no_st_pending_ex;
  logic                     no_st_pending_commit;
  logic                     amo_valid_commit;
  // --------------
  // ROB <-> COMMIT
  // --------------
  re_order_buffer_entry_t [NR_COMMIT_PORTS-1:0] commit_instr_rob_commit;
  logic [NR_COMMIT_PORTS-1:0] [TRANS_ID_BITS-1:0] commit_instr_trid_rob_commit; 
  // --------------
  // COMMIT <-> ID
  // --------------
  logic [NR_COMMIT_PORTS-1:0][4:0]  waddr_commit_id;
  logic [NR_COMMIT_PORTS-1:0][riscv::XLEN-1:0] wdata_commit_id;
  logic [NR_COMMIT_PORTS-1:0]       we_gpr_commit_id;
  logic [NR_COMMIT_PORTS-1:0]       we_fpr_commit_id;
  // --------------
  // CSR <-> *
  // --------------
  logic [4:0]               fflags_csr_commit;
  riscv::xs_t               fs;
  logic [2:0]               frm_csr_id_issue_ex;
  logic [6:0]               fprec_csr_ex;
  logic                     enable_translation_csr_ex;
  logic                     en_ld_st_translation_csr_ex;
  riscv::priv_lvl_t         ld_st_priv_lvl_csr_ex;
  logic                     sum_csr_ex;
  logic                     mxr_csr_ex;
  logic [riscv::PPNW-1:0]   satp_ppn_csr_ex;
  logic [ASID_WIDTH-1:0]    asid_csr_ex;
  logic [11:0]              csr_addr_ex_csr;
  fu_op                     csr_op_commit_csr;
  riscv::xlen_t             csr_wdata_commit_csr;
  riscv::xlen_t             csr_rdata_csr_commit;
  exception_t               csr_exception_csr_commit;
  logic                     tvm_csr_id;
  logic                     tw_csr_id;
  logic                     tsr_csr_id;
  irq_ctrl_t                irq_ctrl_csr_id;
  logic                     dcache_en_csr_nbdcache;
  logic                     csr_write_fflags_commit_cs;
  logic                     icache_en_csr;
  logic                     debug_mode_csr_toseveral;
  logic                     single_step_csr_commit;
  riscv::pmpcfg_t [15:0]    pmpcfg;
  logic [15:0][riscv::PLEN-3:0] pmpaddr;
  // ----------------------------
  // Performance Counters <-> *
  // ----------------------------
  logic [4:0]               addr_csr_perf;
  riscv::xlen_t             data_csr_perf, data_perf_csr;
  logic                     we_csr_perf;

  logic                     icache_flush_ctrl_cache;
  logic                     itlb_miss_ex_perf;
  logic                     dtlb_miss_ex_perf;
  logic                     dcache_miss_cache_perf;
  logic                     icache_miss_cache_perf;
  // --------------
  // CTRL <-> *
  // --------------
  logic                     set_pc_ctrl_frontend;
  logic                     set_debug_pc_ctrl_frontend;
  logic                     flush_csr_ctrl;
  logic                     flush_misbranch_instr_ctrl_several;
  logic                     flush_ctrl_if;
  logic                     flush_ctrl_id;
  logic                     flush_ctrl_issue; 
  logic                     flush_ctrl_re_order_buffer; 
  logic                     flush_ctrl_ex;
  logic                     flush_ctrl_bp;
  logic                     flush_tlb_ctrl_ex;
  logic                     fence_i_commit_ctrl;
  logic                     fence_commit_ctrl;
  logic                     sfence_vma_commit_ctrl;
  logic                     fence_t_commit_ctrl;
  logic                     halt_ctrl;
  logic                     dcache_flush_ctrl_cache;
  logic                     caches_flush_ack_cache_ctrl;
  logic                     set_debug_pc_csr_ctrl;
  logic                     flush_commit;
  logic                     flush_tlb_all; 

  icache_areq_i_t           icache_areq_ex_cache;
  icache_areq_o_t           icache_areq_cache_ex;
  icache_dreq_i_t           icache_dreq_if_cache;
  icache_dreq_o_t           icache_dreq_cache_if;

  amo_req_t                 amo_req;
  amo_resp_t                amo_resp;
  logic                     ics_full;



  logic [ariane_pkg::TRANS_ID_BITS-1:0] id_issue_rs1_transID_reference;
  logic [ariane_pkg::TRANS_ID_BITS-1:0] id_issue_rs2_transID_reference;

  logic [ariane_pkg::NR_ROB_ENTRIES-1:0]  rob_ics_flush_ics_transID_structure; // change with generics params
  logic [ariane_pkg::NR_ROB_ENTRIES-1:0]  rob_ics_flush_ics_transID_structure_q; // change with generics params
  
  logic ics_rob_sample; 
  logic [riscv::VLEN-1:0]                                 issued_instr_pc_q;            // PC of instruction
  fu_t                                                    issued_instr_fu_q;            // functional unit to use
  fu_op                                                   issued_instr_op_q;            // operation to perform in each functional unit
  logic [REG_ADDR_SIZE-1:0]                               issued_instr_rd_q;            // register destination address
  logic [ariane_pkg::TRANS_ID_BITS-1:0]                   issued_instr_trans_id_q;      // trans id of the instruction (position in the rob)
  logic issue_instr_iscompressed_q;
  exception_t issue_instr_exception_q; 

`ifndef SYNTHESIS
  riscv::xlen_t                                           rs1_operand_q;     // needed to easy instr_trace information, TODO: must be trimmed in syntesys 
  riscv::xlen_t                                           rs2_operand_q;     // needed to easy instr_trace information, TODO: must be trimmed in syntesys 
  riscv::xlen_t                                           rs1_operand_n;     // needed to easy instr_trace information, TODO: must be trimmed in syntesys 
  riscv::xlen_t                                           rs2_operand_n;     // needed to easy instr_trace information, TODO: must be trimmed in syntesys 
`endif
  

  logic ics_rob_sample_q; 
  
  // ----------------
  // DCache <-> *
  // ----------------
  dcache_req_i_t [2:0]      dcache_req_ports_ex_cache;
  dcache_req_o_t [2:0]      dcache_req_ports_cache_ex;
  logic                     dcache_commit_wbuffer_empty;
  logic ex_valid_ctrl_if; 
  logic eret_ctrl_if;
  logic wfi_csr_ctrl_set;
  logic wfi_csr_ctrl_reset;
  logic                     dcache_commit_wbuffer_not_ni;
  logic caches_and_internal_states_flush_ctrl_cache; 
  

  // --------------
  // Frontend
  // --------------
  frontend #(
    .ArianeCfg ( ArianeCfg )
  ) i_frontend (
    .clk_i, 
    .rst_ni,
    .flush_i             ( flush_ctrl_if                 ), //C1 --> from ctrl, registered
    .flush_bp_i          ( flush_ctrl_bp                 ), //C1 --> from ctrl, registered
    .debug_mode_i        ( debug_mode_csr_toseveral      ), //From CSR regfile registered since coming from 
    .boot_addr_i         ( boot_addr_i                   ), //From outside world 
    .icache_dreq_i       ( icache_dreq_cache_if          ), //From ICACHE
    .icache_dreq_o       ( icache_dreq_if_cache          ), //TO ICACHE
    .resolved_branch_i   ( resolved_branch_ctrl_frontend             ), // FROM commit stage, registered in ad hoc top level register
    .pc_ctrl_i           ( pc_ctrl_frontend              ), // FROM ctrl
    .set_pc_ctrl_i       ( set_pc_ctrl_frontend          ), //C1 --> from ctrl, registered 
    .set_debug_pc_i      ( set_debug_pc_ctrl_frontend    ), //C0 from CSR regfile, combinatorial 
    .epc_i               ( epc_ctrl_pcgen                ), // coming from ctrl, value from registers but activate combinatorial... review
    .eret_i              ( eret_ctrl_if                  ), // c1 coming from ctrl, going to ctrl to to trigger ERET activity 
    .trap_vector_base_i  ( trap_vector_base_commit_pcgen ),
    .ex_valid_i          ( ex_valid_ctrl_if  ), 
    .fetch_entry_o       ( fetch_entry_if_id             ),
    .fetch_entry_valid_o ( fetch_valid_if_id             ),
    .fetch_entry_ready_i ( fetch_ready_id_if             )
  );



  // ---------
  // ID
  // ---------
  id_stage id_stage_i (
    .clk_i,
    .rst_ni,
    .flush_i                    ( flush_ctrl_id ), //resets the next instr to be issued (already decoded)
    .flush_issue_i              ( flush_ctrl_issue ), //this resets the transid counter
    .flush_misbranch_instr_i  ( flush_misbranch_instr_ctrl_several ), 
    .debug_req_i,
    .fetch_entry_i              ( fetch_entry_if_id          ),
    .fetch_entry_valid_i        ( fetch_valid_if_id          ),
    .fetch_entry_ready_o        ( fetch_ready_id_if          ),
    .branch_trans_id            ( resolved_branch_ctrl_frontend.trans_id ), 
    .issue_entry_o              ( issue_entry_id_issue       ),
    .issue_entry_valid_o        ( issue_entry_valid_id_issue ),
    .is_ctrl_flow_o             ( is_ctrl_fow_id_issue       ),
    .issue_instr_ack_i          ( issue_instr_issue_id       ),
    .rs1_transID_reference_o    ( id_issue_rs1_transID_reference ), 
    .rs2_transID_reference_o    ( id_issue_rs2_transID_reference ),
    .priv_lvl_i                 ( priv_lvl                   ),
    .fs_i                       ( fs                         ),
    .frm_i                      ( frm_csr_id_issue_ex        ),
    .irq_i                      ( irq_i                      ),
    .irq_ctrl_i                 ( irq_ctrl_csr_id            ),
    .debug_mode_i               ( debug_mode_csr_toseveral   ),
    .tvm_i                      ( tvm_csr_id                 ),
    .tw_i                       ( tw_csr_id                  ),
    .tsr_i                      ( tsr_csr_id                 )
  );

  // ---------
  // Issue
  // ---------
  issue_control_structure #(
    .NR_WB_PORTS                ( NR_WB_PORTS_TO_ICS           ),
    .NR_COMMIT_PORTS            ( NR_COMMIT_PORTS              )
  ) issue_stage_i (
    .clk_i,
    .rst_ni,
    .ics_full_o                 ( ics_full                    ),
    .flush_misbranch_instr_i  ( flush_misbranch_instr_ctrl_several ),
    .flush_i                    ( flush_ctrl_issue             ),
    // ID Stage
    .decoded_instr_i            ( issue_entry_id_issue         ),
    .decoded_instr_valid_i      ( issue_entry_valid_id_issue   ),
    .decoded_instr_ack_o        ( issue_instr_issue_id         ),
    
`ifndef SYNTHESIS
    // 
    .rs1_operand_o (rs1_operand_n), 
    .rs2_operand_o (rs2_operand_n),
`endif
  
    // Functional Units
	  .fu_data_o                  ( fu_data_id_ex                ),
    .pc_o                       ( pc_id_ex                     ),
    .is_compressed_instr_o      ( is_compressed_instr_id_ex    ),
    // fixed latency unit ready
    .flu_ready_i                ( flu_ready_ex_id              ),
    // ALU
    .alu_valid_o                ( alu_valid_id_ex              ),
    .mult_ready_i               ( mult_ready_ex_id), 
    // Branches and Jumps
    .branch_valid_o             ( branch_valid_id_ex           ), // branch is valid
    .branch_predict_o           ( branch_predict_id_ex         ), // branch predict to ex
    // LSU
    .lsu_ready_i                ( lsu_ready_ex_id              ),
    .lsu_valid_o                ( lsu_valid_id_ex              ),
    // Multiplier
    .mult_valid_o               ( mult_valid_id_ex             ),
    // FPU
    .fpu_ready_i                ( fpu_ready_ex_id              ),
    .fpu_valid_o                ( fpu_valid_id_ex              ),
    .fpu_fmt_o                  ( fpu_fmt_id_ex                ),
    .fpu_rm_o                   ( fpu_rm_id_ex                 ),
    // CSR
    .csr_valid_o                ( csr_valid_id_ex              ),
    // Commit
    .trans_id_i                 ({flu_trans_id_ex_id, load_trans_id_ex_id, mult_trans_id_ex_id }), // only ports that can carry data
    .wbdata_i                   ({flu_result_ex_id, load_result_ex_id, mult_result_ex_id}),
    .wt_valid_i                 ({flu_valid_ex_id, load_valid_ex_id, mult_valid_ex_id}),
    .waddr_i                    ( waddr_commit_id              ),
    .wdata_i                    ( wdata_commit_id              ),
    .we_gpr_i                   ( we_gpr_commit_id             ),
    .rs1_transID_reference_i (id_issue_rs1_transID_reference), 
    .rs2_transID_reference_i (id_issue_rs2_transID_reference),
    .rob_sample_feedback_i(ics_rob_sample_q),
    .rob_transID_feedback_i(issued_instr_trans_id_q),
    .rob_sample_o (ics_rob_sample), // the rob sample an instruction when this signal is high  
    .flush_ics_transID_structure_i (rob_ics_flush_ics_transID_structure_q) // and review if we can simplify
     );


  always_ff @ (posedge clk_i) // Registers to separate timings
  begin 
    //Registers between ICS and ROB. the ROB entry is populated one clock cycle after the ICS issue. 
    //As consequence, the Instruction result will come in the same moment if coming from the Fixed Latency Unit (FLU)
    ics_rob_sample_q <= ics_rob_sample;
    issued_instr_pc_q <= issue_entry_id_issue.pc;             // PC of instruction
    issued_instr_fu_q <= issue_entry_id_issue.fu;             // functional unit to use
    issued_instr_op_q <= issue_entry_id_issue.op;             // operation to perform in each functional unit
    issued_instr_rd_q <= issue_entry_id_issue.rd;             // register destination address
    issued_instr_trans_id_q <= issue_entry_id_issue.trans_id; // trans id of the instruction (position in the 
    issue_instr_exception_q <= issue_entry_id_issue.ex; 
    issue_instr_iscompressed_q <= issue_entry_id_issue.is_compressed;

`ifndef SYNTHESIS
    rs1_operand_q <= rs1_operand_n; 
    rs2_operand_q <= rs2_operand_n; 
`endif

    
  end

  always_ff @ (posedge clk_i) // Registers to separate timings
  begin 
    //FROM ROB TO ICS 
    if (flush_ctrl_issue)   // TODO: check if we can get rid of this
      rob_ics_flush_ics_transID_structure_q <= '0; 
    else
      rob_ics_flush_ics_transID_structure_q <= rob_ics_flush_ics_transID_structure; 
  end  
  

  
  // ---------
  // EX
  // ---------
  ex_stage #(
    .ASID_WIDTH ( ASID_WIDTH ),
    .ArianeCfg ( ArianeCfg )
  ) ex_stage_i (
    .clk_i,
    .rst_ni,
    .debug_mode_i           ( debug_mode_csr_toseveral                  ),
    .flush_i                ( flush_ctrl_ex               ),
    .flush_misbranch_instr_i     ( flush_misbranch_instr_ctrl_several ), 
	  .flush_tlb_all_i (flush_tlb_all), 
	  .fu_data_i              ( fu_data_id_ex               ),
    .pc_i                   ( pc_id_ex                    ),
    .is_compressed_instr_i  ( is_compressed_instr_id_ex   ),
    // MULT
    .mult_ready_o            ( mult_ready_ex_id),
    .mult_valid_i            ( mult_valid_id_ex            ),
    .mult_result_o           ( mult_result_ex_id            ),
    .mult_trans_id_o         ( mult_trans_id_ex_id          ),
    .mult_valid_o            ( mult_valid_ex_id             ),
    .mult_exception_o        ( mult_exception_ex_id         ),
    // fixed latency units
    .flu_result_o           ( flu_result_ex_id            ),
    .flu_trans_id_o         ( flu_trans_id_ex_id          ),
    .flu_valid_o            ( flu_valid_ex_id             ),
    .flu_exception_o        ( flu_exception_ex_id         ),
    .flu_ready_o            ( flu_ready_ex_id             ),
    // ALU
    .alu_valid_i            ( alu_valid_id_ex             ),
    // Branches and Jumps
    .branch_valid_i         ( branch_valid_id_ex          ),
    .branch_predict_i       ( branch_predict_id_ex        ), // branch predict to ex
    .resolved_branch_o      ( resolved_branch_ex_several  ),
    // CSR
    .csr_valid_i            ( csr_valid_id_ex             ),
    .csr_addr_o             ( csr_addr_ex_csr             ),
    .csr_commit_i           ( csr_commit_commit_ex        ), // from commit
    // LSU
    .lsu_ready_o            ( lsu_ready_ex_id             ),
    .lsu_valid_i            ( lsu_valid_id_ex             ),
    .load_result_o          ( load_result_ex_id           ),
    .load_trans_id_o        ( load_trans_id_ex_id         ),
    .load_valid_o           ( load_valid_ex_id            ),
    .load_exception_o       ( load_exception_ex_id        ),
    .store_result_o         ( store_result_ex_id          ),
    .store_trans_id_o       ( store_trans_id_ex_id        ),
    .store_valid_o          ( store_valid_ex_id           ),
    .store_exception_o      ( store_exception_ex_id       ),
    .lsu_commit_i           ( lsu_commit_commit_ex        ), // from commit
    .lsu_commit_ready_o     ( lsu_commit_ready_ex_commit  ), // to commit
    .commit_tran_id_i       ( lsu_commit_trans_id         ), // from commit
    .no_st_pending_o        ( no_st_pending_ex            ),
    // FPU
    .fpu_ready_o            ( fpu_ready_ex_id             ),
    .fpu_valid_i            ( fpu_valid_id_ex             ),
    .fpu_fmt_i              ( fpu_fmt_id_ex               ),
    .fpu_rm_i               ( fpu_rm_id_ex                ),
    .fpu_frm_i              ( frm_csr_id_issue_ex         ),
    .fpu_prec_i             ( fprec_csr_ex                ),
    .fpu_trans_id_o         ( fpu_trans_id_ex_id          ),
    .fpu_result_o           ( fpu_result_ex_id            ),
    .fpu_valid_o            ( fpu_valid_ex_id             ),
    .fpu_exception_o        ( fpu_exception_ex_id         ),
    .amo_valid_commit_i     ( amo_valid_commit            ),
    .amo_req_o              ( amo_req                     ),
    .amo_resp_i             ( amo_resp                    ),
    // Performance counters
    .itlb_miss_o            ( itlb_miss_ex_perf           ),
    .dtlb_miss_o            ( dtlb_miss_ex_perf           ),
    // Memory Management
    .enable_translation_i   ( enable_translation_csr_ex   ), // from CSR
    .en_ld_st_translation_i ( en_ld_st_translation_csr_ex ),
    .flush_tlb_i            ( flush_tlb_ctrl_ex           ),
    .priv_lvl_i             ( priv_lvl                    ), // from CSR
    .ld_st_priv_lvl_i       ( ld_st_priv_lvl_csr_ex       ), // from CSR
    .sum_i                  ( sum_csr_ex                  ), // from CSR
    .mxr_i                  ( mxr_csr_ex                  ), // from CSR
    .satp_ppn_i             ( satp_ppn_csr_ex             ), // from CSR
    .asid_i                 ( asid_csr_ex                 ), // from CSR
    .icache_areq_i          ( icache_areq_cache_ex        ),
    .icache_areq_o          ( icache_areq_ex_cache        ),
    // DCACHE interfaces
    .dcache_req_ports_i     ( dcache_req_ports_cache_ex   ),
    .dcache_req_ports_o     ( dcache_req_ports_ex_cache   ),
    .dcache_wbuffer_empty_i ( dcache_commit_wbuffer_empty ),
    .dcache_wbuffer_not_ni_i ( dcache_commit_wbuffer_not_ni ),
    // PMP
    .pmpcfg_i               ( pmpcfg                      ),
    .pmpaddr_i              ( pmpaddr                     )
  );

  // Re-order buffer declared as separate entity 
  re_order_buffer #(
    .NR_WB_PORTS (NR_WB_PORTS_TO_ROB),
    .NR_COMMIT_PORTS (NR_COMMIT_PORTS)
  ) re_order_buffer_i (

  .clk_i,    // Clock
  .rst_ni,   // Asynchronous reset active low
  .flush_i (flush_ctrl_re_order_buffer),  // flush whole re-order_buffer
  .flush_misbranch_instr_i(flush_misbranch_instr_ctrl_several),
  .issued_instr_valid_i (ics_rob_sample_q), // the rob sample an instruction when this signal is high  
  .issued_instr_pc_i(issued_instr_pc_q),            // PC of instruction
  .issued_instr_fu_i(issued_instr_fu_q),            // functional unit to use
  .issued_instr_op_i(issued_instr_op_q),            // operation to perform in each functional unit
  .issued_instr_rd_i(issued_instr_rd_q),            // register destination address
  .issued_instr_trans_id_i(issued_instr_trans_id_q),      // trans id of the instruction (position in the rob)
  .issue_instr_exception_i(issue_instr_exception_q),
  .issue_instr_iscompressed_i(issue_instr_iscompressed_q),

`ifndef SYNTHESIS
  .rs1_operand_i (rs1_operand_q),
  .rs2_operand_i (rs2_operand_q),
`endif
  
  .flush_ics_transID_structure_o (rob_ics_flush_ics_transID_structure), // and review if we can simplify
  .commit_trans_id_o (commit_instr_trid_rob_commit),
  .commit_instr_o (commit_instr_rob_commit),
  .commit_ack_i (commit_ack),
  // write-back port
  .trans_id_i                 ( {flu_trans_id_ex_id,  load_trans_id_ex_id,  store_trans_id_ex_id,   mult_trans_id_ex_id }), // FPU not supported at moment
  .wbdata_i                   ( {flu_result_ex_id,    load_result_ex_id,    store_result_ex_id,       mult_result_ex_id }),
  .ex_i                       ( {flu_exception_ex_id, load_exception_ex_id, store_exception_ex_id, mult_exception_ex_id }),
  .wt_valid_i                 ( {flu_valid_ex_id,     load_valid_ex_id,     store_valid_ex_id,         mult_valid_ex_id }), 
  .branch_target_address_i    ( resolved_branch_ex_several.target_address )
  );

  // ---------
  // Commit
  // ---------

  // we have to make sure that the whole write buffer path is empty before
  // used e.g. for fence instructions.
  assign no_st_pending_commit = no_st_pending_ex & dcache_commit_wbuffer_empty;

  commit_stage #(
    .NR_COMMIT_PORTS ( NR_COMMIT_PORTS )
  ) commit_stage_i (
    .clk_i, 
    .halt_i                 ( halt_ctrl                     ),
    .flush_dcache_i         ( dcache_flush_ctrl_cache       ),
    .exception_o            ( ex_commit                     ),
    .dirty_fp_state_o       ( dirty_fp_state                ),
    .single_step_i          ( single_step_csr_commit        ),
    .commit_instr_i         ( commit_instr_rob_commit        ),
    .commit_ack_o           ( commit_ack                    ),
    .no_st_pending_i        ( no_st_pending_commit          ),
    .waddr_o                ( waddr_commit_id               ),
    .wdata_o                ( wdata_commit_id               ),
    .we_gpr_o               ( we_gpr_commit_id              ),
    .we_fpr_o               ( we_fpr_commit_id              ),
    .commit_lsu_o           ( lsu_commit_commit_ex          ),
    .commit_lsu_ready_i     ( lsu_commit_ready_ex_commit    ),
    .commit_tran_id_o       ( lsu_commit_trans_id           ),
    .amo_valid_commit_o     ( amo_valid_commit              ),
    .amo_resp_i             ( amo_resp                      ),
    .commit_csr_o           ( csr_commit_commit_ex          ),
    .pc_o                   ( pc_commit_ctrl                     ),
    .csr_op_o               ( csr_op_commit_csr             ),
    .csr_wdata_o            ( csr_wdata_commit_csr          ),
    .csr_rdata_i            ( csr_rdata_csr_commit          ),
    .csr_write_fflags_o     ( csr_write_fflags_commit_cs    ),
    .csr_exception_i        ( csr_exception_csr_commit      ),
    .fence_i_o              ( fence_i_commit_ctrl     ),
    .fence_o                ( fence_commit_ctrl       ),
    .sfence_vma_o           ( sfence_vma_commit_ctrl  ),
    .fence_t_o              ( fence_t_commit_ctrl     ),
    .flush_commit_o         ( flush_commit                  ),
    .commit_instr_trid_rob_commit_i (commit_instr_trid_rob_commit)
  );

  // ---------
  // CSR
  // ---------
  csr_regfile #(
    .AsidWidth              ( ASID_WIDTH                    ),
    .DmBaseAddress          ( ArianeCfg.DmBaseAddress       ),
    .NrCommitPorts          ( NR_COMMIT_PORTS               ),
    .NrPMPEntries           ( ArianeCfg.NrPMPEntries        )
  ) csr_regfile_i (
    .clk_i, 
    .rst_ni, 
    .debug_req_i,
    .ipi_i,
    .irq_i,
    .time_irq_i,
    .time_i,
    .flush_o                ( flush_csr_ctrl                ),
    .commit_instr_i         ( commit_instr_rob_commit        ),
    .commit_ack_i           ( commit_ack                    ),
    .boot_addr_i            ( boot_addr_i[riscv::VLEN-1:0]  ),
    .hart_id_i              ( hart_id_i[riscv::XLEN-1:0]    ),
    .ex_i                   ( ex_commit                     ),
    .csr_op_i               ( csr_op_commit_csr             ),
    .csr_write_fflags_i     ( csr_write_fflags_commit_cs    ),
    .dirty_fp_state_i       ( dirty_fp_state                ),
    .csr_addr_i             ( csr_addr_ex_csr               ),
    .csr_wdata_i            ( csr_wdata_commit_csr          ),
    .csr_rdata_o            ( csr_rdata_csr_commit          ),
    .pc_i                   ( pc_commit_ctrl                     ),
    .csr_exception_o        ( csr_exception_csr_commit      ),
    .epc_o                  ( epc_commit_ctrl               ),
    .eret_o                 ( eret                          ),
    .set_debug_pc_o         ( set_debug_pc_csr_ctrl         ),
    .trap_vector_base_o     ( trap_vector_base_commit_pcgen ),
    .priv_lvl_o             ( priv_lvl                      ),
    .fs_o                   ( fs                            ),
    .fflags_o               ( fflags_csr_commit             ),
    .frm_o                  ( frm_csr_id_issue_ex           ),
    .fprec_o                ( fprec_csr_ex                  ),
    .irq_ctrl_o             ( irq_ctrl_csr_id               ),
    .ld_st_priv_lvl_o       ( ld_st_priv_lvl_csr_ex         ),
    .en_translation_o       ( enable_translation_csr_ex     ),
    .en_ld_st_translation_o ( en_ld_st_translation_csr_ex   ),
    .sum_o                  ( sum_csr_ex                    ),
    .mxr_o                  ( mxr_csr_ex                    ),
    .satp_ppn_o             ( satp_ppn_csr_ex               ),
    .asid_o                 ( asid_csr_ex                   ),
    .tvm_o                  ( tvm_csr_id                    ),
    .tw_o                   ( tw_csr_id                     ),
    .tsr_o                  ( tsr_csr_id                    ),
    .debug_mode_o           ( debug_mode_csr_toseveral                    ),
    .single_step_o          ( single_step_csr_commit        ),
    .dcache_en_o            ( dcache_en_csr_nbdcache        ),
    .icache_en_o            ( icache_en_csr                 ),
    .perf_addr_o            ( addr_csr_perf                 ),
    .perf_data_o            ( data_csr_perf                 ),
    .perf_data_i            ( data_perf_csr                 ),
    .perf_we_o              ( we_csr_perf                   ),
    .pmpcfg_o               ( pmpcfg                        ),
    .pmpaddr_o              ( pmpaddr                       ),
    .wfi_set_o     ( wfi_csr_ctrl_set ),
    .wfi_reset_o   ( wfi_csr_ctrl_reset )
  );

  // ------------------------
  // Performance Counters
  // ------------------------
  perf_counters i_perf_counters (
    .clk_i,
    .rst_ni,
    .debug_mode_i      ( debug_mode_csr_toseveral             ),
    .addr_i            ( addr_csr_perf          ),
    .we_i              ( we_csr_perf            ),
    .data_i            ( data_csr_perf          ),
    .data_o            ( data_perf_csr          ),
    .commit_instr_i    ( commit_instr_rob_commit ),
    .commit_ack_i      ( commit_ack             ),
    .l1_icache_miss_i  ( icache_miss_cache_perf ),
    .l1_dcache_miss_i  ( dcache_miss_cache_perf ),
    .itlb_miss_i       ( itlb_miss_ex_perf      ),
    .dtlb_miss_i       ( dtlb_miss_ex_perf      ),
    .sb_full_i         ( ics_full               ),
    .if_empty_i        ( ~fetch_valid_if_id     ),
    .ex_i              ( ex_valid_ctrl_if ),
    .eret_i            ( eret_ctrl_if           ),
    .misbranch_i       ( flush_misbranch_instr_ctrl_several )
  );
  // ------------
  // ctrl
  // ------------
  

  controller controller_i (
    // flush ports
    .clk_i,
    .rst_ni,    
    .flush_misbranch_instr_o ( flush_misbranch_instr_ctrl_several  ),
    .flush_if_o             ( flush_ctrl_if                 ),
    .flush_id_o             ( flush_ctrl_id                 ),
    .flush_issue_o          ( flush_ctrl_issue              ),
    .flush_ex_o             ( flush_ctrl_ex                 ),
    .flush_re_order_buffer_o( flush_ctrl_re_order_buffer    ),          
    .flush_bp_o             ( flush_ctrl_bp                 ),
    .flush_tlb_command_o    ( flush_tlb_ctrl_ex             ),
	  .flush_tlb_all_o        ( flush_tlb_all ),
    .flush_dcache_o         ( dcache_flush_ctrl_cache       ),
    .flush_icache_o         ( icache_flush_ctrl_cache       ),
    .flush_caches_and_internal_states_o ( caches_and_internal_states_flush_ctrl_cache ),
    .flush_caches_ack_i     ( caches_flush_ack_cache_ctrl   ),
    .ex_valid_o             ( ex_valid_ctrl_if ), 
    .halt_o                 ( halt_ctrl                     ),
    .set_pc_ctrl_o          ( set_pc_ctrl_frontend             ),
    .set_debug_pc_o          ( set_debug_pc_ctrl_frontend             ),
    .pc_o                   ( pc_ctrl_frontend                   ),
    .pc_commit_i            ( pc_commit_ctrl                     ),
    .wfi_set_i     ( wfi_csr_ctrl_set ),
    .wfi_reset_i   ( wfi_csr_ctrl_reset ),
    .eret_i                 ( eret                          ),
    .eret_o                 ( eret_ctrl_if ), 
    .epc_i                  ( epc_commit_ctrl               ),
    .epc_o                  ( epc_ctrl_pcgen                ),
    .ex_valid_i             ( ex_commit.valid               ),
    .set_debug_pc_i         ( set_debug_pc_csr_ctrl         ),
    .flush_csr_i            ( flush_csr_ctrl                ),
    .resolved_branch_i      ( resolved_branch_ex_several    ),
    .resolved_branch_o      ( resolved_branch_ctrl_frontend ),
    .fence_i_i              ( fence_i_commit_ctrl     ),
    .fence_i                ( fence_commit_ctrl       ),
    .fence_t_i              ( fence_t_commit_ctrl     ),
    .sfence_vma_i           ( sfence_vma_commit_ctrl  ),
    .flush_commit_i         ( flush_commit                  )
  );

  // -------------------
  // Cache Subsystem
  // -------------------

/*`ifdef WT_DCACHE
  // this is a cache subsystem that is compatible with OpenPiton
  wt_cache_subsystem #(
    .ArianeCfg            ( ArianeCfg     )
  ) i_cache_subsystem (
    // to D$
    .clk_i                 ( clk_i                       ),
    .rst_ni                ( rst_ni                      ),
    // I$
    .icache_en_i           ( icache_en_csr               ),
    .icache_flush_i        ( icache_flush_ctrl_cache     ),
    .icache_miss_o         ( icache_miss_cache_perf      ),
    .icache_areq_i         ( icache_areq_ex_cache        ),
    .icache_areq_o         ( icache_areq_cache_ex        ),
    .icache_dreq_i         ( icache_dreq_if_cache        ),
    .icache_dreq_o         ( icache_dreq_cache_if        ),
    // D$
    .dcache_enable_i       ( dcache_en_csr_nbdcache      ),
    .dcache_flush_i        ( dcache_flush_ctrl_cache     ),
    .dcache_flush_ack_o    ( caches_flush_ack_cache_ctrl ),
    .flush_dcache_lfsr_i   ( flush_dcache_lfsr_ctrl_cache),
    .flush_icache_lfsr_i   ( flush_icache_lfsr_ctrl_cache),
    .flush_dcache_mem_arb_i     ( flush_dcache_mem_arb_ctrl_cache     ),
    .flush_dcache_wbuffer_arb_i ( flush_dcache_wbuffer_arb_ctrl_cache ),
    .flush_dcache_fifo_i        ( flush_dcache_fifo_ctrl_cache        ),
    // to commit stage
    .dcache_amo_req_i      ( amo_req                     ),
    .dcache_amo_resp_o     ( amo_resp                    ),
    // from PTW, Load Unit  and Store Unit
    .dcache_miss_o         ( dcache_miss_cache_perf      ),
    .dcache_req_ports_i    ( dcache_req_ports_ex_cache   ),
    .dcache_req_ports_o    ( dcache_req_ports_cache_ex   ),
    // write buffer status
    .wbuffer_empty_o       ( dcache_commit_wbuffer_empty ),
    .wbuffer_not_ni_o      ( dcache_commit_wbuffer_not_ni ),
`ifdef PITON_ARIANE
    .l15_req_o             ( l15_req_o                   ),
    .l15_rtrn_i            ( l15_rtrn_i                  )
`else
    // memory side
    .axi_req_o             ( axi_req_o                   ),
    .axi_resp_i            ( axi_resp_i                  )
`endif
  );
`else
*/
  std_cache_subsystem #(
    // note: this only works with one cacheable region
    // not as important since this cache subsystem is about to be
    // deprecated
    .ArianeCfg             ( ArianeCfg                   )
  ) i_cache_subsystem (
    // to D$
    .clk_i                 ( clk_i                       ),
    .rst_ni                ( rst_ni ),
    .priv_lvl_i            ( priv_lvl                    ),
    // I$
    .icache_en_i           ( icache_en_csr               ),
    .icache_flush_i        ( icache_flush_ctrl_cache     ),
    .icache_miss_o         ( icache_miss_cache_perf      ),
    .icache_areq_i         ( icache_areq_ex_cache        ),
    .icache_areq_o         ( icache_areq_cache_ex        ),
    .icache_dreq_i         ( icache_dreq_if_cache        ),
    .icache_dreq_o         ( icache_dreq_cache_if        ),
    // D$
    .dcache_enable_i       ( dcache_en_csr_nbdcache      ),
    .dcache_flush_i        ( dcache_flush_ctrl_cache     ),
    // to ctrl
    .caches_flush_ack_o    ( caches_flush_ack_cache_ctrl ),
    .caches_flush_and_internal_states_i (caches_and_internal_states_flush_ctrl_cache),

    
    // to commit stage
    .amo_req_i             ( amo_req                     ),
    .amo_resp_o            ( amo_resp                    ),
    .dcache_miss_o         ( dcache_miss_cache_perf      ),
    // this is statically set to 1 as the std_cache does not have a wbuffer
    .wbuffer_empty_o       ( dcache_commit_wbuffer_empty ),
    // from PTW, Load Unit  and Store Unit
    .dcache_req_ports_i    ( dcache_req_ports_ex_cache   ),
    .dcache_req_ports_o    ( dcache_req_ports_cache_ex   ),
    // memory side
    .axi_req_o             ( axi_req_o                   ),
    .axi_resp_i            ( axi_resp_i                  )
  );
  assign dcache_commit_wbuffer_not_ni = 1'b1;
//`endif

  // -------------------
  // Parameter Check
  // -------------------
  // pragma translate_off
  `ifndef VERILATOR
  initial ariane_pkg::check_cfg(ArianeCfg);
  `endif
  // pragma translate_on

  // -------------------
  // Instruction Tracer
  // -------------------

  // Instruction trace port (used for FireSim)
`ifdef FIRESIM_TRACE
  for (genvar i = 0; i < NR_COMMIT_PORTS; i++) begin : gen_tp_connect
    assign trace_o[i].clock = clk_i;
    assign trace_o[i].reset = rst_ni;
    assign trace_o[i].valid = commit_ack[i] & ~commit_instr_rob_commit[i].ex.valid;
    assign trace_o[i].iaddr = commit_instr_rob_commit[i].pc;
    assign trace_o[i].insn = commit_instr_rob_commit[i].ex.tval[31:0];
    assign trace_o[i].priv = priv_lvl;
    assign trace_o[i].exception = commit_ack[i] & commit_instr_rob_commit[i].ex.valid & ~commit_instr_rob_commit[i].ex.cause[63];
    assign trace_o[i].interrupt = commit_ack[i] & commit_instr_rob_commit[i].ex.valid & commit_instr_rob_commit[i].ex.cause[63];
    assign trace_o[i].cause = commit_instr_rob_commit[i].ex.cause;
    assign trace_o[i].tval = commit_instr_rob_commit[i].ex.tval[31:0];
  end
`endif

  //pragma translate_off
`ifdef PITON_ARIANE
  localparam PC_QUEUE_DEPTH = 16;

  logic        piton_pc_vld;
  logic [riscv::VLEN-1:0] piton_pc;
  logic [NR_COMMIT_PORTS-1:0][riscv::VLEN-1:0] pc_data;
  logic [NR_COMMIT_PORTS-1:0] pc_pop, pc_empty;

  for (genvar i = 0; i < NR_COMMIT_PORTS; i++) begin : gen_pc_fifo
    fifo_v3 #(
      .DATA_WIDTH(64),
      .DEPTH(PC_QUEUE_DEPTH))
    i_pc_fifo (
      .clk_i      ( clk_i                                               ),
      .rst_ni     ( rst_ni                                              ),
      .flush_i    ( '0                                                  ),
      .testmode_i ( '0                                                  ),
      .full_o     (                                                     ),
      .empty_o    ( pc_empty[i]                                         ),
      .usage_o    (                                                     ),
      .data_i     ( commit_instr_rob_commit[i].pc                        ),
      .push_i     ( commit_ack[i] & ~commit_instr_rob_commit[i].ex.valid ),
      .data_o     ( pc_data[i]                                          ),
      .pop_i      ( pc_pop[i]                                           )
    );
  end

  rr_arb_tree #(
    .NumIn(NR_COMMIT_PORTS),
    .DataWidth(64))
  i_rr_arb_tree (
    .clk_i   ( clk_i        ),
    .rst_ni  ( rst_ni       ),
    .flush_i ( '0           ),
    .rr_i    ( '0           ),
    .req_i   ( ~pc_empty    ),
    .gnt_o   ( pc_pop       ),
    .data_i  ( pc_data      ),
    .gnt_i   ( piton_pc_vld ),
    .req_o   ( piton_pc_vld ),
    .data_o  ( piton_pc     ),
    .idx_o   (              )
  );
`endif // PITON_ARIANE
//pragma translate_on

`ifndef SYNTHESIS 
`ifndef VERILATOR
  instr_tracer_if tracer_if (clk_i);
  // assign instruction tracer interface
  // control signals
  assign tracer_if.rstn              = rst_ni;
  assign tracer_if.flush_unissued    = flush_misbranch_instr_ctrl_several;
  assign tracer_if.flush             = flush_ctrl_ex;
  // fetch
  assign tracer_if.instruction       = id_stage_i.fetch_entry_i.instruction;
  assign tracer_if.fetch_valid       = id_stage_i.fetch_entry_valid_i;
  assign tracer_if.fetch_ack         = id_stage_i.fetch_entry_ready_o;
  // Issue
  assign tracer_if.issue_ack         = issue_stage_i.csr_valid_o | issue_stage_i.lsu_valid_o | issue_stage_i.mult_valid_o | issue_stage_i.alu_valid_o | issue_stage_i.branch_valid_o | issue_stage_i.fpu_valid_o;
  assign tracer_if.issue_ie          = {issue_stage_i.pc_o, issue_stage_i.rs1_register_trace, issue_stage_i.rs2_register_trace, issue_stage_i.rd_register_trace, issue_stage_i.fu_data_o.imm, issue_stage_i.fu_data_o.operator};
  // write-back
  assign tracer_if.waddr             = waddr_commit_id;
  assign tracer_if.wdata             = wdata_commit_id;
  assign tracer_if.we_gpr            = we_gpr_commit_id;
  assign tracer_if.we_fpr            = we_fpr_commit_id;
  // commit
  assign tracer_if.commit_instr      = commit_instr_rob_commit;
  assign tracer_if.commit_ack        = commit_ack;
  // branch predict
  assign tracer_if.resolve_branch    = resolved_branch_ex_several;
  // address translation
  // stores
  assign tracer_if.st_valid          = ex_stage_i.lsu_i.i_store_unit.store_buffer_i.valid_i;
  assign tracer_if.st_paddr          = ex_stage_i.lsu_i.i_store_unit.store_buffer_i.paddr_i;
  // loads
  assign tracer_if.ld_valid          = ex_stage_i.lsu_i.i_load_unit.req_port_o.tag_valid;
  assign tracer_if.ld_kill           = ex_stage_i.lsu_i.i_load_unit.req_port_o.kill_req;
  assign tracer_if.ld_paddr          = ex_stage_i.lsu_i.i_load_unit.paddr_i;
  // exceptions
  assign tracer_if.exception         = commit_stage_i.exception_o;
  // assign current privilege level
  assign tracer_if.priv_lvl          = priv_lvl;
  assign tracer_if.debug_mode        = debug_mode_csr_toseveral;

  instr_tracer instr_tracer_i (
    .tracer_if(tracer_if),
    .hart_id_i
  );

// mock tracer for Verilator, to be used with spike-dasm
`else

  int f;
  logic [63:0] cycles;

`ifdef DROMAJO
  initial begin
    string f_name;
    if ($value$plusargs("checkpoint=%s", f_name)) begin
      init_dromajo({f_name, ".cfg"});
      $display("Done initing dromajo...");
    end else begin
      $display("Failed initing dromajo. Provide checkpoint name.");
    end
  end
`endif

  initial begin
    f = $fopen("trace_hart_00.dasm", "w");
  end

`ifdef DROMAJO
  always_ff @(posedge clk_i) begin
      for (int i = 0; i < NR_COMMIT_PORTS; i++) begin
        if (commit_instr_rob_commit[i].ex.valid) begin
          dromajo_trap(hart_id_i,
                       commit_instr_rob_commit[i].ex.cause);
        end
      end
  end

  always_ff @(posedge clk_i) begin
    for (int i = 0; i < NR_COMMIT_PORTS; i++) begin
      if (commit_ack[i] && !commit_instr_rob_commit[i].ex.valid) begin
        if (csr_op_commit_csr == 0) begin
          dromajo_step(hart_id_i,
                       commit_instr_rob_commit[i].pc,
                       commit_instr_rob_commit[i].ex.tval[31:0],
                       commit_instr_rob_commit[i].result, cycles);
        end else begin
          dromajo_step(hart_id_i,
                       commit_instr_rob_commit[i].pc,
                       commit_instr_rob_commit[i].ex.tval[31:0],
                       csr_rdata_csr_commit, cycles);
        end
      end
    end
  end
`endif

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cycles <= 0;
    end else begin
      string mode = "";
      if (debug_mode_csr_toseveral) mode = "D";
      else begin
        case (priv_lvl)
        riscv::PRIV_LVL_M: mode = "M";
        riscv::PRIV_LVL_S: mode = "S";
        riscv::PRIV_LVL_U: mode = "U";
        endcase
      end
      for (int i = 0; i < NR_COMMIT_PORTS; i++) begin
        if (commit_ack[i] && !commit_instr_rob_commit[i].ex.valid) begin
          $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_rob_commit[i].pc, mode, commit_instr_rob_commit[i].ex.tval[31:0], commit_instr_rob_commit[i].ex.tval[31:0]);
        end else if (commit_ack[i] && commit_instr_rob_commit[i].ex.valid) begin
          if (commit_instr_rob_commit[i].ex.cause == 2) begin
            $fwrite(f, "Exception Cause: Illegal Instructions, DASM(%h) PC=%h\n", commit_instr_rob_commit[i].ex.tval[31:0], commit_instr_rob_commit[i].pc);
          end else begin
            if (debug_mode_csr_toseveral) begin
              $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_rob_commit[i].pc, mode, commit_instr_rob_commit[i].ex.tval[31:0], commit_instr_rob_commit[i].ex.tval[31:0]);
            end else begin
              $fwrite(f, "Exception Cause: %5d, DASM(%h) PC=%h\n", commit_instr_rob_commit[i].ex.cause, commit_instr_rob_commit[i].ex.tval[31:0], commit_instr_rob_commit[i].pc);
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
`endif // VERILATOR
`endif // SYNTHESIS

endmodule // ariane
