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
// Date: 13.10.2017
// Description: Nonblocking private L1 dcache


module std_nbdcache import std_cache_pkg::*; import ariane_pkg::*; #(
    parameter ariane_cfg_t ArianeCfg        = ArianeDefaultConfig, // contains cacheable regions
    parameter type mst_req_t = logic,
    parameter type mst_resp_t = logic
)(
    input logic  clk_i, // Clock
    input logic  rst_ni, // Asynchronous reset active low
    // Cache management
    input logic  enable_i, // from CSR
    input logic  flush_i, // high until acknowledged
    output logic flush_ack_o, // send a single cycle acknowledge signal when the cache is flushed
    output logic miss_o, // we missed on a LD/ST
    // AMOs
    input        amo_req_t amo_req_i,
    output       amo_resp_t amo_resp_o,
    // Request ports
    input        dcache_req_i_t [2:0] req_ports_i, // request ports
    output       dcache_req_o_t [2:0] req_ports_o, // request ports
    // Cache AXI refill port
    output       mst_req_t axi_data_o,
    input        mst_resp_t axi_data_i,
    output       mst_req_t axi_bypass_o,
    input        mst_resp_t axi_bypass_i,
    output       ariane_ace::snoop_resp_t snoop_port_o,
    input        ariane_ace::snoop_req_t snoop_port_i

);

import std_cache_pkg::*;

    // -------------------------------
    // Controller <-> Arbiter
    // -------------------------------
    // 1. Miss handler
    // 2. snoop
    // 3. PTW
    // 4. Load Unit
    // 5. Store unit
    logic        [4:0][DCACHE_SET_ASSOC-1:0]  req;
    logic        [4:0][DCACHE_INDEX_WIDTH-1:0]addr;
    logic        [4:0]                        gnt;
    cache_line_t [DCACHE_SET_ASSOC-1:0]       rdata;
    logic        [4:0][DCACHE_TAG_WIDTH-1:0]  tag;

    cache_line_t [4:0]                        wdata;
    logic        [4:0]                        we;
    cl_be_t      [4:0]                        be;
    logic        [DCACHE_SET_ASSOC-1:0]       hit_way;
    logic [DCACHE_SET_ASSOC-1:0]              dirty_way;
    logic [DCACHE_SET_ASSOC-1:0]              shared_way;
    // -------------------------------
    // Controller <-> Miss unit
    // -------------------------------
    logic [3:0]                        busy;
    logic [3:0][55:0]                  mshr_addr;
    logic [3:0]                        mshr_addr_matches;
    logic [3:0]                        mshr_index_matches;
    logic [63:0]                       critical_word;
    logic                              critical_word_valid;

    logic [3:0][$bits(miss_req_t)-1:0] miss_req;
    logic [3:0]                        miss_gnt;
    logic [3:0]                        active_serving;
    logic                              flushing;


    logic [3:0]                        bypass_gnt;
    logic [3:0]                        bypass_valid;
    logic [3:0][63:0]                  bypass_data;

    logic                              invalidate;

    // -------------------------------
    // Arbiter <-> Datram,
    // -------------------------------
    logic [DCACHE_SET_ASSOC-1:0]         req_ram;
    logic [DCACHE_INDEX_WIDTH-1:0]       addr_ram;
    logic                                we_ram;
    cache_line_t                         wdata_ram;
    cache_line_t [DCACHE_SET_ASSOC-1:0]  rdata_ram;
    cl_be_t                              be_ram;

    readshared_done_t readshared_done;
    logic [3:0]       updating_cache;

    // ------------------
    // Cache Controller
    // ------------------

    snoop_cache_ctrl  #(
        .ArianeCfg ( ArianeCfg )
    ) i_snoop_cache_ctrl (
        .bypass_i             ( ~enable_i             ),
        .busy_o               ( busy              [0] ),
        // from ACE
        .snoop_port_i         ( snoop_port_i          ),
        .snoop_port_o         ( snoop_port_o          ),
        // to SRAM array
        .req_o                ( req               [1] ),
        .addr_o               ( addr              [1] ),
        .gnt_i                ( gnt               [1] ),
        .data_i               ( rdata                 ),
        .tag_o                ( tag               [1] ),
        .data_o               ( wdata             [1] ),
        .we_o                 ( we                [1] ),
        .be_o                 ( be                [1] ),
        .hit_way_i            ( hit_way               ),
        .dirty_way_i          ( dirty_way             ),
        .shared_way_i         ( shared_way            ),

        .miss_req_o           ( miss_req          [0] ),
        .miss_gnt_i           ( miss_gnt          [0] ),
        .active_serving_i     ( active_serving    [0] ),
        .bypass_gnt_i         ( bypass_gnt        [0] ),
        .bypass_valid_i       ( bypass_valid      [0] ),

        .mshr_addr_o          ( mshr_addr         [0] ),
        .mshr_addr_matches_i  ( mshr_addr_matches [0] ),
        .mshr_index_matches_i ( mshr_index_matches[0] ),

        .readshared_done_o    ( readshared_done       ),
        .updating_cache_i     ( |updating_cache       ),
        .flushing_i           ( flushing              ),
        .*
    );

    generate
        for (genvar i = 1; i < 4; i++) begin : master_ports
            cache_ctrl  #(
                .ArianeCfg             ( ArianeCfg            )
            ) i_cache_ctrl (
                .bypass_i              ( ~enable_i            ),
                .busy_o                ( busy            [i]  ),
                // from core
                .req_port_i            ( req_ports_i     [i-1]  ),
                .req_port_o            ( req_ports_o     [i-1]  ),
                // to SRAM array
                .req_o                 ( req            [i+1] ),
                .addr_o                ( addr           [i+1] ),
                .gnt_i                 ( gnt            [i+1] ),
                .data_i                ( rdata                ),
                .tag_o                 ( tag            [i+1] ),
                .data_o                ( wdata          [i+1] ),
                .we_o                  ( we             [i+1] ),
                .be_o                  ( be             [i+1] ),
                .hit_way_i             ( hit_way              ),
                .shared_way_i          ( shared_way           ),

                .miss_req_o            ( miss_req        [i]  ),
                .miss_gnt_i            ( miss_gnt        [i]  ),
                .active_serving_i      ( active_serving  [i]  ),
                .critical_word_i       ( critical_word        ),
                .critical_word_valid_i ( critical_word_valid  ),
                .bypass_gnt_i          ( bypass_gnt      [i]  ),
                .bypass_valid_i        ( bypass_valid    [i]  ),
                .bypass_data_i         ( bypass_data     [i]  ),

                .mshr_addr_o           ( mshr_addr         [i] ),
                .mshr_addr_matches_i   ( mshr_addr_matches [i] ),
                .mshr_index_matches_i  ( mshr_index_matches[i] ),

                .readshared_done_i (readshared_done),
                .updating_cache_o (updating_cache[i]),
                .*
            );
        end
    endgenerate

  ariane_ace::m2s_nosnoop_t axi_nosnoop_data_o, axi_nosnoop_bypass_o;
  ariane_ace::s2m_nosnoop_t axi_nosnoop_data_i, axi_nosnoop_bypass_i;

  assign axi_data_o.aw = axi_nosnoop_data_o.aw;
  assign axi_data_o.aw_valid = axi_nosnoop_data_o.aw_valid;
  assign axi_data_o.w = axi_nosnoop_data_o.w;
  assign axi_data_o.w_valid = axi_nosnoop_data_o.w_valid;
  assign axi_data_o.b_ready = axi_nosnoop_data_o.b_ready;
  assign axi_data_o.ar = axi_nosnoop_data_o.ar;
  assign axi_data_o.ar_valid = axi_nosnoop_data_o.ar_valid;
  assign axi_data_o.r_ready = axi_nosnoop_data_o.r_ready;
  assign axi_nosnoop_data_i.aw_ready = axi_data_i.aw_ready;
  assign axi_nosnoop_data_i.ar_ready = axi_data_i.ar_ready;
  assign axi_nosnoop_data_i.w_ready = axi_data_i.w_ready;
  assign axi_nosnoop_data_i.b_valid = axi_data_i.b_valid;
  assign axi_nosnoop_data_i.b = axi_data_i.b;
  assign axi_nosnoop_data_i.r_valid = axi_data_i.r_valid;
  assign axi_nosnoop_data_i.r = axi_data_i.r;
  assign axi_bypass_o.aw = axi_nosnoop_bypass_o.aw;
  assign axi_bypass_o.aw_valid = axi_nosnoop_bypass_o.aw_valid;
  assign axi_bypass_o.w = axi_nosnoop_bypass_o.w;
  assign axi_bypass_o.w_valid = axi_nosnoop_bypass_o.w_valid;
  assign axi_bypass_o.b_ready = axi_nosnoop_bypass_o.b_ready;
  assign axi_bypass_o.ar = axi_nosnoop_bypass_o.ar;
  assign axi_bypass_o.ar_valid = axi_nosnoop_bypass_o.ar_valid;
  assign axi_bypass_o.r_ready = axi_nosnoop_bypass_o.r_ready;
  assign axi_nosnoop_bypass_i.aw_ready = axi_bypass_i.aw_ready;
  assign axi_nosnoop_bypass_i.ar_ready = axi_bypass_i.ar_ready;
  assign axi_nosnoop_bypass_i.w_ready = axi_bypass_i.w_ready;
  assign axi_nosnoop_bypass_i.b_valid = axi_bypass_i.b_valid;
  assign axi_nosnoop_bypass_i.b = axi_bypass_i.b;
  assign axi_nosnoop_bypass_i.r_valid = axi_bypass_i.r_valid;
  assign axi_nosnoop_bypass_i.r = axi_bypass_i.r;

    // ------------------
    // Miss Handling Unit
    // ------------------
    miss_handler #(
        .NR_PORTS               ( 4                    ),
        .ArianeCfg             ( ArianeCfg            ),
        .mst_req_t (ariane_ace::m2s_nosnoop_t),
        .mst_resp_t (ariane_ace::s2m_nosnoop_t)
    ) i_miss_handler (
        .flush_i                ( flush_i              ),
        .busy_i                 ( |busy                ),
        // AMOs
        .amo_req_i              ( amo_req_i            ),
        .amo_resp_o             ( amo_resp_o           ),
        .miss_req_i             ( miss_req             ),
        .miss_gnt_o             ( miss_gnt             ),
        .bypass_gnt_o           ( bypass_gnt           ),
        .bypass_valid_o         ( bypass_valid         ),
        .bypass_data_o          ( bypass_data          ),
        .critical_word_o        ( critical_word        ),
        .critical_word_valid_o  ( critical_word_valid  ),
        .mshr_addr_i            ( mshr_addr            ),
        .mshr_addr_matches_o    ( mshr_addr_matches    ),
        .mshr_index_matches_o   ( mshr_index_matches   ),
        .active_serving_o       ( active_serving       ),
        .flushing_o (flushing),
        .serve_amo_o (serve_amo),
        .req_o                  ( req             [0]  ),
        .addr_o                 ( addr            [0]  ),
        .data_i                 ( rdata                ),
        .be_o                   ( be              [0]  ),
        .data_o                 ( wdata           [0]  ),
        .we_o                   ( we              [0]  ),
        .axi_bypass_o (axi_nosnoop_bypass_o),
        .axi_bypass_i (axi_nosnoop_bypass_i),
        .axi_data_o (axi_nosnoop_data_o),
        .axi_data_i (axi_nosnoop_data_i),
        .updating_cache_o (updating_cache[0]),
        .*
    );

    assign tag[0] = '0;

    // --------------
    // Memory Arrays
    // --------------
    for (genvar i = 0; i < DCACHE_SET_ASSOC; i++) begin : sram_block
        sram #(
            .DATA_WIDTH ( DCACHE_LINE_WIDTH                 ),
            .NUM_WORDS  ( DCACHE_NUM_WORDS                  )
        ) data_sram (
            .req_i   ( req_ram [i]                          ),
            .rst_ni  ( rst_ni                               ),
            .we_i    ( we_ram                               ),
            .addr_i  ( addr_ram[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET]  ),
            .wuser_i ( '0                                   ),
            .wdata_i ( wdata_ram.data                       ),
            .be_i    ( be_ram.data                          ),
            .ruser_o (                                      ),
            .rdata_o ( rdata_ram[i].data                    ),
            .*
        );

        sram #(
            .DATA_WIDTH ( DCACHE_TAG_WIDTH                  ),
            .NUM_WORDS  ( DCACHE_NUM_WORDS                  )
        ) tag_sram (
            .req_i   ( req_ram [i]                          ),
            .rst_ni  ( rst_ni                               ),
            .we_i    ( we_ram                               ),
            .addr_i  ( addr_ram[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET]  ),
            .wuser_i ( '0                                   ),
            .wdata_i ( wdata_ram.tag                        ),
            .be_i    ( be_ram.tag                           ),
            .ruser_o (                                      ),
            .rdata_o ( rdata_ram[i].tag                     ),
            .*
        );

    end

    // ----------------
    // Valid/Dirty/Shared Regs
    // ----------------

    // align each valid/dirty/shared triplet is aligned to a byte boundary in order to leverage byte enable signals.
    // note: if you have an SRAM that supports flat bit enables for your target technology,
    // you can use it here to save the extra overhead introduced by this workaround.
    logic [4*DCACHE_DIRTY_WIDTH-1:0] dirty_wdata, dirty_rdata;

    for (genvar i = 0; i < DCACHE_SET_ASSOC; i++) begin
        assign dirty_wdata[8*i]   = wdata_ram.dirty;
        assign dirty_wdata[8*i+1] = wdata_ram.valid;
        assign dirty_wdata[8*i+2] = wdata_ram.shared;
        assign rdata_ram[i].dirty = dirty_rdata[8*i];
        assign rdata_ram[i].valid = dirty_rdata[8*i+1];
        assign rdata_ram[i].shared = dirty_rdata[8*i+2];
    end

    sram #(
        .USER_WIDTH ( 1                                ),
        .DATA_WIDTH ( 4*DCACHE_DIRTY_WIDTH             ),
        .NUM_WORDS  ( DCACHE_NUM_WORDS                 )
    ) valid_dirty_sram (
        .clk_i   ( clk_i                               ),
        .rst_ni  ( rst_ni                              ),
        .req_i   ( |req_ram                            ),
        .we_i    ( we_ram                              ),
        .addr_i  ( addr_ram[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] ),
        .wuser_i ( '0                                  ),
        .wdata_i ( dirty_wdata                         ),
        .be_i    ( be_ram.vldrty                       ),
        .ruser_o (                                     ),
        .rdata_o ( dirty_rdata                         )
    );

    // ------------------------------------------------
    // Tag Comparison and memory arbitration
    // ------------------------------------------------
    tag_cmp #(
        .NR_PORTS           ( 5                  ),
        .ADDR_WIDTH         ( DCACHE_INDEX_WIDTH ),
        .DCACHE_SET_ASSOC   ( DCACHE_SET_ASSOC   )
    ) i_tag_cmp (
        .req_i              ( req         ),
        .gnt_o              ( gnt         ),
        .addr_i             ( addr        ),
        .wdata_i            ( wdata       ),
        .we_i               ( we          ),
        .be_i               ( be          ),
        .rdata_o            ( rdata       ),
        .tag_i              ( tag         ),
        .hit_way_o          ( hit_way     ),

        .req_o              ( req_ram     ),
        .addr_o             ( addr_ram    ),
        .wdata_o            ( wdata_ram   ),
        .we_o               ( we_ram      ),
        .be_o               ( be_ram      ),
        .rdata_i            ( rdata_ram   ),
        .*
    );

  for (genvar j = 0; j < DCACHE_SET_ASSOC; j++) begin
    assign dirty_way[j] = rdata_ram[j].dirty;
    assign shared_way[j] = rdata_ram[j].shared;
  end

//pragma translate_off
    initial begin
        assert ($bits(axi_data_o.aw.addr) == 64) else $fatal(1, "Ariane needs a 64-bit bus");
        assert (DCACHE_LINE_WIDTH/64 inside {2, 4, 8, 16}) else $fatal(1, "Cache line size needs to be a power of two multiple of 64");
    end
//pragma translate_on
endmodule
