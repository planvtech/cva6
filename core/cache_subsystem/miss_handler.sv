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
// Date: 12.11.2017
// Description: Handles cache misses.

// --------------
// MISS Handler
// --------------

module miss_handler import ariane_pkg::*; import std_cache_pkg::*; #(
    parameter int unsigned NR_PORTS         = 3,
    parameter ariane_cfg_t ArianeCfg        = ArianeDefaultConfig, // contains cacheable regions
    parameter type mst_req_t = logic,
    parameter type mst_resp_t = logic
)(
    input logic                                       clk_i,
    input logic                                       rst_ni,
    input logic                                       flush_i, // flush request
    output logic                                      flush_ack_o, // acknowledge successful flush
    output logic                                      miss_o,
    input logic                                       busy_i, // dcache is busy with something
    // Bypass or miss
    input logic [NR_PORTS-1:0][$bits(miss_req_t)-1:0] miss_req_i,
    // Bypass handling
    output logic [NR_PORTS-1:0]                       bypass_gnt_o,
    output logic [NR_PORTS-1:0]                       bypass_valid_o,
    output logic [NR_PORTS-1:0][63:0]                 bypass_data_o,

    // AXI port
    output                                            mst_req_t axi_bypass_o,
    input                                             mst_resp_t axi_bypass_i,

    // Miss handling (~> cacheline refill)
    output logic [NR_PORTS-1:0]                       miss_gnt_o,
    output logic [NR_PORTS-1:0]                       active_serving_o,

    output logic [63:0]                               critical_word_o,
    output logic                                      critical_word_valid_o,
    output                                            mst_req_t axi_data_o,
    input                                             mst_resp_t axi_data_i,

    input logic [NR_PORTS-1:0][55:0]                  mshr_addr_i,
    output logic [NR_PORTS-1:0]                       mshr_addr_matches_o,
    output logic [NR_PORTS-1:0]                       mshr_index_matches_o,
    // AMO
    input                                             amo_req_t amo_req_i,
    output                                            amo_resp_t amo_resp_o,
    output logic                                      flushing_o,
    output logic                                      serve_amo_o,
    output logic                                      updating_cache_o,
    // Port to SRAMs, for refill and eviction
    output logic [DCACHE_SET_ASSOC-1:0]               req_o,
    output logic [DCACHE_INDEX_WIDTH-1:0]             addr_o, // address into cache array
    output                                            cache_line_t data_o,
    output                                            cl_be_t be_o,
    input                                             cache_line_t [DCACHE_SET_ASSOC-1:0] data_i,
    output logic                                      we_o
);

    // MSHR ports (incl. snoop) + AMO port
    parameter NR_BYPASS_PORTS = NR_PORTS + 1;

    // FSM states
    enum logic [4:0] {
        IDLE,               // 0
        FLUSHING,           // 1
        FLUSH,              // 2
        WB_CACHELINE_FLUSH, // 3
        FLUSH_REQ_STATUS,   // 4
        WB_CACHELINE_MISS,  // 5
        WAIT_GNT_SRAM,      // 6
        MISS,               // 7
        REQ_CACHELINE,      // 8
        MISS_REPL,          // 9
        SAVE_CACHELINE,     // A
        INIT,               // B
        AMO_REQ,            // C
        AMO_WAIT_RESP,      // D
        SEND_CLEAN            // E
    } state_d, state_q;

    // Registers
    mshr_t                                  mshr_d, mshr_q;
    logic [DCACHE_INDEX_WIDTH-1:0]          cnt_d, cnt_q;
    logic [DCACHE_SET_ASSOC-1:0]            evict_way_d, evict_way_q;

  logic                                colliding_clean_d, colliding_clean_q;

    // cache line to evict
    cache_line_t                            evict_cl_d, evict_cl_q;

    logic serve_amo_d, serve_amo_q;
    // Request from one FSM
    logic [NR_PORTS-1:0]                    miss_req_valid;
    logic [NR_PORTS-1:0]                    miss_req_bypass;
    logic [NR_PORTS-1:0][63:0]              miss_req_addr;
    logic [NR_PORTS-1:0][63:0]              miss_req_wdata;
    logic [NR_PORTS-1:0]                    miss_req_we;
    logic [NR_PORTS-1:0][7:0]               miss_req_be;
    logic [NR_PORTS-1:0][1:0]               miss_req_size;
    logic [NR_PORTS-1:0]                    miss_req_invalidate;
    logic [NR_PORTS-1:0]                    miss_req_make_unique;

    // Bypass AMO port
    bypass_req_t amo_bypass_req;
    bypass_rsp_t amo_bypass_rsp;

    // Bypass ports <-> Arbiter
    bypass_req_t [NR_BYPASS_PORTS-1:0] bypass_ports_req;
    bypass_rsp_t [NR_BYPASS_PORTS-1:0] bypass_ports_rsp;

    // Arbiter <-> Bypass AXI adapter
    bypass_req_t bypass_adapter_req;
    bypass_rsp_t bypass_adapter_rsp;
//    ariane_ace::ace_req_t              bypass_adapter_req_type;

    // Cache Line Refill <-> AXI
    logic                                    req_fsm_miss_valid;
    logic [63:0]                             req_fsm_miss_addr;
    logic [DCACHE_LINE_WIDTH-1:0]            req_fsm_miss_wdata;
    logic                                    req_fsm_miss_we;
    logic [(DCACHE_LINE_WIDTH/8)-1:0]        req_fsm_miss_be;
    ariane_axi::ad_req_t                     req_fsm_miss_req;
    logic [1:0]                              req_fsm_miss_size;
    ariane_ace::ace_req_t                    req_fsm_miss_type;

    logic                                    gnt_miss_fsm;
    logic                                    valid_miss_fsm;
    logic [(DCACHE_LINE_WIDTH/64)-1:0][63:0] data_miss_fsm;

  logic                                      shared_miss_fsm;
  logic                                      dirty_miss_fsm;
    // Cache Management <-> LFSR
    logic                                  lfsr_enable;
    logic [DCACHE_SET_ASSOC-1:0]           lfsr_oh;
    logic [$clog2(DCACHE_SET_ASSOC-1)-1:0] lfsr_bin;
    // AMOs
    ariane_pkg::amo_t amo_op;
    logic [63:0]      amo_operand_b;

    logic [DCACHE_SET_ASSOC-1:0] matching_way, matching_dirty_way;

    // ------------------------------
    // Cache Management
    // ------------------------------
    always_comb begin : cache_management
        automatic logic [DCACHE_SET_ASSOC-1:0] evict_way, valid_way;

        for (int unsigned i = 0; i < DCACHE_SET_ASSOC; i++) begin
            evict_way[i] = data_i[i].valid & data_i[i].dirty;
            valid_way[i] = data_i[i].valid;
            matching_way[i] = data_i[i].valid & (data_i[i].tag == mshr_q.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH]);
            matching_dirty_way[i] = data_i[i].valid & data_i[i].dirty & (data_i[i].tag == mshr_q.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH]);
        end
        // ----------------------
        // Default Assignments
        // ----------------------
        // memory array
        req_o  = '0;
        addr_o = '0;
        data_o = '0;
        be_o   = '0;
        we_o   = '0;
        // Cache controller
        miss_gnt_o = '0;
        active_serving_o = '0;
        flushing_o = 1'b0;
        updating_cache_o = 1'b0;
        // LFSR replacement unit
        lfsr_enable = 1'b0;
        // to AXI refill
        req_fsm_miss_valid  = 1'b0;
        req_fsm_miss_addr   = '0;
        req_fsm_miss_wdata  = '0;
        req_fsm_miss_we     = 1'b0;
        req_fsm_miss_be     = '0;
        req_fsm_miss_req    = ariane_axi::CACHE_LINE_REQ;
        req_fsm_miss_size   = 2'b11;
        req_fsm_miss_type   = ariane_ace::READ_SHARED;
        // to AXI bypass
        amo_bypass_req.req     = 1'b0;
        amo_bypass_req.reqtype = ariane_axi::SINGLE_REQ;
        amo_bypass_req.amo     = ariane_pkg::AMO_NONE;
        amo_bypass_req.addr    = '0;
        amo_bypass_req.we      = 1'b0;
        amo_bypass_req.wdata   = '0;
        amo_bypass_req.be      = '0;
        amo_bypass_req.size    = 2'b11;
        amo_bypass_req.id      = 4'b1011;
        // core
        flush_ack_o         = 1'b0;
        miss_o              = 1'b0; // to performance counter
        serve_amo_d         = serve_amo_q;
        serve_amo_o = serve_amo_q;
        // --------------------------------
        // Flush and Miss operation
        // --------------------------------
        state_d      = state_q;
        cnt_d        = cnt_q;
        evict_way_d  = evict_way_q;
        evict_cl_d   = evict_cl_q;
        mshr_d       = mshr_q;
        colliding_clean_d = colliding_clean_q;
        // communicate to the requester which unit we are currently serving
        active_serving_o[mshr_q.id] = mshr_q.valid;
        // AMOs
        amo_resp_o.ack = 1'b0;
        amo_resp_o.result = '0;
        amo_operand_b = '0;

        case (state_q)

            IDLE: begin
                colliding_clean_d = '0;
                // lowest priority are AMOs, wait until everything else is served before going for the AMOs
                if (amo_req_i.req && !busy_i) begin
                    state_d = FLUSH_REQ_STATUS;
                    cnt_d = '0;
                    // remember that flush was started by AMO
                    serve_amo_d = 1'b1;
                end
                // check if we want to flush and can flush e.g.: we are not busy anymore
                // TODO: Check that the busy flag is indeed needed
                if (flush_i && !busy_i) begin
                    state_d = FLUSH_REQ_STATUS;
                    cnt_d = '0;
                end

                // check if one of the state machines missed
                for (int unsigned i = 1; i < NR_PORTS; i++) begin
                    // check if we have to generate a CleanUnique transaction
                    if (miss_req_valid[i] && miss_req_make_unique[i] &&
                        (!miss_req_invalidate[0] ||
                         miss_req_addr[0][DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH] != miss_req_addr[i][DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH])) begin
                        state_d = SEND_CLEAN;
                        // we are taking another request so don't take the AMO
                        serve_amo_d  = 1'b0;
                        // save to MSHR
                        mshr_d.valid = 1'b1;
                        mshr_d.we    = '0;
                        mshr_d.id    = i;
                        mshr_d.addr  = miss_req_addr[i][DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:0];
                        mshr_d.wdata = '0;
                        mshr_d.be    = '0;
                        break;
                    end
                    // here comes the refill portion of code
                    if (miss_req_valid[i] && !miss_req_bypass[i] && !miss_req_make_unique[i]) begin
                        state_d      = MISS;
                        // we are taking another request so don't take the AMO
                        serve_amo_d  = 1'b0;
                        // save to MSHR
                        mshr_d.valid = 1'b1;
                        mshr_d.we    = miss_req_we[i];
                        mshr_d.id    = i;
                        mshr_d.addr  = miss_req_addr[i][DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:0];
                        mshr_d.wdata = miss_req_wdata[i];
                        mshr_d.be    = miss_req_be[i];
                        break;
                    end
                end
              // check if we have to serve an invalidate request
              // invalidate requests can ony come from port 0 (snoop cache controller)
              if (miss_req_valid[0] && miss_req_invalidate[0] && !miss_req_bypass[0]) begin
                // this should never happen
              end

            end

            //  ~> we missed on the cache
            MISS: begin
                // 1. Check if there is an empty cache-line
                // 2. If not -> evict one
                req_o = '1;
                addr_o = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];
                state_d = MISS_REPL;
                miss_o = 1'b1;
            end

            // ~> second miss cycle
            MISS_REPL: begin
                // if all are valid we need to evict one, pseudo random from LFSR
                if (&valid_way) begin
                    lfsr_enable = 1'b1;
                    evict_way_d = lfsr_oh;
                    // do we need to write back the cache line?
                    if (data_i[lfsr_bin].dirty) begin
                        state_d = WB_CACHELINE_MISS;
                        evict_cl_d.tag = data_i[lfsr_bin].tag;
                        evict_cl_d.data = data_i[lfsr_bin].data;
                        cnt_d = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];
                    // no - we can request a cache line now
                    end else
                        state_d = REQ_CACHELINE;
                // we have at least one free way
                end else begin
                    // get victim cache-line by looking for the first non-valid bit
                    evict_way_d = get_victim_cl(~valid_way);
                    state_d = REQ_CACHELINE;
                end
            end

            // ~> we can just load the cache-line, the way is store in evict_way_q
            REQ_CACHELINE: begin
                req_fsm_miss_valid  = 1'b1;
                req_fsm_miss_addr   = mshr_q.addr;
              case ({mshr_q.we, is_inside_shareable_regions(ArianeCfg, mshr_q.addr)})
                    2'b00: req_fsm_miss_type = ariane_ace::READ_NO_SNOOP;
                    2'b01: req_fsm_miss_type = ariane_ace::READ_SHARED;
                    2'b10: req_fsm_miss_type = ariane_ace::WRITE_NO_SNOOP;
                    2'b11: req_fsm_miss_type = ariane_ace::READ_UNIQUE;
                endcase
                // start a ReadUnique also if we reached this state after a colliding invalidation
                if (colliding_clean_q)
                  req_fsm_miss_type = ariane_ace::READ_UNIQUE;
                if (gnt_miss_fsm) begin
                    state_d = SAVE_CACHELINE;
                    miss_gnt_o[mshr_q.id] = 1'b1;
                end
            end

            // ~> replace the cacheline
            SAVE_CACHELINE: begin
                // calculate cacheline offset
                automatic logic [$clog2(DCACHE_LINE_WIDTH)-1:0] cl_offset;
                cl_offset = mshr_q.addr[DCACHE_BYTE_OFFSET-1:3] << 6;
                // we've got a valid response from refill unit
                if (valid_miss_fsm) begin
                    updating_cache_o = 1'b1;

                    addr_o       = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];
                    req_o        = evict_way_q;
                    we_o         = 1'b1;
                    be_o         = '1;
                    be_o.vldrty  = evict_way_q;
                    data_o.tag   = mshr_q.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH];
                    data_o.data  = data_miss_fsm;
                    data_o.valid = 1'b1;
                    data_o.dirty = dirty_miss_fsm;
                    data_o.shared = mshr_q.we ? 1'b0 : shared_miss_fsm;

                    // is this a write?
                    if (mshr_q.we) begin
                        // Yes, so safe the updated data now
                        for (int i = 0; i < 8; i++) begin
                            // check if we really want to write the corresponding byte
                            if (mshr_q.be[i])
                                data_o.data[(cl_offset + i*8) +: 8] = mshr_q.wdata[i];
                        end
                        // it's immediately dirty if we write
                        data_o.dirty = 1'b1;
                    end
                    // reset MSHR
                    mshr_d.valid = 1'b0;
                    // go back to idle
                    state_d = IDLE;
                end
            end

            // ------------------------------
            // Write Back Operation
            // ------------------------------
            // ~> evict a cache line from way saved in evict_way_q
            WB_CACHELINE_FLUSH, WB_CACHELINE_MISS: begin

                req_fsm_miss_valid  = 1'b1;
                req_fsm_miss_addr   = {evict_cl_q.tag, cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET], {{DCACHE_BYTE_OFFSET}{1'b0}}};
                req_fsm_miss_be     = '1;
                req_fsm_miss_we     = 1'b1;
                req_fsm_miss_wdata  = evict_cl_q.data;
                req_fsm_miss_type   = ariane_ace::WRITEBACK;
                flushing_o          = state_q == WB_CACHELINE_FLUSH;

                // we've got a grant --> this is timing critical, think about it
                if (gnt_miss_fsm) begin
                    // write status array
                    addr_o     = cnt_q;
                    req_o      = 1'b1;
                    we_o       = 1'b1;
                    data_o.valid = INVALIDATE_ON_FLUSH ? 1'b0 : 1'b1;
                    // invalidate
                    be_o.vldrty = evict_way_q;
                    // go back to handling the miss or flushing or go to idle, depending on where we came from
                    state_d = (state_q == WB_CACHELINE_MISS) ? MISS :
                              (state_q == WB_CACHELINE_FLUSH) ? FLUSH_REQ_STATUS :
                              IDLE;
                end
            end

            // ------------------------------
            // Flushing & Initialization
            // ------------------------------
            // ~> make another request to check the same cache-line if there are still some valid entries
            FLUSH_REQ_STATUS: begin
                req_o   = '1;
                addr_o  = cnt_q;
                flushing_o = 1'b1;
                state_d = FLUSHING;
            end

            FLUSHING: begin
                flushing_o = 1'b1;
                // this has priority
                // at least one of the cache lines is dirty
                if (|evict_way) begin
                    // evict cache line, look for the first cache-line which is dirty
                    evict_way_d = get_victim_cl(evict_way);
                    evict_cl_d  = data_i[one_hot_to_bin(evict_way)];
                    state_d     = WB_CACHELINE_FLUSH;
                // not dirty ~> increment and continue
                end else begin
                    // increment and re-request
                    cnt_d       = cnt_q + (1'b1 << DCACHE_BYTE_OFFSET);
                    state_d     = FLUSH_REQ_STATUS;
                    addr_o      = cnt_q;
                    req_o       = 1'b1;
                    be_o.vldrty = INVALIDATE_ON_FLUSH ? '1 : '0;
                    we_o        = 1'b1;
                    // finished with flushing operation, go back to idle
                    if (cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == DCACHE_NUM_WORDS-1) begin
                        if (serve_amo_q) begin
                            // if flush was triggered by AMO then continue with request
                            state_d = AMO_REQ;
                            serve_amo_d = 1'b0;
                        end else begin
                            state_d     = IDLE;
                            // only acknowledge if the flush wasn't triggered by an atomic
                            flush_ack_o = 1'b1;
                        end
                    end
                end
            end

            // ~> only called after reset
            INIT: begin
                // initialize status array
                addr_o = cnt_q;
                req_o  = 1'b1;
                we_o   = 1'b1;
                // only write the dirty array
                be_o.vldrty = '1;
                cnt_d       = cnt_q + (1'b1 << DCACHE_BYTE_OFFSET);
                // finished initialization
                if (cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == DCACHE_NUM_WORDS-1)
                    state_d = IDLE;
            end

            // ----------------------
            // Send CleanUnique
            // ----------------------
            SEND_CLEAN: begin
              req_fsm_miss_valid  = 1'b1;
              req_fsm_miss_addr   = mshr_q.addr;
              req_fsm_miss_type   = ariane_ace::CLEAN_UNIQUE;

              if (miss_req_invalidate[0] & !colliding_clean_q)
                colliding_clean_d = miss_req_invalidate[0] & (miss_req_addr[0][63:DCACHE_BYTE_OFFSET]==mshr_q.addr[55:DCACHE_BYTE_OFFSET]);

              if (valid_miss_fsm) begin
                // if the cacheline has just been invalidated, request it again
                if (colliding_clean_q) begin
                  state_d = MISS;
                end
                else begin
                  state_d = IDLE;
                  mshr_d.valid = 1'b0;
                  miss_gnt_o[mshr_q.id] = 1'b1;
                end
              end
            end

            // ----------------------
            // AMOs
            // ----------------------
            // ~> we are here because we need to do the AMO, the cache is clean at this point
            AMO_REQ: begin
                amo_bypass_req.req     = 1'b1;
                amo_bypass_req.reqtype = ariane_axi::SINGLE_REQ;
                amo_bypass_req.amo     = amo_req_i.amo_op;
                // address is in operand a
                amo_bypass_req.addr = amo_req_i.operand_a;
                if (amo_req_i.amo_op != AMO_LR) begin
                    amo_bypass_req.we = 1'b1;
                end
                amo_bypass_req.size  = amo_req_i.size;
                // AXI implements CLR op instead of AND, negate operand
                if (amo_req_i.amo_op == AMO_AND) begin
                    amo_operand_b = ~amo_req_i.operand_b;
                end else begin
                    amo_operand_b = amo_req_i.operand_b;
                end
                // align data and byte-enable to correct byte lanes
                amo_bypass_req.wdata = amo_operand_b;
                if (amo_req_i.size == 2'b11) begin
                    // 64b transfer
                    amo_bypass_req.be = 8'b11111111;
                end else begin
                    // 32b transfer
                    if (amo_req_i.operand_a[2:0] == '0) begin
                        // 64b aligned -> activate lower 4 byte lanes
                        amo_bypass_req.be = 8'b00001111;
                    end else begin
                        // 64b unaligned -> activate upper 4 byte lanes
                        amo_bypass_req.be = 8'b11110000;
                        amo_bypass_req.wdata = amo_operand_b[31:0] << 32;
                    end
                end

                // when request is accepted, wait for response
                if (amo_bypass_rsp.gnt) begin
                    if (amo_bypass_rsp.valid) begin
                        state_d = IDLE;
                        amo_resp_o.ack = 1'b1;
                        amo_resp_o.result = amo_bypass_rsp.rdata;
                    end else begin
                        state_d = AMO_WAIT_RESP;
                    end
                end
            end
            AMO_WAIT_RESP: begin
                if (amo_bypass_rsp.valid) begin
                    state_d = IDLE;
                    amo_resp_o.ack = 1'b1;
                    // Request is assumed to be still valid (ack not granted yet)
                    if (amo_req_i.size == 2'b10) begin
                        // 32b request
                        logic [31:0] halfword;
                        if (amo_req_i.operand_a[2:0] == '0) begin
                            // 64b aligned -> activate lower 4 byte lanes
                            halfword = amo_bypass_rsp.rdata[31:0];
                        end else begin
                            // 64b unaligned -> activate upper 4 byte lanes
                            halfword = amo_bypass_rsp.rdata[63:32];
                        end
                        // Sign-extend 32b requests as per RISC-V spec
                        amo_resp_o.result = {{32{halfword[31]}}, halfword};
                    end else begin
                        // 64b request
                        amo_resp_o.result = amo_bypass_rsp.rdata;
                    end
                end
            end
        endcase
    end

    // check MSHR for aliasing
    always_comb begin

        mshr_addr_matches_o  = 'b0;
        mshr_index_matches_o = 'b0;

        for (int i = 0; i < NR_PORTS; i++) begin
            // check mshr for potential matching of other units, exclude the unit currently being served
            if (mshr_q.valid && mshr_addr_i[i][55:DCACHE_BYTE_OFFSET] == mshr_q.addr[55:DCACHE_BYTE_OFFSET]) begin
                mshr_addr_matches_o[i] = 1'b1;
            end

            // same as previous, but checking only the index
            if (mshr_q.valid && mshr_addr_i[i][DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == mshr_q.addr[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET]) begin
                mshr_index_matches_o[i] = 1'b1;
            end
        end
    end
    // --------------------
    // Sequential Process
    // --------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mshr_q        <= '0;
            state_q       <= INIT;
            cnt_q         <= '0;
            evict_way_q   <= '0;
            evict_cl_q    <= '0;
            serve_amo_q   <= 1'b0;
            colliding_clean_q <= '0;
        end else begin
            mshr_q        <= mshr_d;
            state_q       <= state_d;
            cnt_q         <= cnt_d;
            evict_way_q   <= evict_way_d;
            evict_cl_q    <= evict_cl_d;
            serve_amo_q   <= serve_amo_d;
            colliding_clean_q <= colliding_clean_d;
        end
    end

    //pragma translate_off
    `ifndef VERILATOR
    // assert that cache only hits on one way
    assert property (
      @(posedge clk_i) $onehot0(evict_way_q)) else $warning("Evict-way should be one-hot encoded");
    `endif
    //pragma translate_on

    // ----------------------
    // Pack bypass ports
    // ----------------------
    always_comb begin
        logic [$clog2(NR_BYPASS_PORTS)-1:0] id;

        // Pack MHSR ports first
        for (id = 0; id < NR_PORTS; id++) begin
            bypass_ports_req[id].req     = miss_req_valid[id] & miss_req_bypass[id];
            bypass_ports_req[id].reqtype = ariane_axi::SINGLE_REQ;
            bypass_ports_req[id].amo     = AMO_NONE;
            bypass_ports_req[id].id      = {1'b1, id};
            bypass_ports_req[id].addr    = miss_req_addr[id];
            bypass_ports_req[id].wdata   = miss_req_wdata[id];
            bypass_ports_req[id].we      = miss_req_we[id];
            bypass_ports_req[id].be      = miss_req_be[id];
            bypass_ports_req[id].size    = miss_req_size[id];

            if (miss_req_we[id]) begin
              // requests coming from port 0 (snoop) can only be writeback requests
              if (id == 0) begin
                bypass_ports_req[id].acetype = ariane_ace::WRITEBACK;
              end
              else begin
                if (is_inside_shareable_regions(ArianeCfg, miss_req_addr[id])) begin
                  bypass_ports_req[id].acetype = ariane_ace::WRITE_UNIQUE;
                end
                else begin
                  bypass_ports_req[id].acetype = ariane_ace::WRITE_NO_SNOOP;
                end
              end
            end
            else begin
              if (is_inside_shareable_regions(ArianeCfg, miss_req_addr[id])) begin
                bypass_ports_req[id].acetype = ariane_ace::READ_ONCE;
              end
              else begin
                bypass_ports_req[id].acetype = ariane_ace::READ_NO_SNOOP;
              end
            end

            bypass_gnt_o[id]   = bypass_ports_rsp[id].gnt;
            bypass_valid_o[id] = bypass_ports_rsp[id].valid;
            bypass_data_o[id]  = bypass_ports_rsp[id].rdata;
        end

        // AMO port has lowest priority
        bypass_ports_req[id] = amo_bypass_req;
        //bypass_ports_req[id].id = {1'b1, id};
        if (amo_bypass_req.we) begin
          if (is_inside_shareable_regions(ArianeCfg, amo_bypass_req.addr)) begin
            bypass_ports_req[id].acetype = ariane_ace::WRITE_UNIQUE;
          end
          else begin
            bypass_ports_req[id].acetype = ariane_ace::WRITE_NO_SNOOP;
          end
        end
        else begin
          if (is_inside_shareable_regions(ArianeCfg, amo_bypass_req.addr)) begin
            bypass_ports_req[id].acetype = ariane_ace::READ_ONCE;
          end
          else begin
            bypass_ports_req[id].acetype = ariane_ace::READ_NO_SNOOP;
          end
        end

        amo_bypass_rsp       = bypass_ports_rsp[id];
    end

    // ----------------------
    // Arbitrate bypass ports
    // ----------------------
    axi_adapter_arbiter #(
        .NR_PORTS(NR_BYPASS_PORTS),
        .req_t   (bypass_req_t),
        .rsp_t   (bypass_rsp_t)
    ) i_bypass_arbiter (
        .clk_i (clk_i),
        .rst_ni(rst_ni),
        // Master Side
        .req_i (bypass_ports_req),
        .rsp_o (bypass_ports_rsp),
        // Slave Side
        .req_o (bypass_adapter_req),
        .rsp_i (bypass_adapter_rsp)
    );



//  xlnx_ila i_ila
//    (
//     .clk (clk_i),
//     .probe0 ({state_q, flush_i, busy_i, serve_amo_q, miss_req_valid, miss_req_bypass, miss_req_make_unique, miss_req_invalidate}),
//     .probe1 (amo_req_i.operand_a[31:0]),
//     .probe2 ({amo_req_i.req, amo_resp_o.ack}),
//     .probe3 (miss_req_addr[0][31:0]),
//     .probe4 (miss_req_addr[1][31:0]),
//     .probe5 (miss_req_addr[2][31:0]),
//     .probe6 (miss_req_addr[3][31:0]),
//     .probe7 (miss_gnt_o),
//     .probe8 (active_serving_o),
//     .probe9 ('0),
//     .probe10 ('0),
//     .probe11 ('0),
//     .probe12 ('0)
//     );

//  always_comb begin
//    if (bypass_adapter_req.we) begin
//      if (is_inside_shareable_regions(ArianeCfg, bypass_adapter_req.addr)) begin
//        bypass_adapter_req_type = ariane_ace::WRITE_UNIQUE;
//      end
//      else begin
//        bypass_adapter_req_type = ariane_ace::WRITE_NO_SNOOP;
//      end
//    end
//    else begin
//      if (is_inside_shareable_regions(ArianeCfg, bypass_adapter_req.addr)) begin
//        bypass_adapter_req_type = ariane_ace::READ_ONCE;
//      end
//      else begin
//        bypass_adapter_req_type = ariane_ace::READ_NO_SNOOP;
//      end
//    end
//  end

    // ----------------------
    // Bypass AXI Interface
    // ----------------------
    axi_adapter #(
        .DATA_WIDTH           (64),
        .AXI_ID_WIDTH         (4),
        .CACHELINE_BYTE_OFFSET(DCACHE_BYTE_OFFSET),
        .mst_req_t (mst_req_t),
        .mst_resp_t (mst_resp_t)
    ) i_bypass_axi_adapter (
        .clk_i                (clk_i),
        .rst_ni               (rst_ni),
        .req_i                (bypass_adapter_req.req),
        .type_i               (bypass_adapter_req.reqtype),
        .trans_type_i         (bypass_adapter_req.acetype),
        .amo_i                (bypass_adapter_req.amo),
        .id_i                 (bypass_adapter_req.id),
        .addr_i               (bypass_adapter_req.addr),
        .wdata_i              (bypass_adapter_req.wdata),
        .we_i                 (bypass_adapter_req.we),
        .be_i                 (bypass_adapter_req.be),
        .size_i               (bypass_adapter_req.size),
        .gnt_o                (bypass_adapter_rsp.gnt),
        .valid_o              (bypass_adapter_rsp.valid),
        .rdata_o              (bypass_adapter_rsp.rdata),
        .dirty_o              (),
        .shared_o             (),
        .id_o                 (), // not used, single outstanding request in arbiter
        .critical_word_o      (), // not used for single requests
        .critical_word_valid_o(), // not used for single requests
        .axi_req_o            (axi_bypass_o),
        .axi_resp_i           (axi_bypass_i)
    );

    // ----------------------
    // Cache Line AXI Refill
    // ----------------------
    axi_adapter  #(
        .DATA_WIDTH            ( DCACHE_LINE_WIDTH  ),
        .AXI_ID_WIDTH          ( 4                  ),
        .CACHELINE_BYTE_OFFSET ( DCACHE_BYTE_OFFSET ),
        .mst_req_t (mst_req_t),
        .mst_resp_t (mst_resp_t)
    ) i_miss_axi_adapter (
        .clk_i,
        .rst_ni,
        .req_i               ( req_fsm_miss_valid ),
        .type_i              ( req_fsm_miss_req   ),
        .trans_type_i        ( req_fsm_miss_type  ),
        .amo_i               ( AMO_NONE           ),
        .gnt_o               ( gnt_miss_fsm       ),
        .addr_i              ( req_fsm_miss_addr  ),
        .we_i                ( req_fsm_miss_we    ),
        .wdata_i             ( req_fsm_miss_wdata ),
        .be_i                ( req_fsm_miss_be    ),
        .size_i              ( req_fsm_miss_size  ),
        .id_i                ( 4'b1100            ),
        .valid_o             ( valid_miss_fsm     ),
        .rdata_o             ( data_miss_fsm      ),
        .dirty_o             ( dirty_miss_fsm     ),
        .shared_o            ( shared_miss_fsm    ),
        .id_o                (                    ),
        .critical_word_o     ( critical_word_o    ),
        .critical_word_valid_o (critical_word_valid_o),
        .axi_req_o           ( axi_data_o         ),
        .axi_resp_i          ( axi_data_i         )
    );

    // -----------------
    // Replacement LFSR
    // -----------------
    lfsr_8bit #(.WIDTH (DCACHE_SET_ASSOC)) i_lfsr (
        .en_i           ( lfsr_enable ),
        .refill_way_oh  ( lfsr_oh     ),
        .refill_way_bin ( lfsr_bin    ),
        .*
    );

    // -----------------
    // Struct Split
    // -----------------
    // Hack as system verilog support in modelsim seems to be buggy here
    always_comb begin
        automatic miss_req_t miss_req;

        for (int unsigned i = 0; i < NR_PORTS; i++) begin
            miss_req =  miss_req_t'(miss_req_i[i]);
            miss_req_valid  [i]  = miss_req.valid;
            miss_req_bypass [i]  = miss_req.bypass;
            miss_req_addr   [i]  = miss_req.addr;
            miss_req_wdata  [i]  = miss_req.wdata;
            miss_req_we     [i]  = miss_req.we;
            miss_req_be     [i]  = miss_req.be;
            miss_req_size   [i]  = miss_req.size;
            miss_req_invalidate   [i]  = miss_req.invalidate;
            miss_req_make_unique   [i]  = miss_req.make_unique;
        end
    end
endmodule

// --------------
// AXI Arbiter
// --------------
//
// Description: Arbitrates access to AXI refill/bypass
//
module axi_adapter_arbiter #(
    parameter NR_PORTS = 4,
    parameter type req_t = std_cache_pkg::bypass_req_t,
    parameter type rsp_t = std_cache_pkg::bypass_rsp_t
)(
    input  logic                clk_i,  // Clock
    input  logic                rst_ni, // Asynchronous reset active low
    // Master ports
    input  req_t [NR_PORTS-1:0] req_i,
    output rsp_t [NR_PORTS-1:0] rsp_o,
    // Slave port
    output req_t                req_o,
    input  rsp_t                rsp_i
);

    enum logic { IDLE, SERVING } state_d, state_q;

    req_t req_d, req_q;
    logic [NR_PORTS-1:0] sel_d, sel_q;

    always_comb begin
        sel_d = sel_q;

        state_d = state_q;
        req_d   = req_q;

        req_o = req_q;

        rsp_o = '0;
        rsp_o[sel_q].rdata = rsp_i.rdata;

        case (state_q)

            IDLE: begin
                req_d = '0;
                req_o = '0;

                // wait for incoming requests
                for (int unsigned i = 0; i < NR_PORTS; i++) begin
                    if (req_i[i].req == 1'b1) begin
                        sel_d   = i[$bits(sel_d)-1:0];
                        req_d = req_i[sel_d];
                        req_o = req_i[sel_d];
                        rsp_o[sel_d].gnt = req_i[sel_d].req;
                        state_d = SERVING;
                        break;
                    end
                end
            end

            SERVING: begin
                if (rsp_i.valid) begin
                    rsp_o[sel_q].valid = 1'b1;
                    state_d = IDLE;
                end
            end

            default : /* default */;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q <= IDLE;
            sel_q   <= '0;
            req_q   <= '0;
        end else begin
            state_q <= state_d;
            sel_q   <= sel_d;
            req_q   <= req_d;
        end
    end
    // ------------
    // Assertions
    // ------------

    //pragma translate_off
    `ifndef VERILATOR
    // make sure that we eventually get an rvalid after we received a grant
    assert property (@(posedge clk_i) rsp_i.gnt |-> ##[1:$] rsp_i.valid )
        else begin $error("There was a grant without a rvalid"); $stop(); end
    // assert that there is no grant without a request
    assert property (@(negedge clk_i) rsp_i.gnt |-> req_o.req)
        else begin $error("There was a grant without a request."); $stop(); end
    // assert that the address does not contain X when request is sent
    assert property ( @(posedge clk_i) (req_o.req) |-> (!$isunknown(req_o.addr)) )
      else begin $error("address contains X when request is set"); $stop(); end

    `endif
    //pragma translate_on
endmodule
