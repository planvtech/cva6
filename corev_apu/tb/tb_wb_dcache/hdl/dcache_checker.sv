// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright 2022 PlanV GmbH

// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "tb.svh"

module dcache_checker import ariane_pkg::*; import std_cache_pkg::*; import tb_pkg::*;
  #(
    parameter int unsigned NR_CPU_PORTS = 3,
    parameter CACHE_BASE_ADDR = 64'h8000_0000
    )
  (
   input logic  clk_i,
   input logic  rst_ni,
   input logic start_transaction_i,
   output logic check_done_o,
   input        ariane_pkg::dcache_req_i_t[NR_CPU_PORTS-1:0] req_ports_i,
   input        ariane_pkg::dcache_req_o_t[NR_CPU_PORTS-1:0] req_ports_o,
   input        ariane_ace::m2s_nosnoop_t axi_data_o,
   input        ariane_ace::s2m_nosnoop_t axi_data_i,
   input        ariane_ace::m2s_nosnoop_t axi_bypass_o,
   input        ariane_ace::s2m_nosnoop_t axi_bypass_i,
   input        ariane_ace::snoop_req_t snoop_req_i,
   input        ariane_ace::snoop_resp_t snoop_resp_o
   );

  typedef enum  int {RD_REQ, WR_REQ, SNOOP_REQ} type_t;

  typedef struct packed {
    type_t req_type;
    logic [63:0] addr;
    logic [DCACHE_INDEX_WIDTH-1:0] index;
    logic [DCACHE_TAG_WIDTH-1:0]   tag;
    logic [DCACHE_INDEX_WIDTH-DCACHE_BYTE_OFFSET-1:0] mem_idx;
    logic [$clog2(NR_CPU_PORTS)-1:0]                  active_port;
    snoop_pkg::acsnoop_t snoop_type;
  } current_req_t;

  // Cache model

  cache_line_t [DCACHE_NUM_WORDS-1:0][DCACHE_SET_ASSOC-1:0] cache_status;

  // Signals

  logic [$clog2(DCACHE_SET_ASSOC)-1:0] lfsr;
  current_req_t current_req;

  // Helper functions

  function logic[7:0] nextLfsr(logic[7:0] n);
    automatic logic tmp;
    tmp = !(n[7] ^ n[3] ^ n[2] ^ n[1]);
    return {n[6:0], tmp};
  endfunction

  function bit isHit(
                     cache_line_t [DCACHE_NUM_WORDS-1:0][DCACHE_SET_ASSOC-1:0] cache_status,
                     current_req_t req
                     );
    for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
      if (cache_status[req.mem_idx][i].valid && cache_status[req.mem_idx][i].tag == req.tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function bit isDirty(
                       cache_line_t [DCACHE_NUM_WORDS-1:0][DCACHE_SET_ASSOC-1:0] cache_status,
                       current_req_t req
                     );
    for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
      if (cache_status[req.mem_idx][i].dirty && cache_status[req.mem_idx][i].valid && cache_status[req.mem_idx][i].tag == req.tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function bit isShared(
                        cache_line_t [DCACHE_NUM_WORDS-1:0][DCACHE_SET_ASSOC-1:0] cache_status,
                        current_req_t req
                       );
    for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
      if (cache_status[req.mem_idx][i].shared && cache_status[req.mem_idx][i].valid && cache_status[req.mem_idx][i].tag == req.tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  logic [$clog2(DCACHE_SET_ASSOC)-1:0] target_way;
  logic [DCACHE_SET_ASSOC-1:0]         valid_v, dirty_v, shared_v;

  generate
    genvar                             i;
    for (i = 0; i < DCACHE_SET_ASSOC; i++) begin
      assign valid_v[i] = cache_status[current_req.mem_idx][i].valid;
      assign dirty_v[i] = cache_status[current_req.mem_idx][i].dirty;
      assign shared_v[i] = cache_status[current_req.mem_idx][i].shared;
    end
  endgenerate

  // Helper tasks

  task automatic updateCache();
    if (current_req.req_type == SNOOP_REQ) begin
      // look for the right tag
      for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
//        if (valid_v[i] && cache_status[current_req.mem_idx][i].tag == current_req.tag) begin
          if (isHit(cache_status, current_req)) begin
          case (current_req.snoop_type)
            snoop_pkg::READ_SHARED: begin
              cache_status[current_req.mem_idx][i].shared = 1'b1;
            end
            snoop_pkg::READ_UNIQUE: begin
              cache_status[current_req.mem_idx][i].shared = 1'b0;
              cache_status[current_req.mem_idx][i].valid = 1'b0;
              cache_status[current_req.mem_idx][i].dirty = 1'b0;
            end
            snoop_pkg::CLEAN_INVALID: begin
              cache_status[current_req.mem_idx][i].shared = 1'b0;
              cache_status[current_req.mem_idx][i].valid = 1'b0;
              cache_status[current_req.mem_idx][i].dirty = 1'b0;
            end
          endcase
          break;
        end
      end
    end
    // read or write request
    else begin
      // cache miss
      if (!isHit(cache_status, current_req)) begin
        // all ways occupied
        if (&valid_v) begin
          target_way = lfsr[$clog2(DCACHE_SET_ASSOC)-1:0];
          cache_status[current_req.mem_idx][target_way].tag = current_req.tag;
          if (current_req.req_type == WR_REQ)
            cache_status[current_req.mem_idx][target_way].dirty = 1'b1;
          else
            cache_status[current_req.mem_idx][target_way].dirty = 1'b0;
          lfsr = nextLfsr(lfsr);
        end
        // there is an empty way
        else begin
          target_way = one_hot_to_bin(get_victim_cl(~valid_v));
          cache_status[current_req.mem_idx][target_way].tag = current_req.tag;
          cache_status[current_req.mem_idx][target_way].valid = 1'b1;
          if (current_req.req_type == WR_REQ)
            cache_status[current_req.mem_idx][target_way].dirty = 1'b1;
        end
      end
      // cache hit
      else begin
        if (current_req.req_type == WR_REQ)
          cache_status[current_req.mem_idx][target_way].dirty = 1'b1;
      end
    end
  endtask

  task automatic checkCache (
                             output bit OK
                             );
    int unsigned                        cache_idx;

    OK = 1'b1;

    // check the target_way
    if (cache_status[current_req.mem_idx][target_way].dirty != i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - dirty bit: expected %d, actual %d", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].dirty, i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way]);
    end
    if (cache_status[current_req.mem_idx][target_way].valid != i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way+1]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - valid bit: expected %d, actual %d", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].valid, i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way+1]);
    end
    if (cache_status[current_req.mem_idx][target_way].shared != i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way+2]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - shared bit: expected %d, actual %d", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].shared, i_dut.valid_dirty_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx][8*target_way+2]);
    end
    if (cache_status[current_req.mem_idx][0].tag != i_dut.sram_block[0].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[0].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][1].tag != i_dut.sram_block[1].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[1].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][2].tag != i_dut.sram_block[2].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[2].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][3].tag != i_dut.sram_block[3].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[3].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][4].tag != i_dut.sram_block[4].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[4].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][5].tag != i_dut.sram_block[5].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[5].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][6].tag != i_dut.sram_block[6].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[6].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
    if (cache_status[current_req.mem_idx][7].tag != i_dut.sram_block[7].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]) begin
      OK = 1'b0;
      $error("Cache mismatch index %h tag %h way %h - tag: expected %h, actual %h", current_req.index, current_req.tag, target_way, cache_status[current_req.mem_idx][target_way].tag, i_dut.sram_block[7].tag_sram.gen_cut[0].gen_mem.i_tc_sram_wrapper.i_tc_sram.sram[current_req.mem_idx]);
    end
  endtask

  // Main loop

  assign current_req.index = current_req.addr[DCACHE_INDEX_WIDTH-1:0];
  assign current_req.tag = current_req.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH];
  assign current_req.mem_idx = current_req.addr[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET];

  logic ongoing_transaction;

  logic start_transaction;

  always_comb begin
    start_transaction = 1'b0;
    if (snoop_req_i.ac_valid & snoop_resp_o.ac_ready)
      start_transaction = 1'b1;
    for (int i = 0; i < NR_CPU_PORTS; i++)
      if (req_ports_i[i].data_req)
        start_transaction = 1'b1;
  end

  always_latch begin
    if (start_transaction) begin
      if (snoop_req_i.ac_valid & snoop_resp_o.ac_ready) begin
        current_req.active_port = 0;
        current_req.req_type = SNOOP_REQ;
        current_req.addr = snoop_req_i.ac.addr;
        current_req.snoop_type = snoop_req_i.ac.snoop;
      end
      else begin
        for (int i = 0; i < NR_CPU_PORTS; i++) begin
          if (req_ports_i[i].data_req) begin
            current_req.active_port = i;
            if (req_ports_i[i].data_we)
              current_req.req_type = WR_REQ;
            else
              current_req.req_type = RD_REQ;
            current_req.addr = {req_ports_i[i].address_tag, req_ports_i[i].address_index};
            current_req.snoop_type = 0;
          end
        end
      end
    end
  end

  initial begin
    bit checkOK;

    cache_status = '0;
    lfsr = '0;

    forever begin
      check_done_o = 1'b0;

      `WAIT_SIG(clk_i, start_transaction)

      if (current_req.req_type == SNOOP_REQ) begin
        // expect a writeback before the response
        if (isHit(cache_status, current_req) && current_req.snoop_type == snoop_pkg::CLEAN_INVALID) begin
          `WAIT_SIG(clk_i, axi_data_o.w.last)
        end
        // wait for the response
        if(~snoop_resp_o.cr_valid) begin
          `WAIT_SIG(clk_i, snoop_resp_o.cr_valid)
        end
        // expect the data
        if (isHit(cache_status, current_req) &&
            (current_req.snoop_type == snoop_pkg::READ_UNIQUE || current_req.snoop_type == snoop_pkg::READ_ONCE || current_req.snoop_type == snoop_pkg::READ_SHARED)) begin
          `WAIT_SIG(clk_i, snoop_resp_o.cd.last)
        end
      end
      else begin
        // bypass
        if (current_req.addr < CACHE_BASE_ADDR) begin
          if (current_req.req_type == WR_REQ)
            `WAIT_SIG(clk_i, axi_bypass_i.b_valid)
          else
            `WAIT_SIG(clk_i, axi_bypass_i.r.last)
        end
        // cacheable
        else begin
          // wait for an axi transaction in case of a cache miss
          if (!isHit(cache_status, current_req)) begin
            if (current_req.req_type == WR_REQ) begin
              fork
                `WAIT_SIG(clk_i, axi_data_i.r.last)
                `WAIT_SIG(clk_i, req_ports_o[current_req.active_port].data_gnt)
              join
            end
            else begin
              fork
                `WAIT_SIG(clk_i, axi_data_i.r.last)
                `WAIT_SIG(clk_i, req_ports_o[current_req.active_port].data_rvalid)
              join
            end
          end
          else begin
            // otherwise wait only for the response from the port
            if (current_req.req_type == WR_REQ) begin
              `WAIT_SIG(clk_i, req_ports_o[current_req.active_port].data_gnt)
            end
            else begin
              `WAIT_SIG(clk_i, req_ports_o[current_req.active_port].data_rvalid)
            end
          end
        end
      end // else: !if(current_req.req_type == SNOOP_REQ)

      if (current_req.addr >= CACHE_BASE_ADDR)
        updateCache();

      // the actual cache needs 2 more cycles to be updated
      `WAIT_CYC(clk_i, 2)

      checkCache(checkOK);

      check_done_o = 1'b1;
      `WAIT_CYC(clk_i, 1)
    end
  end

endmodule
