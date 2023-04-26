// interface to the dcache request / response ports
// for use in testbenches
interface dcache_intf (
    input logic clk
);
    import ariane_pkg::*; 

    // request / response between CPU core and dcache 
    dcache_req_i_t req;
    dcache_req_o_t resp;

    // this should be hooked up to the gnt_i input of the cache_ctrl instance 
    // to detect when a write request is accepted
    logic          wr_gnt;

endinterface
