// Copyright 2017-2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Max Bjurling, PlanV GmbH
// Description: CVA6 Top-level module with only cache subsystem instantiated
//              Used for unit testing of cache

module cva6_cache_dummy
  import ariane_pkg::*;
#(
  parameter ariane_pkg::ariane_cfg_t ArianeCfg  = ariane_pkg::ArianeDefaultConfig,
  parameter type                     mst_req_t  = logic,
  parameter type                     mst_resp_t = logic
) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  // Unused I/O
  input  logic [riscv::VLEN-1:0] boot_addr_i,
  input  logic [riscv::XLEN-1:0] hart_id_i,
  input  logic [1:0]             irq_i,
  input  logic                   ipi_i,
  input  logic                   time_irq_i,
  input  logic                   debug_req_i,
  output cvxif_pkg::cvxif_req_t  cvxif_req_o,
  input  cvxif_pkg::cvxif_resp_t cvxif_resp_i,
  // memory side, AXI Master
  output mst_req_t               axi_req_o,
  input  mst_resp_t              axi_resp_i
);

  riscv::priv_lvl_t         priv_lvl;

  logic                     icache_en_csr;
  logic                     icache_flush_ctrl_cache;
  logic                     icache_miss_cache_perf;
  icache_areq_i_t           icache_areq_ex_cache;
  icache_areq_o_t           icache_areq_cache_ex;
  icache_dreq_i_t           icache_dreq_if_cache;
  icache_dreq_o_t           icache_dreq_cache_if;

  logic                     dcache_miss_cache_perf;
  logic                     dcache_en_csr_nbdcache;
  logic                     dcache_flush_ctrl_cache;
  logic                     dcache_flush_ack_cache_ctrl;

  dcache_req_i_t [2:0]      dcache_req_ports_ex_cache;
  dcache_req_o_t [2:0]      dcache_req_ports_cache_ex;
  logic                     dcache_commit_wbuffer_empty;
  logic                     dcache_commit_wbuffer_not_ni;

  amo_req_t                 amo_req;
  amo_resp_t                amo_resp;


  assign icache_en_csr            = 1'b1;
  assign icache_flush_ctrl_cache  = 1'b0;
  assign icache_areq_ex_cache     = '0;
  assign icache_dreq_if_cache     = '0;

  assign cvxif_req_o = '0;

  assign priv_lvl_i = riscv::PRIV_LVL_M;





  // -------------------
  // Cache Subsystem
  // -------------------

`ifdef WT_DCACHE
  // this is a cache subsystem that is compatible with OpenPiton
  wt_cache_subsystem #(
    .ArianeCfg            ( ArianeCfg     )
  ) i_cache_subsystem (
    // to D$
    .clk_i                 ( clk_i                       ),
    .rst_ni                ( rst_ni                      ),
    // I$
    .icache_en_i           ( icache_en_csr               ),
    .icache_flush_i        ( icache_flush_ctrl_cache     ),
    .icache_miss_o         ( icache_miss_cache_perf      ),
    .icache_areq_i         ( icache_areq_ex_cache        ),
    .icache_areq_o         ( icache_areq_cache_ex        ),
    .icache_dreq_i         ( icache_dreq_if_cache        ),
    .icache_dreq_o         ( icache_dreq_cache_if        ),
    // D$
    .dcache_enable_i       ( dcache_en_csr_nbdcache      ),
    .dcache_flush_i        ( dcache_flush_ctrl_cache     ),
    .dcache_flush_ack_o    ( dcache_flush_ack_cache_ctrl ),
    // to commit stage
    .dcache_amo_req_i      ( amo_req                     ),
    .dcache_amo_resp_o     ( amo_resp                    ),
    // from PTW, Load Unit  and Store Unit
    .dcache_miss_o         ( dcache_miss_cache_perf      ),
    .dcache_req_ports_i    ( dcache_req_ports_ex_cache   ),
    .dcache_req_ports_o    ( dcache_req_ports_cache_ex   ),
    // write buffer status
    .wbuffer_empty_o       ( dcache_commit_wbuffer_empty ),
    .wbuffer_not_ni_o      ( dcache_commit_wbuffer_not_ni ),
`ifdef PITON_ARIANE
    .l15_req_o             ( l15_req_o                   ),
    .l15_rtrn_i            ( l15_rtrn_i                  )
`else
    // memory side
    .axi_req_o             ( axi_req_o                   ),
    .axi_resp_i            ( axi_resp_i                  )
`endif
  );
`else

  std_cache_subsystem #(
    // note: this only works with one cacheable region
    // not as important since this cache subsystem is about to be
    // deprecated
    .ArianeCfg             ( ArianeCfg                   ),
    .mst_req_t (mst_req_t),
    .mst_resp_t (mst_resp_t)
  ) i_cache_subsystem (
    // to D$
    .clk_i                 ( clk_i                       ),
    .rst_ni                ( rst_ni                      ),
    .priv_lvl_i            ( priv_lvl                    ),
    // I$
    .icache_en_i           ( icache_en_csr               ),
    .icache_flush_i        ( icache_flush_ctrl_cache     ),
    .icache_miss_o         ( icache_miss_cache_perf      ),
    .icache_areq_i         ( icache_areq_ex_cache        ),
    .icache_areq_o         ( icache_areq_cache_ex        ),
    .icache_dreq_i         ( icache_dreq_if_cache        ),
    .icache_dreq_o         ( icache_dreq_cache_if        ),
    // D$
    .dcache_enable_i       ( dcache_en_csr_nbdcache      ),
    .dcache_flush_i        ( dcache_flush_ctrl_cache     ),
    .dcache_flush_ack_o    ( dcache_flush_ack_cache_ctrl ),
    // to commit stage
    .amo_req_i             ( amo_req                     ),
    .amo_resp_o            ( amo_resp                    ),
    .dcache_miss_o         ( dcache_miss_cache_perf      ),
    // this is statically set to 1 as the std_cache does not have a wbuffer
    .wbuffer_empty_o       ( dcache_commit_wbuffer_empty ),
    // from PTW, Load Unit  and Store Unit
    .dcache_req_ports_i    ( dcache_req_ports_ex_cache   ),
    .dcache_req_ports_o    ( dcache_req_ports_cache_ex   ),
    // memory side
    .axi_req_o             ( axi_req_o                   ),
    .axi_resp_i            ( axi_resp_i                  )
  );
  assign dcache_commit_wbuffer_not_ni = 1'b1;
`endif

  // -------------------
  // Parameter Check
  // -------------------
  // pragma translate_off
  `ifndef VERILATOR
  initial ariane_pkg::check_cfg(ArianeCfg);
  `endif
  // pragma translate_on

endmodule // cva6_cache_dummy
