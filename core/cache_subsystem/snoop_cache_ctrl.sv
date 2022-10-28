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
   output logic                          invalidate_o,
    // return
   input logic                           miss_gnt_i,
   input logic                           active_serving_i, // the miss unit is currently active for this unit, serving the miss
    // check MSHR for aliasing
   output logic [55:0]                   mshr_addr_o,
   input logic                           mshr_addr_matches_i,
   input logic                           mshr_index_matches_i
);

  enum                                   logic [2:0]
       {
        IDLE, // 0
        SEND_REQ, // 1
        WAIT_GNT, // 2
        SEND_CR_RESP, // 3
        SEND_CD_RESP, // 4
        WAIT_MH, // 5
        SEND_ACK, // 6
        SEND_NACK // 7
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
  // the snoop_cache_ctrl only makes read requests
  assign data_o = '0;
  assign be_o   = '0;
  assign we_o   = '0;

  logic [DCACHE_SET_ASSOC-1:0]           hit_way_d, hit_way_q;

  logic [63:0]                           cache_data_d, cache_data_q;
  logic [DCACHE_LINE_WIDTH-1:0]          cl_i;

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

  // FSM

  always_comb begin : cache_ctrl_fsm

    state_d   = state_q;
    mem_req_d = mem_req_q;
    cache_data_d = cache_data_q;
    hit_way_d = hit_way_q;

    snoop_port_o.ac_ready = 1'b0;
    snoop_port_o.cr_valid = 1'b0;
    snoop_port_o.cd_valid = 1'b0;
    snoop_port_o.cr_resp = '0;
    snoop_port_o.cd = '0;

    miss_req_o    = '0;
    mshr_addr_o   = '0;

    req_o  = '0;

    invalidate_o = '0;

    case (state_q)

      IDLE: begin
        snoop_port_o.ac_ready = 1'b1;

        // we receive a snooping request
        if (snoop_port_i.ac_valid) begin
          // save the request details
          mem_req_d.index = snoop_port_i.ac.addr[DCACHE_INDEX_WIDTH-1:0];
          mem_req_d.tag = snoop_port_i.ac.addr[DCACHE_INDEX_WIDTH+:DCACHE_TAG_WIDTH];
          if (bypass_i) begin
            state_d = SEND_ACK;
          end
          else begin
            // invalidate request
            if (snoop_port_i.ac.snoop == snoop_pkg::CLEAN_INVALID) begin
              state_d = WAIT_MH;
            end
            // read request
            else if (snoop_port_i.ac.snoop == snoop_pkg::READ_SHARED || snoop_port_i.ac.snoop == snoop_pkg::READ_ONCE) begin
              state_d = WAIT_GNT;
              // request the cache line
              req_o = '1;
            end
            // wrong request
            else begin
              state_d = SEND_NACK;
            end
          end
        end
      end

      WAIT_GNT: begin
        req_o = '1;
        if (gnt_i)
          state_d = SEND_CR_RESP;
      end

      SEND_CR_RESP: begin
        snoop_port_o.cr_valid = 1'b1;
        // Hit: transfer the data
        if (|hit_way_i) begin
          snoop_port_o.cr_resp.dataTransfer = 1'b1;
          snoop_port_o.cr_resp.passDirty = dirty;
          snoop_port_o.cr_resp.isShared = shared;
          case (mem_req_q.index[3])
            1'b0: cache_data_d = cl_i[63:0];
            1'b1: cache_data_d = cl_i[127:64];
          endcase
          if (snoop_port_i.cr_ready)
            state_d = SEND_CD_RESP;
        end
        // Miss
        else begin
          if (snoop_port_i.cr_ready)
            state_d = IDLE;
        end
      end

      SEND_CD_RESP: begin
        snoop_port_o.cd_valid = 1'b1;
        snoop_port_o.cd.data = cache_data_q;
        snoop_port_o.cd.last = 1'b1;
        if (snoop_port_i.cd_ready)
          state_d = IDLE;
      end

      WAIT_MH: begin
        miss_req_o.valid = 1'b1;
        miss_req_o.addr = {mem_req_q.tag, mem_req_q.index};
        miss_req_o.size = mem_req_q.size;
        invalidate_o = 1'b1;

        if (miss_gnt_i)
          state_d = SEND_ACK;
      end

      SEND_ACK: begin
        snoop_port_o.cr_valid = 1'b1;
        if (snoop_port_i.cr_ready)
          state_d = IDLE;
      end

      SEND_NACK: begin
        snoop_port_o.cr_valid = 1'b1;
        snoop_port_o.cr_resp.error = 1'b1;
        if (snoop_port_i.cr_ready)
          state_d = IDLE;
      end
    endcase
  end

  // Registers

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q       <= IDLE;
      mem_req_q     <= '0;
      cache_data_q  <= '0;
      hit_way_q     <= '0;
    end else begin
      state_q   <= state_d;
      mem_req_q <= mem_req_d;
      cache_data_q <= cache_data_d;
      hit_way_q <= hit_way_d;
    end
  end

endmodule
