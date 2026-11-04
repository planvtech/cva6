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
// Date: 22.05.2017
// Description: Store Unit, takes care of all store requests and atomic memory operations (AMOs)


module store_unit
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type ypb_store_req_t = logic,
    parameter type ypb_store_rsp_t = logic,
    parameter type ypb_amo_req_t = logic,
    parameter type ypb_amo_rsp_t = logic,
    parameter type exception_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type mmu_arsp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Flush - CONTROLLER
    input logic flush_i,
    // TO_BE_COMPLETED - ACC_DISPATCHER
    input logic stall_st_pending_i,
    // No store pending - COMMIT_STAGE
    output logic no_st_pending_o,
    // Store buffer is empty - LOAD_UNIT
    output logic store_buffer_empty_o,
    // Store instruction is valid - ISSUE_STAGE
    input logic valid_i,
    // Data input - ISSUE_STAGE
    input lsu_ctrl_t lsu_ctrl_i,
    // Pop store - LSU_BYPASS
    output logic pop_st_o,
    // Instruction commit - COMMIT_STAGE
    input logic commit_i,
    // Commit queue is ready to accept another commit request - COMMIT_STAGE
    output logic commit_ready_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic amo_valid_commit_i,
    // Data Endian mode - CSR_REGFILE
    input logic mbe_i,
    // Store result is valid - ISSUE_STAGE
    output logic valid_o,
    // Transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] result_o,
    // Store exception output - ISSUE_STAGE
    output exception_t ex_o,
    // Address translation request - MMU/PMP
    output logic translation_req_o,
    // Virtual address - MMU/PMP
    output logic [CVA6Cfg.VLEN-1:0] vaddr_o,
    // Transformed trap instruction out - TO_BE_COMPLETED
    output logic [31:0] tinst_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic hs_ld_st_inst_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic hlvx_inst_o,
    // Translation response of the request presented this cycle
    // (valid + paddr + exception), combinational - MMU/PMP
    input mmu_arsp_t arsp_i,
    // Address to be checked - load_unit
    input logic [11:0] page_offset_i,
    // Address check result - load_unit
    output logic page_offset_matches_o,
    // Store cache response - DCACHE
    output ypb_store_req_t ypb_store_req_o,
    // Store cache request - DCACHE
    input ypb_store_rsp_t ypb_store_rsp_i,
    // AMO request - DCACHE
    output ypb_amo_req_t ypb_amo_req_o,
    // AMO response - DCACHE
    input ypb_amo_rsp_t ypb_amo_rsp_i,
    //Trigger module
    input logic sdtrig_store_stall_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);

  // align data to address e.g.: shift data to be naturally 64
  function automatic [CVA6Cfg.XLEN-1:0] data_align(logic [2:0] addr, logic [63:0] data);
    // Set addr[2] to 1'b0 when 32bits
    logic [ 2:0] addr_tmp = {(addr[2] && CVA6Cfg.IS_XLEN64), addr[1:0]};
    logic [63:0] data_tmp = {64{1'b0}};
    case (addr_tmp)
      3'b000: data_tmp[CVA6Cfg.XLEN-1:0] = {data[CVA6Cfg.XLEN-1:0]};
      3'b001:
      data_tmp[CVA6Cfg.XLEN-1:0] = {data[CVA6Cfg.XLEN-9:0], data[CVA6Cfg.XLEN-1:CVA6Cfg.XLEN-8]};
      3'b010:
      data_tmp[CVA6Cfg.XLEN-1:0] = {data[CVA6Cfg.XLEN-17:0], data[CVA6Cfg.XLEN-1:CVA6Cfg.XLEN-16]};
      3'b011:
      data_tmp[CVA6Cfg.XLEN-1:0] = {data[CVA6Cfg.XLEN-25:0], data[CVA6Cfg.XLEN-1:CVA6Cfg.XLEN-24]};
      default:
      if (CVA6Cfg.IS_XLEN64) begin
        case (addr_tmp)
          3'b100:  data_tmp = {data[31:0], data[63:32]};
          3'b101:  data_tmp = {data[23:0], data[63:24]};
          3'b110:  data_tmp = {data[15:0], data[63:16]};
          3'b111:  data_tmp = {data[7:0], data[63:8]};
          default: data_tmp = {data[63:0]};
        endcase
      end
    endcase
    return data_tmp[CVA6Cfg.XLEN-1:0];
  endfunction

  // it doesn't matter what we are writing back as stores don't return anything
  assign result_o = lsu_ctrl_i.data;

  // directly forward exception fields (valid bit is set below)
  // A store trigger reports its own cause and the faulting address; otherwise
  // the exception of the translation response passes through unchanged.
  assign ex_o.cause = (CVA6Cfg.SdtrigMcontrol6Store && sdtrig_store_stall_i && valid_i) ? sdtrig_store_action_i : arsp_i.exception.cause;
  assign ex_o.tval  = (CVA6Cfg.SdtrigMcontrol6Store && sdtrig_store_stall_i && valid_i) ? {{CVA6Cfg.XLEN - CVA6Cfg.VLEN{1'b0}}, lsu_ctrl_i.vaddr} : arsp_i.exception.tval;
  assign ex_o.tval2 = CVA6Cfg.RVH ? arsp_i.exception.tval2 : '0;
  assign ex_o.tinst = CVA6Cfg.RVH ? arsp_i.exception.tinst : '0;
  assign ex_o.gva = CVA6Cfg.RVH ? arsp_i.exception.gva : 1'b0;
  // Store triggers are precise: they break on the instruction itself, never
  // after it, so the deferred-exception bit stays clear here.
  assign ex_o.timing = 1'b0;

  // store buffer control signals
  logic instr_is_amo;

  // -------------
  // Byte-Swapper
  // -------------
  // The byte order of what is about to be stored is reversed when the
  // processor is in big endian data mode.
  logic [CVA6Cfg.XLEN-1:0] endian_data;
  always_comb begin
    endian_data = lsu_ctrl_i.data;
    if (CVA6Cfg.BigEndianEn && mbe_i) begin
      case (lsu_ctrl_i.operation)
        ariane_pkg::SB, ariane_pkg::HSV_B, ariane_pkg::FSB:
        endian_data[7:0] = {lsu_ctrl_i.data[7:0]};
        ariane_pkg::SH, ariane_pkg::HSV_H, ariane_pkg::FSH:
        endian_data[15:0] = {<<8{lsu_ctrl_i.data[15:0]}};
        ariane_pkg::SW, ariane_pkg::HSV_W, ariane_pkg::FSW, ariane_pkg::AMO_LRW, ariane_pkg::AMO_SCW,
        ariane_pkg::AMO_SWAPW, ariane_pkg::AMO_ADDW, ariane_pkg::AMO_ANDW, ariane_pkg::AMO_ORW,
        ariane_pkg::AMO_XORW, ariane_pkg::AMO_MAXW, ariane_pkg::AMO_MINW, ariane_pkg::AMO_MAXWU,
        ariane_pkg::AMO_MINWU:
        endian_data[31:0] = {<<8{lsu_ctrl_i.data[31:0]}};
        default: endian_data[CVA6Cfg.XLEN-1:0] = {<<8{lsu_ctrl_i.data[CVA6Cfg.XLEN-1:0]}};
      endcase
    end
  end
  assign instr_is_amo = is_amo(lsu_ctrl_i.operation);

  // The translation response is combinational, so with or without an MMU a
  // store is translated, written to the store/AMO buffer and retired in the
  // cycle it is accepted: no data, address or valid is registered here.
  logic [CVA6Cfg.XLEN-1:0] st_data;
  logic [(CVA6Cfg.XLEN/8)-1:0] st_be;
  logic [1:0] st_data_size;
  amo_t amo_op;
  fu_op cbo_op;

  logic store_buffer_valid, store_buffer_valid_no_flush;
  logic amo_buffer_valid;
  logic store_buffer_ready, amo_buffer_ready;

  logic ex_s0;
  logic stall_translation;

  // output assignments
  assign vaddr_o = lsu_ctrl_i.vaddr;  // virtual address
  assign hs_ld_st_inst_o = CVA6Cfg.RVH ? lsu_ctrl_i.hs_ld_st_inst : 1'b0;
  assign hlvx_inst_o = CVA6Cfg.RVH ? lsu_ctrl_i.hlvx_inst : 1'b0;
  assign tinst_o = CVA6Cfg.RVH ? lsu_ctrl_i.tinst : '0;  // transformed instruction

  // As for the Frontend, a store is accepted only once its translation is
  // valid and clean. Without an MMU the response is valid with the request and
  // only a misaligned or PMP exception stalls it.
  assign stall_translation = translation_req_o && (!arsp_i.valid || arsp_i.exception.valid);

  // Translation exception: retired in the request cycle, the store is never
  // accepted, so it never reaches the store or AMO buffer.
  assign ex_s0 = translation_req_o && arsp_i.valid && arsp_i.exception.valid;

  always_comb begin : store_control
    // default assignment
    translation_req_o           = 1'b0;
    valid_o                     = 1'b0;
    amo_buffer_valid            = 1'b0;
    store_buffer_valid          = 1'b0;
    store_buffer_valid_no_flush = 1'b0;
    pop_st_o                    = 1'b0;
    ex_o.valid                  = 1'b0;
    trans_id_o                  = lsu_ctrl_i.trans_id;

    // A store trigger matched: retire the instruction as an exception without
    // letting it reach the store buffer, so the write never happens.
    if (CVA6Cfg.SdtrigMcontrol6Store && sdtrig_store_stall_i && valid_i) begin
      valid_o    = 1'b1;
      ex_o.valid = 1'b1;
      // REQUEST
    end else if (valid_i) begin
      translation_req_o = 1'b1;
      // RETIRE TRANSLATION EXCEPTION: the response holds while the store is
      // presented, so it is released once retired.
      if (ex_s0) begin
        valid_o    = 1'b1;
        ex_o.valid = 1'b1;
        pop_st_o   = 1'b1;
        // ACCEPT AND RETIRE STORE: written to the buffer in the same cycle
      end else if (!stall_translation) begin
        if (CVA6Cfg.RVA && instr_is_amo) begin
          if (amo_buffer_ready) begin
            pop_st_o         = 1'b1;
            amo_buffer_valid = !flush_i;
            valid_o          = 1'b1;
          end
        end else begin
          if (store_buffer_ready) begin
            pop_st_o                    = 1'b1;
            store_buffer_valid          = !flush_i;
            store_buffer_valid_no_flush = 1'b1;
            valid_o                     = 1'b1;
          end
        end
      end
    end
  end

  // -----------
  // Re-aligner
  // -----------
  // re-align the write data to comply with the address offset
  always_comb begin
    st_be = lsu_ctrl_i.be;
    // don't shift the data if we are going to perform an AMO as we still need to operate on this data
    st_data = ((CVA6Cfg.RVA && instr_is_amo) ? endian_data[CVA6Cfg.XLEN-1:0] :
               data_align(lsu_ctrl_i.vaddr[2:0], {{64 - CVA6Cfg.XLEN{1'b0}}, endian_data}));
    st_data_size = extract_transfer_size(lsu_ctrl_i.operation);
    if (CVA6Cfg.RVA) begin
      case (lsu_ctrl_i.operation)
        AMO_LRW, AMO_LRD:     amo_op = AMO_LR;
        AMO_SCW, AMO_SCD:     amo_op = AMO_SC;
        AMO_SWAPW, AMO_SWAPD: amo_op = AMO_SWAP;
        AMO_ADDW, AMO_ADDD:   amo_op = AMO_ADD;
        AMO_ANDW, AMO_ANDD:   amo_op = AMO_AND;
        AMO_ORW, AMO_ORD:     amo_op = AMO_OR;
        AMO_XORW, AMO_XORD:   amo_op = AMO_XOR;
        AMO_MAXW, AMO_MAXD:   amo_op = AMO_MAX;
        AMO_MAXWU, AMO_MAXDU: amo_op = AMO_MAXU;
        AMO_MINW, AMO_MIND:   amo_op = AMO_MIN;
        AMO_MINWU, AMO_MINDU: amo_op = AMO_MINU;
        default:              amo_op = AMO_NONE;
      endcase
    end else begin
      amo_op = AMO_NONE;
    end

    if (CVA6Cfg.RVZiCbom) begin
      case (lsu_ctrl_i.operation)
        ariane_pkg::CBO_INVAL: cbo_op = ariane_pkg::CBO_INVAL;
        ariane_pkg::CBO_CLEAN: cbo_op = ariane_pkg::CBO_CLEAN;
        ariane_pkg::CBO_FLUSH: cbo_op = ariane_pkg::CBO_FLUSH;
        default:               cbo_op = ariane_pkg::CBO_NONE;
      endcase
    end else begin
      cbo_op = ariane_pkg::CBO_NONE;
    end
  end

  // ---------------
  // Store Queue
  // ---------------
  store_buffer #(
      .CVA6Cfg(CVA6Cfg),
      .ypb_store_req_t(ypb_store_req_t),
      .ypb_store_rsp_t(ypb_store_rsp_t)
  ) store_buffer_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .stall_st_pending_i,
      .no_st_pending_o,
      .store_buffer_empty_o,
      .page_offset_i,
      .page_offset_matches_o,
      .commit_i,
      .commit_ready_o,
      .ready_o              (store_buffer_ready),
      .valid_i              (store_buffer_valid),
      // the flush signal can be critical and we need this valid
      // signal to check whether the page_offset matches or not,
      // functionally it doesn't make a difference whether we use
      // the correct valid signal or not as we are flushing
      // the whole pipeline anyway
      .valid_without_flush_i(store_buffer_valid_no_flush),
      .paddr_i              (arsp_i.paddr),
      .data_i               (st_data),
      .cbo_op_i             (cbo_op),
      .be_i                 (st_be),
      .data_size_i          (st_data_size),
      .ypb_store_req_o      (ypb_store_req_o),
      .ypb_store_rsp_i      (ypb_store_rsp_i)
  );

  if (CVA6Cfg.RVA) begin
    amo_buffer #(
        .CVA6Cfg(CVA6Cfg),
        .ypb_amo_req_t(ypb_amo_req_t),
        .ypb_amo_rsp_t(ypb_amo_rsp_t)
    ) i_amo_buffer (
        .clk_i,
        .rst_ni,
        .flush_i,
        .valid_i           (amo_buffer_valid),
        .ready_o           (amo_buffer_ready),
        .paddr_i           (arsp_i.paddr),
        .amo_op_i          (amo_op),
        .data_i            (st_data),
        .data_size_i       (st_data_size),
        .ypb_amo_req_o     (ypb_amo_req_o),
        .ypb_amo_rsp_i     (ypb_amo_rsp_i),
        .amo_valid_commit_i(amo_valid_commit_i),
        .no_st_pending_i   (no_st_pending_o)
    );
  end else begin
    assign amo_buffer_ready = '1;
    assign ypb_amo_req_o    = '0;
  end

endmodule
