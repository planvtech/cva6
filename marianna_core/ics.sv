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
// Author: Marco Sabatano
// Date: Jan 2021
// Description: Issue Control Structure, 
// issue the instructions if all issue conditions are met. 
// It contains a memory structure to forward all the results of completed and not yet committed instructions to the ex stage. 
//

module issue_control_structure #(
  parameter int unsigned NR_WB_PORTS = 3, // LOAD, MUL, and FLU 
  parameter int unsigned NR_COMMIT_PORTS = 2
) (
  input  logic                                                  clk_i,    // Clock
  input  logic                                                  rst_ni,   // Asynchronous reset active low
  // from ctrl 
  input  logic                                                  flush_i,  // flush architectural state of both ICS AND ROB
 
  // ID <--> ICS
  input ariane_pkg::id_entry_t                                  decoded_instr_i,
  input logic                                                   decoded_instr_valid_i,
  input logic [ariane_pkg::TRANS_ID_BITS-1:0]                   rs1_transID_reference_i, // transID where potentially look for rs1 forwarding 
  input logic [ariane_pkg::TRANS_ID_BITS-1:0]                   rs2_transID_reference_i, // transID where potentially look for rs1 forwarding
  output logic                                                  ics_full_o, 
  output logic                                                  decoded_instr_ack_o,
  //

  // ICS <--> ROB
  output logic                                                  rob_sample_o,    
`ifndef SYNTHESIS
  output riscv::xlen_t                                          rs1_operand_o, 
  output riscv::xlen_t                                          rs2_operand_o,       
`endif
  input logic [ariane_pkg::NR_ROB_ENTRIES-1:0]                   flush_ics_transID_structure_i,

  // from ctrl 
  input  logic                                                  flush_misbranch_instr_i, // flush only un-issued instructions
 
  // Feedback signals about rob
  input logic                                                   rob_sample_feedback_i,
  input logic [ariane_pkg::TRANS_ID_BITS-1:0]                   rob_transID_feedback_i, 

  // write-back port to "sniff" and store the results
  input logic [NR_WB_PORTS-1:0][ariane_pkg::TRANS_ID_BITS-1:0]  trans_id_i,  // transaction ID at which to write the result back
  input logic [NR_WB_PORTS-1:0][63:0]                           wbdata_i,    // write data in
  input logic [NR_WB_PORTS-1:0]                                 wt_valid_i,  // data in is valid
  
  // ready signals coming from functional units in EX
  input  logic                                   flu_ready_i,      // Fixed latency unit ready to accept a new request
  input  logic                                   lsu_ready_i,      // FU is ready
  input  logic                                   fpu_ready_i,      // FU is ready
  input  logic                                   mult_ready_i, 
  
  output ariane_pkg::fu_data_t                   fu_data_o,
  output logic [63:0]                            pc_o,
  output logic                                   is_compressed_instr_o,
    // ALU 1
  output logic                                   alu_valid_o,      // Output is valid
  // Branches and Jumps
  output logic                                   branch_valid_o,   // this is a valid branch instruction
  output ariane_pkg::branchpredict_entry_t         branch_predict_o,
  // LSU
  output logic                                   lsu_valid_o,      // Output is valid
  // MULT
  output logic                                   mult_valid_o,     // Output is valid
  // FPU
  output logic                                   fpu_valid_o,      // Output is valid
  output logic [1:0]                             fpu_fmt_o,        // FP fmt field from instr.
  output logic [2:0]                             fpu_rm_o,         // FP rm field from instr.
  // CSR
  output logic                                   csr_valid_o,      // Output is valid
  // commit port
  input  logic [NR_COMMIT_PORTS-1:0][4:0]        waddr_i,
  input  logic [NR_COMMIT_PORTS-1:0][63:0]       wdata_i,
  input  logic [NR_COMMIT_PORTS-1:0]             we_gpr_i
  
);

localparam int unsigned NR_ICS_ENTRIES = ariane_pkg::NR_ROB_ENTRIES; //same as ROB
ariane_pkg::ics_entry_t [NR_ICS_ENTRIES-1:0] ics_mem_q, ics_mem_n; 
logic [ariane_pkg::TRANS_ID_BITS-1:0] current_instruction_trans_id;
logic preissue_doable;
logic ics_full;
logic fu_busy; 
logic mult_busy_intern; 
logic flu_busy_intern; 
logic lsu_busy_intern; 
logic fpu_busy_intern; 
logic [4:0] rs1_register; 
logic [4:0] rs2_register; 
logic [4:0] rs3_register; 
logic [4:0] rd_register; 
logic rs1_valid_ics; 
logic rs2_valid_ics; 
logic rs3_valid_ics; 
logic [63:0] rs1_data_ics; 
logic [63:0] rs2_data_ics; 
logic [63:0] rs3_data_ics;

logic rs1_uses_immediate; 
logic rs2_uses_immediate; 

logic [63:0] rs1_immediate_data; 
logic [63:0] rs2_immediate_data; 

logic do_the_issue;
logic stall_execution; 

logic rs1_value_not_available; 
logic rs2_value_not_available; 

logic [63:0]  rs1_data_forwarded;
logic rs1_using_forwarding;
logic [63:0]  rs2_data_forwarded;
logic rs2_using_forwarding;
logic [ariane_pkg::FLEN-1:0]  rs3_data_forwarded;
logic rs3_using_forwarding;
logic execution_is_possible;

logic  rs1_value_available_in_RF;
logic  rs2_value_available_in_RF; 


/* OLD IRO signal declaration */
logic [63:0] operand_a_regfile, operand_b_regfile;  // operands coming from regfile
logic [ariane_pkg::FLEN-1:0] operand_c_regfile; // third operand only from fp regfile
// output flipflop (ID <-> EX)
logic [63:0] operand_a_n, operand_a_q,
                 operand_b_n, operand_b_q,
                 imm_n, imm_q;

logic          alu_valid_q;
logic         mult_valid_q;
logic          fpu_valid_q;
logic [1:0]      fpu_fmt_q;
logic [2:0]       fpu_rm_q;
logic          lsu_valid_q;
logic          csr_valid_q;
logic       branch_valid_q;

logic [ariane_pkg::TRANS_ID_BITS-1:0] trans_id_n, trans_id_q;
ariane_pkg::fu_op operator_n, operator_q; // operation to perform
ariane_pkg::fu_t  fu_n,       fu_q; // functional unit to use
  
logic [1:0][63:0] rdata;
logic [1:0][4:0]  raddr_pack;

// pack signals
logic [NR_COMMIT_PORTS-1:0][4:0]  waddr_pack;
logic [NR_COMMIT_PORTS-1:0][63:0] wdata_pack;
logic [NR_COMMIT_PORTS-1:0]       we_pack;
logic rs1_register_is_r0; 
logic rs2_register_is_r0; 

`ifndef SYNTHESIS
assign rs1_operand_o = operand_a_n;
assign rs2_operand_o = operand_b_n;
`endif


assign preissue_doable = ~ics_full & decoded_instr_valid_i; 
assign execution_is_possible = (~stall_execution & ~fu_busy) | (decoded_instr_i.fu == ariane_pkg::NONE) | decoded_instr_i.ex.valid;
assign do_the_issue = preissue_doable & execution_is_possible; // simple version, i do the "issue" on the issue data structure if the execution is possible (operands available in addition to issue conditions)
assign rob_sample_o = do_the_issue; 
assign decoded_instr_ack_o = do_the_issue; 


always_comb begin 
  ics_full = 1'b1;  // the ICS is full if all the ics_mem_q entries have issued = 1'b1 
  for (int i = 0; i < NR_ICS_ENTRIES; i = i + 1) begin
    ics_full &= ics_mem_q[i].issued;
  end
end

assign ics_full_o = ics_full; 

assign current_instruction_trans_id = decoded_instr_i.trans_id; 

assign rs1_register_is_r0 = ~(|rs1_register);
assign rs2_register_is_r0 = ~(|rs2_register);

  // original instruction stored in tval
    riscv::instruction_t orig_instr;
    assign orig_instr = riscv::instruction_t'(decoded_instr_i.ex.tval[31:0]);

    // ID <-> EX registers

    assign fu_data_o.operand_a = operand_a_q;
    assign fu_data_o.operand_b = operand_b_q;
    assign fu_data_o.fu        = fu_q;
    assign fu_data_o.operator  = operator_q;
    assign fu_data_o.trans_id  = trans_id_q;
    assign fu_data_o.imm       = imm_q;
    assign alu_valid_o         = alu_valid_q;
    assign branch_valid_o      = branch_valid_q;
    assign lsu_valid_o         = lsu_valid_q;
    assign csr_valid_o         = csr_valid_q;
    assign mult_valid_o        = mult_valid_q;
    assign fpu_valid_o         = fpu_valid_q;
    assign fpu_fmt_o           = fpu_fmt_q;
    assign fpu_rm_o            = fpu_rm_q;

      
  
    // Forwarding/Output MUX
    always_comb begin : forwarding_operand_select

        // default is regfiles (gpr or fpr)
        // immediates are the third operands in the store case
        // for FP operations, the imm field can also be the third operand from the regfile
        //imm_n      = is_imm_fpr(issue_instr_i.op) ? operand_c_regfile : issue_instr_i.result;
        imm_n = decoded_instr_i.result;
        trans_id_n = decoded_instr_i.trans_id; //current_istr_transID_reference_i;
        fu_n       = decoded_instr_i.fu;
        operator_n = decoded_instr_i.op;
        // or should we forward
        
        if (rs1_using_forwarding)
          operand_a_n  = rs1_data_forwarded ;
        else
          operand_a_n = operand_a_regfile;
         
        
        if (rs2_using_forwarding)
          operand_b_n = rs2_data_forwarded ; 
        else
          operand_b_n = operand_b_regfile;

  
        if (rs3_using_forwarding) begin
            imm_n  = rs3_data_forwarded;
        end

    end
    

     // FU select, assert the correct valid out signal (in the next cycle)
    // This needs to be like this to make verilator happy. I know its ugly.
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        alu_valid_q    <= 1'b0;
        lsu_valid_q    <= 1'b0;
        mult_valid_q   <= 1'b0;
        fpu_valid_q    <= 1'b0;
        fpu_fmt_q      <= 2'b0;
        fpu_rm_q       <= 3'b0;
        csr_valid_q    <= 1'b0;
        branch_valid_q <= 1'b0;
      end else begin
        alu_valid_q    <= 1'b0;
        lsu_valid_q    <= 1'b0;
        mult_valid_q   <= 1'b0;
        fpu_valid_q    <= 1'b0;
        fpu_fmt_q      <= 2'b0;
        fpu_rm_q       <= 3'b0;
        csr_valid_q    <= 1'b0;
        branch_valid_q <= 1'b0;
        // Exception pass through:
        // If an exception has occurred simply pass it through
        // we do not want to issue this instruction
        if (!decoded_instr_i.ex.valid & do_the_issue ) begin
            case (decoded_instr_i.fu)
                ariane_pkg::ALU:
                    alu_valid_q    <= 1'b1;
                ariane_pkg::CTRL_FLOW:
                    branch_valid_q <= 1'b1;
                ariane_pkg::MULT:
                    mult_valid_q   <= 1'b1;
                ariane_pkg::FPU : begin
                    fpu_valid_q    <= 1'b1;
                    fpu_fmt_q      <= orig_instr.rftype.fmt; // fmt bits from instruction
                    fpu_rm_q       <= orig_instr.rftype.rm;  // rm bits from instruction
                end
                ariane_pkg::FPU_VEC : begin
                    fpu_valid_q    <= 1'b1;
                    fpu_fmt_q      <= orig_instr.rvftype.vfmt;         // vfmt bits from instruction
                    fpu_rm_q       <= {2'b0, orig_instr.rvftype.repl}; // repl bit from instruction
                end
                ariane_pkg::LOAD, ariane_pkg::STORE:
                    lsu_valid_q    <= 1'b1;
                ariane_pkg::CSR:
                    csr_valid_q    <= 1'b1;
                default:;
            endcase
        end
        
        end
    end


//

assign mult_busy_intern = ~mult_ready_i; 
assign flu_busy_intern = ~flu_ready_i; 
assign lsu_busy_intern = ~lsu_ready_i; 
assign fpu_busy_intern = ~fpu_ready_i; 

                                          // istruction is retired        or  istruction is no the one was expecting(overwrite) or  rs1=0
assign rs1_value_available_in_RF = ~ics_mem_q[rs1_transID_reference_i].issued | (ics_mem_q[rs1_transID_reference_i].rd != rs1_register) | rs1_register_is_r0; 
assign rs2_value_available_in_RF = ~ics_mem_q[rs2_transID_reference_i].issued | (ics_mem_q[rs2_transID_reference_i].rd != rs2_register) | rs2_register_is_r0;

assign rs1_using_forwarding = (rs1_valid_ics & (ics_mem_q[rs1_transID_reference_i].rd == rs1_register) & ~rs1_register_is_r0) | rs1_uses_immediate;
assign rs2_using_forwarding = (rs2_valid_ics & (ics_mem_q[rs2_transID_reference_i].rd == rs2_register) & ~rs2_register_is_r0) | rs2_uses_immediate;

assign rs1_value_not_available = ~rs1_value_available_in_RF & ~rs1_using_forwarding; // not availabe in RF NOR in ICS , we need to wait (stall)
assign rs2_value_not_available = ~rs2_value_available_in_RF & ~rs2_using_forwarding; // not availabe in RF NOR in ICS

assign stall_execution = rs1_value_not_available | rs2_value_not_available; 

assign rs1_data_forwarded  = (rs1_uses_immediate)? rs1_immediate_data : rs1_data_ics; // the data is forwarded from the ID (encoded in the instructrion) or from the ICS
assign rs2_data_forwarded  = (rs2_uses_immediate)? rs2_immediate_data : rs2_data_ics; // the data is forwarded from the ID (encoded in the instructrion) or from the ICS

assign rs3_data_forwarded = rs3_data_ics; 
assign rs3_using_forwarding = rs3_valid_ics;



assign rd_register  = decoded_instr_i.rd;  
assign rs1_register = decoded_instr_i.rs1; 
assign rs2_register = decoded_instr_i.rs2; 
assign rs3_register = '0; // only used on FPU versions, not yet supported
  
    always_comb begin : ics_comb_paths 
      
      ics_mem_n = ics_mem_q; 

      
    // ------------
    // Write Back into ICS memory 
    // ------------

      for (int unsigned i = 0; i < NR_WB_PORTS; i++) 
      begin    
            
          if (wt_valid_i[i] && ics_mem_q[trans_id_i[i]].result_is_forwardable) 
            begin   

                ics_mem_n[trans_id_i[i]].result_is_valid = 1'b1;
                ics_mem_n[trans_id_i[i]].result = wbdata_i[i];
            end

      end 

    for (int unsigned i = 0; i < NR_ICS_ENTRIES; i++) 
      begin
        if (flush_ics_transID_structure_i[i])
        begin 
          ics_mem_n[i].issued=1'b0; 
        end
      end
        
    if (flush_misbranch_instr_i & rob_sample_feedback_i) // flush only instruction that have been blocked before being issued in rob
    begin 
      ics_mem_n[rob_transID_feedback_i].issued = 1'b0;
      ics_mem_n[rob_transID_feedback_i].result_is_valid = 1'b0; 
    end



      if (preissue_doable)  
        begin 
          
          if (decoded_instr_i.fu == ariane_pkg::CSR) 
          
            begin 
              ics_mem_n[current_instruction_trans_id].result_is_forwardable = 1'b0; 
            end 
          else 
            begin
              ics_mem_n[current_instruction_trans_id].result_is_forwardable = 1'b1; 
            end

          ics_mem_n[current_instruction_trans_id].result_is_valid = 1'b0; 
          ics_mem_n[current_instruction_trans_id].rd = rd_register;

        end 
      

      if (do_the_issue)
         ics_mem_n[current_instruction_trans_id].issued = 1'b1; 
      
    end 
   
always_comb begin : unit_busy
  unique case (decoded_instr_i.fu)
    ariane_pkg::NONE:
     fu_busy = 1'b0;
    ariane_pkg::ALU, ariane_pkg::CTRL_FLOW, ariane_pkg::CSR:
      fu_busy = flu_busy_intern;
    ariane_pkg::MULT:
      fu_busy = mult_busy_intern; 
    ariane_pkg::FPU, ariane_pkg::FPU_VEC:
      fu_busy =  fpu_busy_intern; 
    ariane_pkg::LOAD, ariane_pkg::STORE:
      fu_busy = lsu_busy_intern; 
    default:
      fu_busy = 1'b0;
    endcase
end


always_comb //: direct_forward_searching 
begin 
  rs1_valid_ics = 1'b0; 
  rs2_valid_ics = 1'b0; 
  
   
    if (ics_mem_q[rs1_transID_reference_i].result_is_valid)
      
      begin 
      
        rs1_valid_ics = 1'b1;
        rs1_data_ics = ics_mem_q[rs1_transID_reference_i].result;
      
      end 
      else 
      begin
        
        rs1_valid_ics = ics_mem_n[rs1_transID_reference_i].result_is_valid;
        rs1_data_ics = ics_mem_n[rs1_transID_reference_i].result;
      
      end  
    
    if (ics_mem_q[rs2_transID_reference_i].result_is_valid)
      
      begin 
      
        rs2_valid_ics = 1'b1;
        rs2_data_ics = ics_mem_q[rs2_transID_reference_i].result;
      
      end 
      else 
      begin
        
        rs2_valid_ics = ics_mem_n[rs2_transID_reference_i].result_is_valid;
        rs2_data_ics = ics_mem_n[rs2_transID_reference_i].result;
      
      end  


      

  rs3_valid_ics = 1'b0; // forwarding of rs3 never needed without FPU
  rs3_data_ics = '0; 

 end 

  always_comb begin : check_immediate_usage 
    
    rs1_uses_immediate=1'b0; 
    rs2_uses_immediate=1'b0;
    rs1_immediate_data='0; 
    rs2_immediate_data='0;
    


   // use the PC as operand a
        if (decoded_instr_i.use_pc) begin
            rs1_immediate_data = {{64-riscv::VLEN{decoded_instr_i.pc[riscv::VLEN-1]}}, decoded_instr_i.pc};
            rs1_uses_immediate = 1'b1;
        end

        // use the zimm as operand a
        if (decoded_instr_i.use_zimm) begin
            // zero extend operand a
            rs1_immediate_data = {59'b0,rs1_register};
            rs1_uses_immediate = 1'b1;
        end
        // or is it an immediate (including PC), this is not the case for a store and control flow instructions
        // also make sure operand B is not already used as an FP operand
        if (decoded_instr_i.use_imm && (decoded_instr_i.fu != ariane_pkg::STORE) && (decoded_instr_i.fu != ariane_pkg::CTRL_FLOW)) begin //and is not fpr operation
            rs2_immediate_data = decoded_instr_i.result;
            rs2_uses_immediate = 1'b1; 
        end

  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin 
    if (~rst_ni) 
    begin 
      ics_mem_q <= '0;
    end
    else if (flush_i)
    begin
      ics_mem_q <= '0;
    end
    else
    begin
      ics_mem_q <= ics_mem_n; 
    end
  end

    // ----------------------
    // Integer Register File
    // ----------------------
      assign raddr_pack = {decoded_instr_i.rs2[4:0], decoded_instr_i.rs1[4:0]};
    for (genvar i = 0; i < NR_COMMIT_PORTS; i++) begin : gen_write_back_port
        assign waddr_pack[i] = waddr_i[i];
        assign wdata_pack[i] = wdata_i[i];
        assign we_pack[i]    = we_gpr_i[i];
    end

    ariane_regfile #(
        .DATA_WIDTH     ( 64              ),
        .NR_READ_PORTS  ( 2               ),
        .NR_WRITE_PORTS ( NR_COMMIT_PORTS ),
        .ZERO_REG_ZERO  ( 1               )
    ) i_ariane_regfile (
        .test_en_i ( 1'b0       ),
        .raddr_i   ( raddr_pack ),
        .rdata_o   ( rdata      ),
        .waddr_i   ( waddr_pack ),
        .wdata_i   ( wdata_pack ),
        .we_i      ( we_pack    ),
        .*
    );

    assign operand_a_regfile = /*is_rs1_fpr(issue_instr_i.op) ? fprdata[0] :*/ rdata[0];
    assign operand_b_regfile = /*is_rs2_fpr(issue_instr_i.op) ? fprdata[1] : */rdata[1];
    assign operand_c_regfile = '0; //fprdata[2];

    // ----------------------
    // Registers (ID <-> EX)
    // ----------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            operand_a_q           <= '{default: 0};
            operand_b_q           <= '{default: 0};
            imm_q                 <= '0;
            fu_q                  <= ariane_pkg::NONE;
            operator_q            <= ariane_pkg::ADD;
            trans_id_q            <= '0;
            pc_o                  <= '0;
            is_compressed_instr_o <= 1'b0;
            branch_predict_o      <= {ariane_pkg::cf_t'(0), 64'd0};
            
        end else begin
            operand_a_q           <= operand_a_n;
            operand_b_q           <= operand_b_n;
            imm_q                 <= imm_n;
            fu_q                  <= fu_n;
            operator_q            <= operator_n;
            trans_id_q            <= trans_id_n;
            pc_o                  <= decoded_instr_i.pc;
            is_compressed_instr_o <= decoded_instr_i.is_compressed;
            branch_predict_o      <= decoded_instr_i.bp;
        end
    end

    // Only for tracing purposes

    //pragma translate_off
    `ifndef VERILATOR
    logic [4:0] rs1_register_trace; 
    logic [4:0] rs2_register_trace; 
    logic [4:0] rs3_register_trace; 
    logic [4:0] rd_register_trace; 
    
    always_ff @(posedge clk_i) begin
      rs1_register_trace <= rs1_register;
      rs2_register_trace <= rs2_register;
      rs3_register_trace <= rs3_register;
      rd_register_trace <= rd_register;
    end
    `endif
    //pragma translate_on
  
/*

  //pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (ariane_pkg::NR_ROB_ENTRIES == 2**ariane_pkg::TRANS_ID_BITS-) else $fatal("ROB size needs to be a power of two.");
  end

  // assert that zero is never set
  //assert property (
   // @(posedge clk_i) disable iff (!rst_ni) (rd_clobber_gpr_o[0] == ariane_pkg::NONE))
   // else $fatal (1,"RD 0 should not bet set");
  // assert that we never acknowledge a commit if the instruction is not valid
  assert property (
    @(posedge clk_i) disable iff (!rst_ni) commit_ack_i[0] |-> commit_instr_o[0].valid)
    else $fatal (1,"Commit acknowledged but instruction is not valid");

  assert property (
    @(posedge clk_i) disable iff (!rst_ni) commit_ack_i[1] |-> commit_instr_o[1].valid)
    else $fatal (1,"Commit acknowledged but instruction is not valid");

  // assert that we never give an issue ack signal if the instruction is not valid
  assert property (
    @(posedge clk_i) disable iff (!rst_ni) execution_is_possible |-> issue_instr_valid_o)
    else $fatal (1,"Issue acknowledged but instruction is not valid");

  // there should never be more than one instruction writing the same destination register (except x0)
  // check that no functional unit is retiring with the same transaction id
  for (genvar i = 0; i < NR_WB_PORTS; i++) begin
    for (genvar j = 0; j < NR_WB_PORTS; j++)  begin
      assert property (
        @(posedge clk_i) disable iff (!rst_ni) wt_valid_i[i] && wt_valid_i[j] && (i != j) |-> (trans_id_i[i] != trans_id_i[j]))
        else $fatal (1,"Two or more functional units are retiring instructions with the same transaction id!");
    end
  end
  `endif
  //pragma translate_on
  */
  
endmodule
