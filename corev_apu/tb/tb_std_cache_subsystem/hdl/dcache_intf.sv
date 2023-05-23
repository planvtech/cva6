//------------------------------------------------------------------------------
// interface to the dcache request / response ports
//------------------------------------------------------------------------------
interface dcache_intf (
    input logic clk
);
    import ariane_pkg::*; 

    // request / response between CPU core and dcache 
    dcache_req_i_t req;
    dcache_req_o_t resp;

    // this should be hooked up to (cache_ctrl.gnt_i && (cache_ctrl.state==IDLE))
    // to detect when a write request is accepted
    logic          wr_gnt;

endinterface

//------------------------------------------------------------------------------
// interface to probe internal SRAM
//------------------------------------------------------------------------------
interface dcache_sram_if (input logic clk);
    import ariane_pkg::*;
    import std_cache_pkg::*;

    // interface for probing into sram

    typedef logic [4*DCACHE_DIRTY_WIDTH-1:0] vld_t;
    typedef logic [63:0]                     data_t;
    typedef logic [63:0]                     tag_t;
    typedef data_t                           data_sram_t [DCACHE_NUM_WORDS-1:0];
    typedef tag_t                            tag_sram_t  [DCACHE_NUM_WORDS-1:0];
    typedef vld_t                            vld_sram_t  [DCACHE_NUM_WORDS-1:0];

    data_sram_t data_sram [1:0][DCACHE_SET_ASSOC-1:0];
    tag_sram_t  tag_sram       [DCACHE_SET_ASSOC-1:0];
    vld_sram_t  vld_sram;
endinterface

//------------------------------------------------------------------------------
// interface to probe internal cache grant signals
//------------------------------------------------------------------------------
interface dcache_gnt_if (input logic clk);
    logic [4:0] gnt;
    logic [4:0] rd_gnt;
    logic [3:0] bypass_gnt;
endinterface
