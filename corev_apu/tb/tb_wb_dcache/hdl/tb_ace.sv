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
`include "ace/assign.svh"

module tb_ace import ariane_pkg::*; import std_cache_pkg::*; import tb_pkg::*; #()();

  localparam maxRounds = 1000;

  // leave this
  timeunit 1ps;
  timeprecision 1ps;

  // memory configuration (64bit words)
  parameter MemBytes          = 2**DCACHE_INDEX_WIDTH * 4 * 32;
  parameter MemWords          = MemBytes>>3;

  // noncacheable portion
  parameter logic [63:0] CachedAddrBeg = MemBytes>>3;//1/8th of the memory is NC
  parameter logic [63:0] CachedAddrEnd = 64'hFFFF_FFFF_FFFF_FFFF;

  localparam ariane_cfg_t ArianeDefaultConfig = '{
    RASDepth: 2,
    BTBEntries: 32,
    BHTEntries: 128,
    // idempotent region
    NrNonIdempotentRules:  0,
    NonIdempotentAddrBase: {64'b0},
    NonIdempotentLength:   {64'b0},
    // executable region
    NrExecuteRegionRules:  0,
    ExecuteRegionAddrBase: {64'h0},
    ExecuteRegionLength:   {64'h0},
    // cached region
    NrCachedRegionRules:   1,
    CachedRegionAddrBase:  {CachedAddrBeg},//1/8th of the memory is NC
    CachedRegionLength:    {CachedAddrEnd-CachedAddrBeg+64'b1},
    // cache config
    Axi64BitCompliant:     1'b1,
    SwapEndianess:         1'b0,
    // debug
    DmBaseAddress:         64'h0,
    NrPMPEntries:          0
  };

  // ID width of the Full AXI slave port, master port has ID `AxiIdWidthFull + 32'd1`
  parameter int unsigned AxiIdWidth   = 32'd6;
  // Address width of the full AXI bus
  parameter int unsigned AxiAddrWidth = 32'd64;
  // Data width of the full AXI bus
  parameter int unsigned AxiDataWidth = 32'd64;
  localparam int unsigned AxiUserWidth = 32'd1;

  // DUT signal declarations

  logic                           enable_i;
  logic                           flush_i;
  logic                           flush_ack_o;
  logic                           miss_o;
  amo_req_t                       amo_req_i;
  amo_resp_t                      amo_resp_o;
  dcache_req_i_t [2:0]            req_ports_i;
  dcache_req_o_t [2:0]            req_ports_o;
  ariane_ace::m2s_nosnoop_t       axi_data_o;
  ariane_ace::s2m_nosnoop_t       axi_data_i;
  ariane_ace::m2s_nosnoop_t       axi_bypass_o;
  ariane_ace::s2m_nosnoop_t       axi_bypass_i;
  ariane_ace::snoop_resp_t        snoop_port_o;
  ariane_ace::snoop_req_t         snoop_port_i;

  // TB signal declarations

  logic clk_i, rst_ni;
  ACE_BUS #(
            .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
            .AXI_DATA_WIDTH ( AxiDataWidth     ),
            .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
            .AXI_USER_WIDTH ( AxiUserWidth     )
            ) axi_data ();
  ACE_BUS_DV #(
               .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
               .AXI_DATA_WIDTH ( AxiDataWidth     ),
               .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
               .AXI_USER_WIDTH ( AxiUserWidth     )
               ) axi_data_dv(clk_i);
  ACE_BUS_DV #(
               .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
               .AXI_DATA_WIDTH ( AxiDataWidth     ),
               .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
               .AXI_USER_WIDTH ( AxiUserWidth     )
               ) axi_data_monitor_dv(clk_i);
  `ACE_ASSIGN(axi_data_dv, axi_data)
  `ACE_ASSIGN_FROM_REQ(axi_data, axi_data_o)
  `ACE_ASSIGN_TO_RESP(axi_data_i, axi_data)

  ACE_BUS #(
            .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
            .AXI_DATA_WIDTH ( AxiDataWidth     ),
            .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
            .AXI_USER_WIDTH ( AxiUserWidth     )
            ) axi_bypass ();
  ACE_BUS_DV #(
               .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
               .AXI_DATA_WIDTH ( AxiDataWidth     ),
               .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
               .AXI_USER_WIDTH ( AxiUserWidth     )
               ) axi_bypass_dv(clk_i);
  ACE_BUS_DV #(
               .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
               .AXI_DATA_WIDTH ( AxiDataWidth     ),
               .AXI_ID_WIDTH   ( AxiIdWidth + 32'd1 ),
               .AXI_USER_WIDTH ( AxiUserWidth     )
               ) axi_bypass_monitor_dv(clk_i);
  `ACE_ASSIGN(axi_bypass_dv, axi_bypass)
  `ACE_ASSIGN_FROM_REQ(axi_bypass, axi_bypass_o)
  `ACE_ASSIGN_TO_RESP(axi_bypass_i, axi_bypass)

  SNOOP_BUS #(
            .SNOOP_ADDR_WIDTH ( AxiAddrWidth     ),
            .SNOOP_DATA_WIDTH ( AxiDataWidth     )
            ) snoop ();
  SNOOP_BUS_DV #(
               .SNOOP_ADDR_WIDTH ( AxiAddrWidth     ),
               .SNOOP_DATA_WIDTH ( AxiDataWidth     )
               ) snoop_dv(clk_i);
  SNOOP_BUS_DV #(
               .SNOOP_ADDR_WIDTH ( AxiAddrWidth     ),
               .SNOOP_DATA_WIDTH ( AxiDataWidth     )
               ) snoop_monitor_dv(clk_i);
  `SNOOP_ASSIGN(snoop, snoop_dv)
  `SNOOP_ASSIGN_TO_REQ(snoop_port_i, snoop)
  `SNOOP_ASSIGN_FROM_RESP(snoop, snoop_port_o)

//  ACE_BUS_DV #(
//    .AXI_ADDR_WIDTH ( TbAxiAddrWidthFull       ),
//    .AXI_DATA_WIDTH ( TbAxiDataWidthFull       ),
//    .AXI_ID_WIDTH   ( TbAxiIdWidthFull + 32'd1 ),
//    .AXI_USER_WIDTH ( TbAxiUserWidthFull       )
//  ) axi_data_dv (
//    .clk_i ( clk_i )
//  );
//
//  ACE_BUS_DV #(
//    .AXI_ADDR_WIDTH ( TbAxiAddrWidthFull       ),
//    .AXI_DATA_WIDTH ( TbAxiDataWidthFull       ),
//    .AXI_ID_WIDTH   ( TbAxiIdWidthFull + 32'd1 ),
//    .AXI_USER_WIDTH ( TbAxiUserWidthFull       )
//  ) axi_bypass_dv (
//    .clk_i ( clk_i )
//  );
//
//  `ACE_ASSIGN_FROM_REQ(axi_data_dv, axi_data_o)
//  `ACE_ASSIGN_TO_RESP(axi_data_i, axi_data_dv)
//  `ACE_ASSIGN_FROM_REQ(axi_bypass_dv, axi_bypass_o)
//  `ACE_ASSIGN_TO_RESP(axi_bypass_i, axi_bypass_dv)
//
//  ACE_BUS #(
//    .AXI_ADDR_WIDTH ( TbAxiAddrWidthFull       ),
//    .AXI_DATA_WIDTH ( TbAxiDataWidthFull       ),
//    .AXI_ID_WIDTH   ( TbAxiIdWidthFull + 32'd1 ),
//    .AXI_USER_WIDTH ( TbAxiUserWidthFull       )
//  ) axi_bypass ();
//
//  ACE_BUS #(
//    .AXI_ADDR_WIDTH ( TbAxiAddrWidthFull       ),
//    .AXI_DATA_WIDTH ( TbAxiDataWidthFull       ),
//    .AXI_ID_WIDTH   ( TbAxiIdWidthFull + 32'd1 ),
//    .AXI_USER_WIDTH ( TbAxiUserWidthFull       )
//  ) axi_bypass_amo_adapter ();
//
//  ACE_BUS_DV #(
//    .AXI_ADDR_WIDTH ( TbAxiAddrWidthFull       ),
//    .AXI_DATA_WIDTH ( TbAxiDataWidthFull       ),
//    .AXI_ID_WIDTH   ( TbAxiIdWidthFull + 32'd1 ),
//    .AXI_USER_WIDTH ( TbAxiUserWidthFull       )
//  ) axi_bypass_amo_adapter_dv (
//    .clk_i ( clk_i )
//  );
//
//  `ACE_ASSIGN(axi_bypass, axi_bypass_dv)
//  `ACE_ASSIGN(axi_bypass_amo_adapter_dv, axi_bypass_amo_adapter)

  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  typedef ace_test::ace_rand_slave #(
                                     // AXI interface parameters
                                     .AW ( AxiAddrWidth ),
                                     .DW ( AxiDataWidth ),
                                     .IW ( AxiIdWidth + 32'd1 ),
                                     .UW ( AxiUserWidth ),
                                     // Stimuli application and test time
                                     .TA ( ApplTime         ),
                                     .TT ( TestTime         )
                                     ) axi_rand_slave_t;

  axi_rand_slave_t axi_rand_slave_data;
  axi_rand_slave_t axi_rand_slave_bypass;

  typedef snoop_test::snoop_rand_master #(
                                     // AXI interface parameters
                                     .AW ( AxiAddrWidth ),
                                     .DW ( AxiDataWidth ),
                                     // Stimuli application and test time
                                     .TA ( ApplTime         ),
                                     .TT ( TestTime         )
                                     ) snoop_rand_master_t;

  snoop_rand_master_t snoop_rand_master;

  initial begin
    axi_rand_slave_data = new( axi_data_dv );
    axi_rand_slave_bypass = new( axi_bypass_dv );
    snoop_rand_master = new( snoop_dv );
    axi_rand_slave_data.reset();
    axi_rand_slave_bypass.reset();
    snoop_rand_master.reset();
    @(posedge rst_ni);
    axi_rand_slave_data.run();
    axi_rand_slave_bypass.run();
//    snoop_rand_master.run(1);
  end

  logic start_rd, start_wr, start_snoop;
  logic check_done;

  typedef enum int {RD_REQ, WR_REQ, SNOOP_REQ} type_t;

  typedef struct packed {
    type_t req_type;
    logic [63:0] addr;
    logic [DCACHE_INDEX_WIDTH-1:0] index;
    logic [DCACHE_TAG_WIDTH-1:0]   tag;
    logic [DCACHE_INDEX_WIDTH-DCACHE_BYTE_OFFSET-1:0] mem_idx;
    snoop_pkg::acsnoop_t snoop_type;
  } current_req_t;

  current_req_t current_req;

  // DUT

  std_nbdcache  #(
    .ArianeCfg ( ArianeDefaultConfig ),
    .mst_req_t (ariane_ace::m2s_nosnoop_t),
    .mst_resp_t (ariane_ace::s2m_nosnoop_t)
  ) i_dut (
    .clk_i           ( clk_i           ),
    .rst_ni          ( rst_ni          ),
    .flush_i         ( flush_i         ),
    .flush_ack_o     ( flush_ack_o     ),
    .enable_i        ( enable_i        ),
    .miss_o          ( miss_o          ),
    .amo_req_i       ( '0 /*amo_req_i*/       ),
    .amo_resp_o      ( /*amo_resp_o*/      ),
    .req_ports_i     ( req_ports_i     ),
    .req_ports_o     ( req_ports_o     ),
    .axi_data_o      ( axi_data_o      ),
    .axi_data_i      ( axi_data_i      ),
    .axi_bypass_o    ( axi_bypass_o    ),
    .axi_bypass_i    ( axi_bypass_i    ),
    .snoop_port_o    ( snoop_port_o ),
    .snoop_port_i    ( snoop_port_i )
  );

  // AXI Atomics Adapter

//  axi_riscv_atomics_wrap #(
//      .AXI_ADDR_WIDTH     ( TbAxiAddrWidthFull       ),
//      .AXI_DATA_WIDTH     ( TbAxiDataWidthFull       ),
//      .AXI_ID_WIDTH       ( TbAxiIdWidthFull + 32'd1 ),
//      .AXI_USER_WIDTH     ( TbAxiUserWidthFull       ),
//      .AXI_MAX_WRITE_TXNS ( 1                        ),
//      .RISCV_WORD_WIDTH   ( 64                       )
//  ) i_amo_adapter (
//      .clk_i  ( clk_i                         ),
//      .rst_ni ( rst_ni                        ),
//      .mst    ( axi_bypass_amo_adapter.Master ),
//      .slv    ( axi_bypass.Slave )
//  );

  // Cache model

  cache_line_t [DCACHE_NUM_WORDS-1:0][DCACHE_SET_ASSOC-1:0] cache_status;

  logic [$clog2(DCACHE_SET_ASSOC)-1:0] lfsr;

  function logic[7:0] nextLfsr(logic[7:0] n);
    automatic logic tmp;
    tmp = !(n[7] ^ n[3] ^ n[2] ^ n[1]);
    return {n[6:0], tmp};
  endfunction

  // Tasks

  logic [2:0] active_port;

  task automatic genRdReq();
    current_req.req_type = RD_REQ;
    current_req.addr = $urandom_range(32'h8fff_ffff);
    active_port = $urandom_range(2);
    `WAIT_CYC(clk_i, 1)
    req_ports_i[active_port].data_req  = 1'b1;
    req_ports_i[active_port].data_size = 2'b11;
    req_ports_i[active_port].address_tag   = current_req.tag;
    req_ports_i[active_port].address_index = current_req.index;
    `WAIT_SIG(clk_i, req_ports_o[active_port].data_gnt)
    req_ports_i[active_port].data_req  = 1'b1;
    req_ports_i[active_port].tag_valid     = 1'b1;
    `WAIT_CYC(clk_i,1)
    req_ports_i = '0;
    `WAIT_CYC(clk_i,1)
  endtask

  task automatic genWrReq();
    current_req.req_type = WR_REQ;
    current_req.addr = $urandom_range(32'h8fff_ffff);
    active_port = $urandom_range(2);
    `WAIT_CYC(clk_i, 1)
    req_ports_i[active_port].data_req  = 1'b1;
    req_ports_i[active_port].data_we  = 1'b1;
    req_ports_i[active_port].data_be  = '1;
    req_ports_i[active_port].data_size = 2'b11;
    req_ports_i[active_port].address_tag   = current_req.tag;
    req_ports_i[active_port].tag_valid     = 1'b1;
    req_ports_i[active_port].address_index = current_req.index;
    `WAIT_SIG(clk_i, req_ports_o[active_port].data_gnt)
    req_ports_i = '0;
    `WAIT_CYC(clk_i,1)
  endtask

  // Clock and reset

  initial
    begin
      forever begin
        clk_i = 1; #(CLK_HI);
        clk_i = 0; #(CLK_LO);
      end
    end

  logic [7:0] rst_n_v = '0;

  always_ff @(posedge clk_i) begin
    rst_n_v[6:0] <= rst_n_v[7:1];
    rst_n_v[7] <= 1'b1;
  end

  assign rst_ni = rst_n_v[0];

  // Generate requests

  assign enable_i = 1'b1;
  assign flush_i = 1'b0;

  typedef enum int {IDLE, READ, WRITE, SNOOP, WAIT_CHECK} state_req_t;
  state_req_t state_req;

  int          round;

  always_ff @(posedge clk_i, rst_ni) begin
    if (!rst_ni) begin
        state_req <= IDLE;
        start_rd <= 1'b0;
        start_wr <= 1'b0;
        start_snoop <= 1'b0;
      round <= 0;
      lfsr <= 0;
    end
    else begin
        start_rd <= 1'b0;
        start_wr <= 1'b0;
        start_snoop <= 1'b0;

        case (state_req)

        IDLE: begin
            $cast(state_req, $urandom_range(SNOOP, READ));
        end

        READ: begin
            start_rd <= 1'b1;
            state_req <= WAIT_CHECK;
        end

        WRITE: begin
            start_wr <= 1'b1;
            state_req <= WAIT_CHECK;
        end

        SNOOP: begin
            start_snoop <= 1'b1;
            state_req <= WAIT_CHECK;
        end

        WAIT_CHECK: begin
            if (check_done) begin
              if (round == maxRounds) begin
                $display("Simulation end");
                $finish();
              end
              else begin
                state_req <= IDLE;
                round <= round + 1;
              end
            end
        end

        endcase
    end
  end

  initial begin
    `WAIT_CYC(clk_i,1)
    `WAIT_SIG(clk_i,~rst_ni)
    forever begin
      req_ports_i = '0;
        if (start_rd) begin
          current_req.req_type = RD_REQ;
            genRdReq();
        end
        else if (start_wr) begin
          current_req.req_type = WR_REQ;
            genWrReq();
        end
        else if (start_snoop) begin
          current_req.req_type = SNOOP_REQ;
          fork
            snoop_rand_master.run(1);
            begin
              `WAIT_SIG(clk_i,snoop.ac_valid)
              current_req.addr = snoop.ac_addr;
              current_req.snoop_type = snoop.ac_snoop;
            end
          join
        end
        `WAIT_CYC(clk_i, 1)
    end
  end

  assign current_req.index = current_req.addr[DCACHE_INDEX_WIDTH-1:0];
  assign current_req.tag = current_req.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH];
  assign current_req.mem_idx = current_req.addr[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET];

  // Check

  logic ongoing_transaction;

  always_ff @(posedge clk_i) begin
    if (~rst_ni) begin
      ongoing_transaction <= 1'b0;
    end
    else begin
      if (start_rd | start_wr | start_snoop) begin
        ongoing_transaction <= 1'b1;
      end
      if (check_done) begin
        ongoing_transaction <= 1'b0;
      end
    end
  end

  function bit isHit(
                     cache_line_t [DCACHE_SET_ASSOC-1:0][DCACHE_NUM_WORDS-1:0] cache_status,
                     current_req_t req
                     );
    for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
      if (cache_status[req.mem_idx][i].valid && cache_status[req.mem_idx][i].tag == req.tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function bit isDirty(
                       cache_line_t [DCACHE_SET_ASSOC-1:0][DCACHE_NUM_WORDS-1:0] cache_status,
                       current_req_t req
                     );
    for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
      if (cache_status[req.mem_idx][i].dirty && cache_status[req.mem_idx][i].valid && cache_status[req.mem_idx][i].tag == req.tag)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  function bit isShared(
                        cache_line_t [DCACHE_SET_ASSOC-1:0][DCACHE_NUM_WORDS-1:0] cache_status,
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

  task automatic updateCache();

    if (current_req.req_type == SNOOP_REQ) begin
      // look for the right tag
      for (int i = 0; i < DCACHE_SET_ASSOC; i++) begin
        if (valid_v[i] && cache_status[current_req.mem_idx][i].tag == current_req.tag) begin
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
    else begin
      // all ways occupied
      if (&valid_v) begin
        target_way = one_hot_to_bin(lfsr);
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

  initial begin
    bit checkOK;
    cache_status = '0;

    forever begin
      check_done = 1'b0;

      `WAIT_SIG(clk_i, ongoing_transaction)

      if (current_req.req_type == SNOOP_REQ) begin
        // expect a writeback before the response
        if (isHit(cache_status, current_req.addr) && current_req.snoop_type == snoop_pkg::CLEAN_INVALID) begin
          `WAIT_SIG(clk_i, axi_data_o.w.last)
        end
        // wait for the response
        `WAIT_SIG(clk_i, snoop_port_o.cr_valid)
        // expect the data
        if (isHit(cache_status, current_req.addr) &&
            (current_req.snoop_type == snoop_pkg::READ_UNIQUE || current_req.snoop_type == snoop_pkg::READ_ONCE || current_req.snoop_type == snoop_pkg::READ_SHARED)) begin
          `WAIT_SIG(clk_i, snoop_port_o.cd.last)
        end

      end
      else begin
        // wait for an axi transaction in case of a cache miss
        if (!isHit(cache_status, current_req.addr)) begin
          `WAIT_SIG(clk_i, axi_data_i.r.last)
        end
        // otherwise wait only for the response from the port
        else begin
          `WAIT_SIG(clk_i, {req_ports_o[active_port].data_gnt & ~axi_data_i.r.last})
        end
      end

      updateCache();

      // the actual cache needs 2 more cycles to be updated
      `WAIT_CYC(clk_i, 2)

      checkCache(checkOK);

      check_done = 1'b1;
      `WAIT_CYC(clk_i, 1)
    end
  end

endmodule
