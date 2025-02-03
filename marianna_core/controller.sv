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
// Author: Marco Sabatano, Hensoldt Cyber 
// TODO: clarify license conditions on modified/rewritten files. 
// Date: Jan 2021 
// Description: Flush controller as FSM


module controller import ariane_pkg::*; (
    input  logic            clk_i,
    input  logic            rst_ni,
    
    // Registered outputs, we need to avoid all possible combinatorial paths backpropagating through the ctrl
    output logic            flush_misbranch_instr_o,// Flush speculative instruction due to misprediction everywhere they are
    output logic            flush_if_o,             // Flush the IF stage
    output logic            flush_id_o,             // Flush ID stage
    output logic            flush_issue_o,          // Flush the Issue stage
    output logic            flush_ex_o,             // Flush EX stage
    output logic            flush_re_order_buffer_o,// Flush re-order buffer 
    output logic            flush_bp_o,             // Flush branch predictors
    output logic            flush_icache_o,         // Flush ICache
    output logic            flush_dcache_o,         // Flush DCache
    output logic            flush_tlb_command_o,    // Flush TLBs (SFENCE_VMA logic)
	output logic            flush_tlb_all_o,        // Flush any state of the TLB AND related logic
    output logic            flush_caches_and_internal_states_o, //Flush dcache and any state of related logic
    output logic            ex_valid_o, 
    output logic            eret_o, 
    output logic [riscv::VLEN-1:0] epc_o,              // exception PC which we need to return to
    output logic            set_pc_ctrl_o,        // Set PC om PC Gen
    output logic            set_debug_pc_o,        // Set PC om PC Gen
    output logic [riscv::VLEN-1:0] pc_o,              // exception PC which we need to return to
    output riscv::bp_resolve_t     resolved_branch_o, 

    // Not registered output
    output logic            halt_o,                 // Halt signal to commit stage

    // Inputs
    //FROM commit stage
    input logic [riscv::VLEN-1:0] pc_commit_i,      // exception PC which we need to return to 
    input  logic            wfi_set_i,                  // We received a wait for interrupt instruction
    input  logic            wfi_reset_i,
    input  logic            ex_valid_i,             // We got an exception, flush the pipeline, output of commit stage
    input  logic            fence_i_i,              // fence.i in, from commit stage
    input  logic            fence_i,                // fence in, from commit stage
    input  logic            fence_t_i,              // fence.t in, from commit stage
    input  logic            sfence_vma_i,           // We got an instruction to flush the TLBs and pipeline, from commit stage
    input  logic            flush_commit_i,         // Flush request from commit stage, from commit stage
    
    //FROM CSR
    input  logic            eret_i,                 // Return from exception, output of csr block also in input to frontend 
    input  logic [riscv::VLEN-1:0] epc_i,              // exception PC which we need to return to
    input  logic            set_debug_pc_i,         // set the debug pc from CSR, output csr also input at fronted
    input  logic            flush_csr_i,            // We got an instruction which altered the CSR, flush the pipeline, from CSR 
    
    //FROM EX_STAGE
    input  riscv::bp_resolve_t     resolved_branch_i,      // We got a resolved branch, check if we need to flush the front-end , it coming from ex_stage so we can change flux of execution as soon as we see we are executing wrong instructions... 
    
    //FROM Caches
    input  logic            flush_caches_ack_i     // Acknowledge of the completion icache and dcache flush command, in case the used cached flush always in one clock cycle it can be tied to '1'
    
);

    logic [riscv::VLEN-1:0] epc_d, epc_q;
    logic [riscv::VLEN-1:0] commit_pc_d, commit_pc_q;
    bp_resolve_t    resolved_branch_q;
    
    enum logic [3:0] { PREINIT, INIT,IDLE, MISBRANCH, FENCE, FENCE_I, FENCE_T, SFENCE_VMA, FLUSHCSRorCOMMIT, EXCEPTION, DEBUG, ERET, WFI_FLUSH } state_d, state_q;
    logic halt_fsm; 
    logic sample_commit_pc;
    logic fence_t_state;  // this signal has no utility, is just to support the fence_t rtl test... it will be simplified by the synthetizer 

    assign resolved_branch_o.valid = resolved_branch_q.valid;
    assign resolved_branch_o.pc = resolved_branch_q.pc;
    assign resolved_branch_o.target_address = resolved_branch_q.target_address;
    assign resolved_branch_o.is_taken = resolved_branch_q.is_taken;
    assign resolved_branch_o.cf_type = resolved_branch_q.cf_type;
    assign resolved_branch_o.trans_id = resolved_branch_q.trans_id;
       

    assign halt_o = halt_fsm; 
    assign epc_o = epc_q;

    assign sample_commit_pc = (state_q == IDLE);     
    assign commit_pc_d = (sample_commit_pc)? pc_commit_i : commit_pc_q; 
    assign pc_o = commit_pc_q;

    
    always_comb begin
        
        state_d = state_q;
        set_pc_ctrl_o        = 1'b0;
        set_debug_pc_o = 1'b0;
        flush_if_o             = 1'b0;
        flush_misbranch_instr_o = 1'b0;
        flush_id_o             = 1'b0;
        flush_issue_o = 1'b0; 
        flush_ex_o             = 1'b0;
        flush_re_order_buffer_o = 1'b0; 
        flush_dcache_o           = 1'b0;
        flush_icache_o         = 1'b0;
        flush_tlb_command_o            = 1'b0;
        flush_bp_o             = 1'b0;
        flush_caches_and_internal_states_o    = 1'b0;
        flush_tlb_all_o = 1'b0;
        ex_valid_o             = 1'b0;  
        halt_fsm = 1'b0; 
        eret_o                 = 1'b0;
        epc_d = epc_q;
        resolved_branch_o.is_mispredict = 1'b0; 
        fence_t_state = 1'b0; 
        

        case (state_q)
            PREINIT: 
            begin
                state_d = INIT; 
            end

            INIT:
            begin
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o          = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_re_order_buffer_o = 1'b1; 
                flush_tlb_all_o     = 1'b1;
                flush_bp_o             = 1'b1;
                flush_misbranch_instr_o = 1'b1;
                //flush_caches_and_internal_states_o = 1'b1; // TODO: Marco Sabatano: when activating the cache resets upon INIT some test is failing... should we investigate why? the cache reset in INIT is not really needed, but could it be a syntomp that cache invalidation is not working properly? further test needed
                //if (flush_caches_ack_i)
                    state_d = IDLE;
		    end
            IDLE: 
            begin
                if (set_debug_pc_i) 
                begin
                    state_d = DEBUG;
                end
                else if (ex_valid_i) 
                begin
                    state_d = EXCEPTION;
                end
                else if (eret_i)
                begin
                    state_d = ERET;
                    epc_d = epc_i;
                end
                else 
                    begin 
                        if (flush_csr_i || flush_commit_i)
                        begin
                            state_d = FLUSHCSRorCOMMIT;
                        end
                        else 
                        begin

                            if (wfi_set_i)
                            begin
                                state_d = WFI_FLUSH;  
                            end

                            if (fence_i) 
                            begin
                                state_d = FENCE;
                            end 

                            if (fence_i_i)
                            begin
                                state_d = FENCE_I;
                            end 
                            if (sfence_vma_i)
                            begin
                                state_d = SFENCE_VMA;
                            end 

                            if (fence_t_i)
                            begin
                                state_d = FENCE_T;
                            end 
                            
                            if (~(wfi_set_i|fence_i|fence_i_i|sfence_vma_i|fence_t_i) & resolved_branch_i.is_mispredict)
                            begin
                                state_d = MISBRANCH;
                            end 
                        
                        end
                    end   

            end

            FENCE: 
            begin
                halt_fsm = 1'b1;  
                set_pc_ctrl_o        = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_re_order_buffer_o = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_dcache_o = 1'b1;
                if (flush_caches_ack_i)
                    state_d = IDLE;
                 
            end
          
            FENCE_I: 
            begin
                halt_fsm = 1'b1;  
                set_pc_ctrl_o        = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_re_order_buffer_o = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_icache_o         = 1'b1;
                flush_dcache_o = 1'b1;         // The DCACHE must be also flushed to enforce coherency between I$ and D$ 
                if (flush_caches_ack_i)
                    state_d = IDLE;

            end
          
            FENCE_T: 
            begin
                halt_fsm = 1'b1;
                set_pc_ctrl_o        = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_re_order_buffer_o = 1'b1; 
                flush_bp_o             = 1'b1;
                flush_tlb_all_o = 1'b1; 
                flush_caches_and_internal_states_o = 1'b1;
                fence_t_state = 1'b1; 
                if (flush_caches_ack_i)
                    state_d = IDLE;
            end
          
            SFENCE_VMA: 
            begin
              halt_fsm = 1'b1;
              set_pc_ctrl_o        = 1'b1;
              flush_if_o             = 1'b1;
              flush_id_o             = 1'b1;
              flush_issue_o          = 1'b1; 
              flush_ex_o             = 1'b1;
              flush_tlb_command_o    = 1'b1;
              flush_re_order_buffer_o = 1'b1; 
              state_d = IDLE;  
            end
          
            FLUSHCSRorCOMMIT: 
            begin
                halt_fsm = 1'b1;
                set_pc_ctrl_o        = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_ex_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_re_order_buffer_o = 1'b1; 
                state_d = IDLE;  
            end
          
            MISBRANCH: 
            begin
              flush_misbranch_instr_o = 1'b1; // flush speculative instructions due to the recognized misprediction
              flush_if_o             = 1'b1;
              flush_id_o             = 1'b1;
              resolved_branch_o.is_mispredict = 1'b1;  // We send the misspredict outside only if i am serving the misbranch (otherwise it would be anyway flushed)

              // if there is an exception while processing a misbranch, serve it immediately
              // otherwise the exception_o signal generated by commit_stage could last too long and 
              // this could cause a double update of the mstatus.mpp register
              if (set_debug_pc_i) 
              begin
                  state_d = DEBUG;
              end
              else if (ex_valid_i) 
              begin
                state_d = EXCEPTION;
              end
              else begin
                state_d = IDLE; 
              end
            end

            ERET: 
            begin
              halt_fsm = 1'b1;
              flush_if_o             = 1'b1;
              flush_id_o             = 1'b1;
              flush_ex_o             = 1'b1;
              flush_issue_o = 1'b1; 
              flush_re_order_buffer_o = 1'b1; 
              eret_o                 = 1'b1; 
              state_d = IDLE; 
            end

            EXCEPTION: 
            begin
              halt_fsm = 1'b1;
              flush_if_o             = 1'b1;
              flush_id_o             = 1'b1;
              flush_issue_o = 1'b1; 
              flush_ex_o             = 1'b1;
              flush_re_order_buffer_o = 1'b1; 
              ex_valid_o             = 1'b1;  
              state_d = IDLE; 
            end

            DEBUG:
            begin
                set_debug_pc_o = 1'b1;
                halt_fsm = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_re_order_buffer_o = 1'b1; 
                ex_valid_o             = 1'b1;  
                state_d = IDLE; 
              end
  
            WFI_FLUSH: 
            begin 
                halt_fsm = 1'b1;
                set_pc_ctrl_o        = 1'b1;
                flush_if_o             = 1'b1;
                flush_id_o             = 1'b1;
                flush_issue_o = 1'b1; 
                flush_ex_o             = 1'b1;
                flush_re_order_buffer_o = 1'b1; 
              
                if (wfi_reset_i)
                    state_d = IDLE; 
            end 
          
            default : 
                state_d = IDLE; 
        endcase
    end


    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q <= PREINIT;
            epc_q <= '0;
            commit_pc_q <= '0; 
            resolved_branch_q <= '0;
        end else begin
            state_q <= state_d;
            epc_q <= epc_d;
            commit_pc_q <= commit_pc_d;
            resolved_branch_q <= resolved_branch_i;  
        end
    end


endmodule
