// TODO : header 

module re_order_buffer #(

  parameter int unsigned NR_WB_PORTS     = 4,
  parameter int unsigned NR_COMMIT_PORTS = 2

) (
  input  logic                                                  clk_i,    // Clock
  input  logic                                                  rst_ni,   // Asynchronous reset active low
  input  logic                                                  flush_i,  // flush whole re-order_buffer
  input  logic                                                  flush_misbranch_instr_i,
  
  //ics to rob
  input logic                                                   issued_instr_valid_i, // the rob sample an instruction when this signal is high  
  input logic [riscv::VLEN-1:0]                                 issued_instr_pc_i,            // PC of instruction
  input ariane_pkg::fu_t                                        issued_instr_fu_i,            // functional unit to use
  input ariane_pkg::fu_op                                       issued_instr_op_i,            // operation to perform in each functional unit
  input logic [ariane_pkg::REG_ADDR_SIZE-1:0]                   issued_instr_rd_i,            // register destination address
  input logic [ariane_pkg::TRANS_ID_BITS-1:0]                   issued_instr_trans_id_i,      // trans id of the instruction (position in the rob)
  input ariane_pkg::exception_t                                 issue_instr_exception_i,
  input logic                                                   issue_instr_iscompressed_i,   // needed for single step logic into csr_regfile.. probably the whole concept is improvable. 

`ifndef SYNTHESIS
  input riscv::xlen_t                                           rs1_operand_i,     // needed to easy instr_trace information, TODO: should be trimmed in syntesys automatically, we should verify that. if not true we should use pragmas
  input riscv::xlen_t                                           rs2_operand_i,     // needed to easy instr_trace information, TODO: should be trimmed in syntesys automatically, we should verify that. if not true we should use pragmas
`endif

  
  //rob to ics
  output logic [ariane_pkg::NR_ROB_ENTRIES-1:0]                  flush_ics_transID_structure_o, // and review if we can simplify

  //to commit stage
  output logic [NR_COMMIT_PORTS-1:0] [ariane_pkg::TRANS_ID_BITS-1:0] commit_trans_id_o,
  output ariane_pkg::re_order_buffer_entry_t [NR_COMMIT_PORTS-1:0]   commit_instr_o,
  input logic              [NR_COMMIT_PORTS-1:0]               commit_ack_i,
  
  
  // write-back port

  input logic [NR_WB_PORTS-1:0][ariane_pkg::TRANS_ID_BITS-1:0]  trans_id_i,  // transaction ID at which to write the result back
  input logic [NR_WB_PORTS-1:0][63:0]                           wbdata_i,    // write data in
  input ariane_pkg::exception_t [NR_WB_PORTS-1:0]               ex_i,        // exception from a functional unit (e.g.: ld/st exception)
  input logic [NR_WB_PORTS-1:0]                                 wt_valid_i,   // data in is valid
  input logic [riscv::VLEN-1:0] branch_target_address_i 
);

// this is the FIFO struct of the issue queue
struct packed {
  logic                          issued;         // this bit indicates whether we issued this instruction e.g.: if it is valid
  logic                          is_rd_fpr_flag; // redundant meta info, added for speed
  ariane_pkg::re_order_buffer_entry_t rob_e;            // this is ROB entry we will send to ex
} rob_mem_q [ariane_pkg::NR_ROB_ENTRIES-1:0], rob_mem_n [ariane_pkg::NR_ROB_ENTRIES-1:0];


logic [$clog2(NR_COMMIT_PORTS):0] num_commit;
logic [NR_COMMIT_PORTS-1:0][ariane_pkg::TRANS_ID_BITS-1:0] commit_pointer_n, commit_pointer_q;
logic [ariane_pkg::NR_ROB_ENTRIES-1:0] flush_ics_transID_structure; 



assign commit_pointer_n[0] = (flush_i) ? '0 : commit_pointer_q[0] + num_commit;
// precompute offsets for commit slots
for (genvar k=1; k < NR_COMMIT_PORTS; k++) begin : gen_cnt_incr
  assign commit_pointer_n[k] = (flush_i) ? '0 : commit_pointer_n[0] + unsigned'(k);
end

assign flush_ics_transID_structure_o = flush_ics_transID_structure; 


  // output commit instruction directly
  always_comb begin : commit_ports
    for (int unsigned i = 0; i < NR_COMMIT_PORTS; i++) begin
      commit_instr_o[i] = rob_mem_q[commit_pointer_q[i]].rob_e;
      commit_instr_o[i].valid = rob_mem_q[commit_pointer_q[i]].issued & rob_mem_q[commit_pointer_q[i]].rob_e.valid; 
      commit_trans_id_o[i] = commit_pointer_q[i];
    end
  end

  // maintain a FIFO with issued instructions
  // keep track of all issued instructions
  always_comb begin : issue_fifo
    // default assignment
    rob_mem_n          = rob_mem_q;
    flush_ics_transID_structure = '0; 
    

    // if we got a acknowledge from the issue stage, put this rob entry in the queue
     
    if (issued_instr_valid_i & ~flush_misbranch_instr_i) //if issued_instr_valid_i == 1 the instruction has been issued to the ex stage! 
    begin 

      rob_mem_n[issued_instr_trans_id_i].issued = 1'b1; 
      rob_mem_n[issued_instr_trans_id_i].rob_e.pc = issued_instr_pc_i;
      rob_mem_n[issued_instr_trans_id_i].rob_e.fu = issued_instr_fu_i;   // those info are needed at commit
      rob_mem_n[issued_instr_trans_id_i].rob_e.op = issued_instr_op_i; 
      rob_mem_n[issued_instr_trans_id_i].rob_e.rd = issued_instr_rd_i;
      rob_mem_n[issued_instr_trans_id_i].rob_e.is_compressed = issue_instr_iscompressed_i;
      

`ifndef SYNTHESIS
      rob_mem_n[issued_instr_trans_id_i].rob_e.rs1_operand = rs1_operand_i; 
      rob_mem_n[issued_instr_trans_id_i].rob_e.rs2_operand = rs2_operand_i;
`endif
      
      if (issue_instr_exception_i.valid)
      begin
        rob_mem_n[issued_instr_trans_id_i].rob_e.ex = issue_instr_exception_i;
        rob_mem_n[issued_instr_trans_id_i].rob_e.valid = 1'b1; 
      end
      
    end

    // ------------
    // Write Back
    // ------------
    for (int unsigned i = 0; i < NR_WB_PORTS; i++) begin   // can also be that we have a write back on a transid with "issued" == 0, but in that case the issue information will arrive 

      // check if this instruction was issued (e.g.: it could happen after a flush that there is still
      // something in the pipeline e.g. an incomplete memory operation)
      if (wt_valid_i[i]) // only writes if the tr id is really associated to the wb instruction 
      begin

        rob_mem_n[trans_id_i[i]].rob_e.valid = 1'b1;
        rob_mem_n[trans_id_i[i]].rob_e.result = wbdata_i[i];
        rob_mem_n[trans_id_i[i]].rob_e.branch_address = branch_target_address_i;
        // write the exception back if it is valid
        if (ex_i[i].valid)
          rob_mem_n[trans_id_i[i]].rob_e.ex = ex_i[i];
        // write the fflags back from the FPU (exception valid is never set), leave tval intact
        else if (rob_mem_q[trans_id_i[i]].rob_e.fu inside {ariane_pkg::FPU, ariane_pkg::FPU_VEC})
          rob_mem_n[trans_id_i[i]].rob_e.ex.cause = ex_i[i].cause;
      end
    end

// ------------
    // FU NONE
    // ------------
    for (int unsigned i = 0; i < ariane_pkg::NR_ROB_ENTRIES; i++) begin
      // The FU is NONE -> this instruction is valid immediately
      if (rob_mem_q[i].rob_e.fu == ariane_pkg::NONE && rob_mem_q[i].issued)
        rob_mem_n[i].rob_e.valid = 1'b1;
    end

    // ------------
    // Commit Port
    // ------------
    // we've got an acknowledge from commit
    for (logic [ariane_pkg::TRANS_ID_BITS-1:0] i = 0; i < NR_COMMIT_PORTS; i++) begin
      if (commit_ack_i[i]) begin
        // this instruction is no longer in issue e.g.: it is considered finished
        flush_ics_transID_structure[commit_pointer_q[i]] = 1'b1; 
        rob_mem_n[commit_pointer_q[i]].issued     = 1'b0;
        rob_mem_n[commit_pointer_q[i]].rob_e.valid  = 1'b0;

      end
    end

    // ------
    // Flush
    // ------
    if (flush_i) begin
      for (int unsigned i = 0; i < ariane_pkg::NR_ROB_ENTRIES; i++) begin
        // set all valid flags for all entries to zero
        rob_mem_n[i].issued       = 1'b0;
        rob_mem_n[i].rob_e.valid    = 1'b0;
        rob_mem_n[i].rob_e.ex.valid = 1'b0;
        
      end
    end
  end

// FIFO counter updates
popcount #(
  .INPUT_WIDTH(NR_COMMIT_PORTS)
) i_popcount (
  .data_i(commit_ack_i),
  .popcount_o(num_commit)
);


 always_ff @(posedge clk_i or negedge rst_ni) begin : regs
    if(~rst_ni) begin
     
      rob_mem_q                 <= '{default: 0};
      commit_pointer_q      <= '0;
      
    end else begin
     
      rob_mem_q                 <= rob_mem_n;
      commit_pointer_q      <= commit_pointer_n;
    
    end
  end

endmodule
