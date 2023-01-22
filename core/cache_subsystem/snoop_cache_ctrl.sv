// Copyright 2022 PlanV GmbH
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Description: cache controller, driven by incoming snoop requests

module snoop_cache_ctrl import ariane_pkg::*; import std_cache_pkg::*; #(
    parameter ariane_cfg_t ArianeCfg = ArianeDefaultConfig // contains cacheable regions
) (
   input logic                           clk_i, // Clock
   input logic                           rst_ni, // Asynchronous reset active low
   input logic                           flush_i,
   input logic                           bypass_i, // enable cache
   output logic                          busy_o,
    // Snoop interface
   input                                 ariane_ace::snoop_req_t snoop_port_i,
   output                                ariane_ace::snoop_resp_t snoop_port_o,
    // SRAM interface
   output logic [DCACHE_SET_ASSOC-1:0]   req_o, // req is valid
   output logic [DCACHE_INDEX_WIDTH-1:0] addr_o, // address into cache array
   input logic                           gnt_i,
   output                                cache_line_t data_o,
   output                                cl_be_t be_o,
   output logic [DCACHE_TAG_WIDTH-1:0]   tag_o, //valid one cycle later
   input                                 cache_line_t [DCACHE_SET_ASSOC-1:0] data_i,
   output logic                          we_o,
   input logic [DCACHE_SET_ASSOC-1:0]    hit_way_i,
   input logic [DCACHE_SET_ASSOC-1:0]    dirty_way_i,
   input logic [DCACHE_SET_ASSOC-1:0]    shared_way_i,
    // Miss handling
   output                                miss_req_t miss_req_o,
    // return
   input logic                           miss_gnt_i,
   input logic                           active_serving_i, // the miss unit is currently active for this unit, serving the miss
   // bypass ports
   input logic                           bypass_gnt_i,
   input logic                           bypass_valid_i,
    // check MSHR for aliasing
   output logic [55:0]                   mshr_addr_o,
   input logic                           mshr_addr_matches_i,
   input logic                           mshr_index_matches_i
);

  enum                                   logic [3:0]
       {
        IDLE, // 0
        SEND_REQ, // 1
        WAIT_GNT, // 2
        EVAL_FLAGS, // 3
        UPDATE_SHARED, // 4
        INVALIDATE, // 5
        SEND_CR_RESP, // 6
        SEND_CD_RESP, // 7
        WRITEBACK // 8
        } state_d, state_q;

  typedef struct                         packed {
    logic [DCACHE_INDEX_WIDTH-1:0]       index;
    logic [DCACHE_TAG_WIDTH-1:0]         tag;
    logic [1:0]                          size;
  } mem_req_t;

  mem_req_t mem_req_d, mem_req_q;

  assign busy_o = (state_q != IDLE);
  assign tag_o  = mem_req_d.tag;
  assign addr_o = mem_req_d.index;

  logic [DCACHE_SET_ASSOC-1:0]           hit_way_d, hit_way_q;
  logic [DCACHE_SET_ASSOC-1:0]           shared_way_d, shared_way_q;
  logic [DCACHE_SET_ASSOC-1:0]           dirty_way_d, dirty_way_q;

  logic [DCACHE_LINE_WIDTH-1:0]                           cache_data_d, cache_data_q;
  logic [DCACHE_LINE_WIDTH-1:0]          cl_i;
  logic                                  cacheline_word_sel_d, cacheline_word_sel_q;

  always_comb begin : way_select
    cl_i = '0;
    for (int unsigned i = 0; i < DCACHE_SET_ASSOC; i++)
      if (hit_way_i[i])
        cl_i = data_i[i].data;
  end

  logic dirty;

  assign dirty = |(dirty_way_i & hit_way_i);

  logic shared;

  assign shared = |(shared_way_i & hit_way_i);

  snoop_pkg::crresp_t cr_resp_d, cr_resp_q;

  snoop_pkg::acsnoop_t ac_snoop_d, ac_snoop_q;

  // FSM

  always_comb begin : cache_ctrl_fsm

    state_d   = state_q;
    mem_req_d = mem_req_q;
    cache_data_d = cache_data_q;
    cacheline_word_sel_d = cacheline_word_sel_q;
    hit_way_d = hit_way_q;
    shared_way_d = shared_way_q;
    dirty_way_d = dirty_way_q;
    cr_resp_d = cr_resp_q;
    ac_snoop_d = ac_snoop_q;

    snoop_port_o.ac_ready = 1'b0;
    snoop_port_o.cr_valid = 1'b0;
    snoop_port_o.cd_valid = 1'b0;
    snoop_port_o.cr_resp = '0;
    snoop_port_o.cd = '0;

    miss_req_o    = '0;
    mshr_addr_o   = '0;

    req_o  = '0;
    we_o = '0;
    be_o = '0;
    data_o = '0;

    case (state_q)

      IDLE: begin
        snoop_port_o.ac_ready = 1'b1;
        cr_resp_d = '0;
        ac_snoop_d = '0;
        cacheline_word_sel_d = 1'b0;

        // we receive a snooping request
        if (snoop_port_i.ac_valid) begin
          // save the request details
          mem_req_d.index = snoop_port_i.ac.addr[DCACHE_INDEX_WIDTH-1:0];
          mem_req_d.tag = snoop_port_i.ac.addr[DCACHE_INDEX_WIDTH+:DCACHE_TAG_WIDTH];
          mem_req_d.size = 2'b11;
          if (bypass_i) begin
            state_d = SEND_CR_RESP;
          end
          else begin
            // invalidate request
            if (snoop_port_i.ac.snoop == snoop_pkg::CLEAN_INVALID) begin
              state_d = WAIT_GNT;
              ac_snoop_d = snoop_port_i.ac.snoop;
              // request the cache line
              req_o = '1;
            end
            // read request
            else if (snoop_port_i.ac.snoop == snoop_pkg::READ_SHARED || snoop_port_i.ac.snoop == snoop_pkg::READ_ONCE || snoop_port_i.ac.snoop == snoop_pkg::READ_UNIQUE) begin
              state_d = WAIT_GNT;
              ac_snoop_d = snoop_port_i.ac.snoop;
              // request the cache line
              req_o = '1;
            end
            // wrong request
            else begin
              state_d = SEND_CR_RESP;
              cr_resp_d.error = 1'b1;
            end
          end
        end
      end

      WAIT_GNT: begin
        req_o = '1;
        if (gnt_i)
          state_d = EVAL_FLAGS;
      end

      EVAL_FLAGS: begin
        hit_way_d = hit_way_i;
        shared_way_d = shared_way_i;
        dirty_way_d = dirty_way_i;
        if (|hit_way_i) begin
          cr_resp_d.dataTransfer = 1'b1;
          cr_resp_d.passDirty = dirty;
          cr_resp_d.isShared = shared;
          cache_data_d = cl_i;
          case (ac_snoop_q)
            snoop_pkg::CLEAN_INVALID: begin
              cr_resp_d.dataTransfer = 1'b0;
              cr_resp_d.passDirty = 1'b0;
              cr_resp_d.isShared = 1'b0;
              state_d = INVALIDATE;
            end
            snoop_pkg::READ_ONCE: begin
              state_d = SEND_CR_RESP;
            end
            snoop_pkg::READ_SHARED: begin
              state_d = UPDATE_SHARED;
            end
            snoop_pkg::READ_UNIQUE: begin
              state_d = INVALIDATE;
            end
          endcase
        end
        // Miss
        else begin
          cr_resp_d.dataTransfer = 1'b0;
          cr_resp_d.passDirty = 1'b0;
          cr_resp_d.isShared = 1'b0;
          state_d = SEND_CR_RESP;
        end
      end

        UPDATE_SHARED: begin
          req_o      = hit_way_q;
          we_o       = 1'b1;
          be_o.vldrty = hit_way_q;
          // leave data be to 0 - don't overwrite
          be_o.data = 0;
//          data_o.data = cache_data_q;
          // keep dirty flag as it was
          data_o.dirty = |(dirty_way_q & hit_way_q);
          // must be valid, otherwise we wouldn't be here
          data_o.valid = 1'b1;
          // change shared the state
          data_o.shared = 1'b1;
          if (gnt_i) begin
            state_d = SEND_CR_RESP;
          end
        end

      INVALIDATE: begin
        req_o      = hit_way_q;
        we_o       = 1'b1;
        be_o.vldrty = hit_way_q;
        data_o.dirty = 1'b0;
        data_o.valid = 1'b0;
        data_o.shared = 1'b0;
        // valid = 0, invalidate = 1 signals an incoming ReadUnique to the miss_handler
        // we are not blocked by the miss_handler here
        miss_req_o.valid = 1'b0;
        miss_req_o.invalidate = 1'b1;
        miss_req_o.addr = {mem_req_q.tag, mem_req_q.index};
        miss_req_o.size = mem_req_q.size;
        if (gnt_i) begin
          if ((hit_way_q & dirty_way_q) && ac_snoop_q == snoop_pkg::CLEAN_INVALID)
            state_d = WRITEBACK;
          else
            state_d = SEND_CR_RESP;
        end
      end

      SEND_CR_RESP: begin
        snoop_port_o.cr_valid = 1'b1;
        snoop_port_o.cr_resp.dataTransfer = cr_resp_q.dataTransfer;
        snoop_port_o.cr_resp.passDirty = cr_resp_q.passDirty;
        snoop_port_o.cr_resp.isShared = cr_resp_q.isShared;
        snoop_port_o.cr_resp.error = cr_resp_q.error;
        if (snoop_port_i.cr_ready) begin
          if (cr_resp_q.dataTransfer)
            state_d = SEND_CD_RESP;
          else
            state_d = IDLE;
        end
      end

      SEND_CD_RESP: begin
        snoop_port_o.cd_valid = 1'b1;
        snoop_port_o.cd.data = cacheline_word_sel_q ? cache_data_q[127:64] : cache_data_q[63:0];
        snoop_port_o.cd.last = cacheline_word_sel_q;
        if (snoop_port_i.cd_ready) begin
          if (cacheline_word_sel_q) begin
            state_d = IDLE;
          end
          cacheline_word_sel_d = ~cacheline_word_sel_q;
        end
      end

      WRITEBACK: begin
        // valid = invalidate = 1 signals an incoming cleaninvalid
        // we are not blocked by the miss_handler (invalidation is done here, and we use the bypass port), to avoid a deadlock
        miss_req_o.bypass = 1'b1;
        miss_req_o.valid = 1'b1;
        miss_req_o.invalidate = 1'b1;
        miss_req_o.we = 1'b1;
        miss_req_o.addr = cacheline_word_sel_q ? {mem_req_q.tag, mem_req_q.index + 12'h8} : {mem_req_q.tag, mem_req_q.index};
        miss_req_o.size = mem_req_q.size;
        miss_req_o.wdata = cacheline_word_sel_q ? cache_data_q[127:64] : cache_data_q[63:0];
        if (bypass_gnt_i) begin
          cacheline_word_sel_d = ~cacheline_word_sel_q;
        end
        if (!cacheline_word_sel_q & bypass_valid_i)
          state_d = SEND_CR_RESP;
      end
    endcase
  end

  // Registers

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q       <= IDLE;
      mem_req_q     <= '0;
      cache_data_q  <= '0;
      cacheline_word_sel_q <= 1'b0;
      hit_way_q     <= '0;
      shared_way_q     <= '0;
      dirty_way_q     <= '0;
      cr_resp_q <= '0;
      ac_snoop_q <= '0;
    end else begin
      state_q   <= state_d;
      mem_req_q <= mem_req_d;
      cache_data_q <= cache_data_d;
      cacheline_word_sel_q <= cacheline_word_sel_d;
      hit_way_q <= hit_way_d;
      shared_way_q <= shared_way_d;
      dirty_way_q <= dirty_way_d;
      cr_resp_q <= cr_resp_d;
      ac_snoop_q <= ac_snoop_d;
    end
  end

endmodule
