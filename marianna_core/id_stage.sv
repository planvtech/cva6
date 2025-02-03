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
// Date: 15.04.2017
// Description: Instruction decode, contains the logic for decode,
//              issue and read operands.

module id_stage #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    input  logic                          flush_i,
    input  logic                          flush_issue_i,
    input  logic                          flush_misbranch_instr_i, 
    input  logic                          debug_req_i,
    input  logic [CVA6Cfg.TRANS_ID_BITS-1:0]      branch_trans_id,
    // from IF
    input  riscv::fetch_entry_t      fetch_entry_i,
    input  logic                          fetch_entry_valid_i,
    output logic                          fetch_entry_ready_o, // acknowledge the instruction (fetch entry)
    // to ID
    output riscv::id_entry_t         issue_entry_o,       // a decoded instruction
    output logic                          issue_entry_valid_o, // issue entry is valid
    output logic                          is_ctrl_flow_o,      // the instruction we issue is a ctrl flow instructions
    input  logic                          issue_instr_ack_i,   // issue stage acknowledged sampling of instructions
    
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] rs1_transID_reference_o, 
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] rs2_transID_reference_o,
     
    // from CSR file
    input  riscv::priv_lvl_t              priv_lvl_i,          // current privilege level
    input  riscv::xs_t                    fs_i,                // floating point extension status
    input  logic [2:0]                    frm_i,               // floating-point dynamic rounding mode
    input  logic [1:0]                    irq_i,
    input  riscv::irq_ctrl_t         irq_ctrl_i,
    input  logic                          debug_mode_i,        // we are in debug mode
    input  logic                          tvm_i,
    input  logic                          tw_i,
    input  logic                          tsr_i
);
    // ID/ISSUE register stage
    struct packed {
        logic                          valid;
        ariane_pkg::id_entry_t sbe;
        logic                          is_ctrl_flow;
    } issue_n, issue_q;

    typedef struct packed {
        logic   [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
        logic   [4:0]               rd;

    } rd_trans_id_storing_fifo_entry;

    rd_trans_id_storing_fifo_entry rd_trans_id_fifo_n, rd_trans_id_fifo_q; 
    

    logic                            is_control_flow_instr;
    ariane_pkg::id_entry_t   decoded_instruction;

    logic [CVA6Cfg.TRANS_ID_BITS-1:0] rs1_transID_reference_q,rs1_transID_reference_n;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] rs2_transID_reference_q,rs2_transID_reference_n;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] nextInstr_TransID_n,  nextInstr_TransID_q;
    logic [31:0] [CVA6Cfg.TRANS_ID_BITS-1:0] ID_rd_to_transID_q, ID_rd_to_transID_n; 
    
    logic                is_illegal;
    logic                [31:0] instruction;
    logic                is_compressed;
    logic reset_num_speculative_instr;

    // ---------------------------------------------------------
    // 1. Check if they are compressed and expand in case they are
    // ---------------------------------------------------------
    compressed_decoder compressed_decoder_i (
        .instr_i                 ( fetch_entry_i.instruction   ),
        .instr_o                 ( instruction                 ),
        .illegal_instr_o         ( is_illegal                  ),
        .is_compressed_o         ( is_compressed               )
    );
    // ---------------------------------------------------------
    // 2. Decode and emit instruction to issue stage
    // ---------------------------------------------------------
    decoder decoder_i (
        .debug_req_i,
        .irq_ctrl_i,
        .irq_i,
        .pc_i                    ( fetch_entry_i.address           ),
        .is_compressed_i         ( is_compressed                   ),
        .is_illegal_i            ( is_illegal                      ),
        .instruction_i           ( instruction                     ),
        .compressed_instr_i      ( fetch_entry_i.instruction[15:0] ),
        .branch_predict_i        ( fetch_entry_i.branch_predict    ),
        .ex_i                    ( fetch_entry_i.ex                ),
        .priv_lvl_i              ( priv_lvl_i                      ),
        .debug_mode_i            ( debug_mode_i                    ),
        .fs_i,
        .frm_i,
        .tvm_i,
        .tw_i,
        .tsr_i,
        .instruction_o           ( decoded_instruction          ),
        .is_control_flow_instr_o ( is_control_flow_instr        )
    );

    // ------------------
    // Pipeline Register
    // ------------------
    logic [2:0] num_speculative_instr_n, num_speculative_instr_q;
    assign issue_entry_o = issue_q.sbe;
    assign issue_entry_valid_o = issue_q.valid & ~(flush_misbranch_instr_i|flush_i);
    assign is_ctrl_flow_o = issue_q.is_ctrl_flow;
    
    always_comb begin
      
        issue_n     = issue_q;
        fetch_entry_ready_o = 1'b0;
        rs1_transID_reference_n = rs1_transID_reference_q;
        rs2_transID_reference_n = rs2_transID_reference_q;
        nextInstr_TransID_n = nextInstr_TransID_q; 
        num_speculative_instr_n = num_speculative_instr_q; 
        
        // Clear the valid flag if issue has acknowledged the instruction
        if (issue_instr_ack_i)
        begin 
            issue_n.valid = 1'b0;
        end 

        
        if (flush_misbranch_instr_i)
        begin 
            nextInstr_TransID_n = branch_trans_id + 1;
            num_speculative_instr_n = nextInstr_TransID_q - (branch_trans_id + 1); 
        end 
        else 
            if (issue_instr_ack_i)
                nextInstr_TransID_n = nextInstr_TransID_q + 1;

        if (reset_num_speculative_instr)
            num_speculative_instr_n = '0;
            
        // if we have a space in the register and the fetch is valid, go get it
        // or the issue stage is currently acknowledging an instruction, which means that we will have space
        // for a new instruction
        if ((!issue_q.valid || issue_instr_ack_i) & fetch_entry_valid_i) begin // send istr to issue stage

            fetch_entry_ready_o = 1'b1;
            issue_n = '{~(flush_misbranch_instr_i|flush_i), decoded_instruction, is_control_flow_instr};
            issue_n.sbe.trans_id = nextInstr_TransID_n; 

            rs1_transID_reference_n = ID_rd_to_transID_q[decoded_instruction.rs1];  
            rs2_transID_reference_n = ID_rd_to_transID_q[decoded_instruction.rs2];

            if ((decoded_instruction.rs1 == issue_q.sbe.rd) & issue_q.valid) 
            begin 
                rs1_transID_reference_n = issue_q.sbe.trans_id;
            end
           
            if ((decoded_instruction.rs2 == issue_q.sbe.rd) & issue_q.valid) 
            begin 
                rs2_transID_reference_n = issue_q.sbe.trans_id; 
            end
            
        end
 
        // invalidate the pipeline register on a flush
        if (flush_i)
        begin 
            issue_n.valid = 1'b0;
        end 
    end
    // -------------------------
    // Registers (ID <-> Issue)
    // -------------------------

   

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            issue_q <= '0;
    
        end else begin
            issue_q <= issue_n;
        end
    end



    always_ff @(posedge clk_i or negedge rst_ni)
    begin 
        if (~rst_ni)
        begin 
            nextInstr_TransID_q <= '0; 
        end 
        else if (flush_issue_i)
        begin
            nextInstr_TransID_q <= '0;
        end
        else 
        begin 

            nextInstr_TransID_q <= nextInstr_TransID_n;
        
        end 

          

    end 


    always_ff @(posedge clk_i or negedge rst_ni)
    begin 
        if ( ~rst_ni )
        begin 

            // TODO: reset to review
            ID_rd_to_transID_q <= '0;
            rs1_transID_reference_q <= '0;
            rs2_transID_reference_q <= '0; 
            rd_trans_id_fifo_q <= '0; 
            num_speculative_instr_q <= '0; 

        end 
        else 
        begin

            ID_rd_to_transID_q <= ID_rd_to_transID_n; 
            rs1_transID_reference_q <= rs1_transID_reference_n; 
            rs2_transID_reference_q <= rs2_transID_reference_n;
            rd_trans_id_fifo_q <= rd_trans_id_fifo_n; 
            num_speculative_instr_q <= num_speculative_instr_n; 
        
        end 

          

    end 


    always_comb 
    begin 
      
        ID_rd_to_transID_n = ID_rd_to_transID_q;
        rd_trans_id_fifo_n = rd_trans_id_fifo_q; 
        reset_num_speculative_instr = 1'b0;
       
       
       
       
            if (issue_instr_ack_i & ~(flush_misbranch_instr_i|flush_i))  
            begin  

                ID_rd_to_transID_n[issue_q.sbe.rd] = issue_q.sbe.trans_id;
                rd_trans_id_fifo_n.trans_id = ID_rd_to_transID_q[issue_q.sbe.rd]; //storing the old entry 
                rd_trans_id_fifo_n.rd = issue_q.sbe.rd; //storing the old entry 

            end 

            if (num_speculative_instr_q[0]) // the number of speculative instr can be only 0 or 1 in the current architecture
            begin     
                ID_rd_to_transID_n[rd_trans_id_fifo_q.rd] = rd_trans_id_fifo_q.trans_id;
                reset_num_speculative_instr = 1'b1;
            end
        
    end 
    
    assign rs1_transID_reference_o = rs1_transID_reference_q;
    assign rs2_transID_reference_o = rs2_transID_reference_q;


endmodule

