// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// $File: //acds/prototype/mm_s10/ip/avalon_st/altera_avalon_st_pipeline_stage/altera_avalon_st_pipeline_base.v $
// $Revision: #2 $
// $Date: 2015/05/15 $
// $Author: jyeap $
//------------------------------------------------------------------------------

`timescale 1ns / 1ns

module alt_hiconnect_pipeline_base (
                                       clk,
                                       reset,
                                       in_ready,
                                       in_valid,
                                       in_data,
                                       out_ready,
                                       out_valid,
                                       out_data
                                       );

   parameter SYMBOLS_PER_BEAT = 1;
   parameter BITS_PER_SYMBOL  = 8;
   parameter PIPELINE_READY   = 1;
   localparam DATA_WIDTH = SYMBOLS_PER_BEAT * BITS_PER_SYMBOL;
   
   input clk;
   input reset;
   
   output in_ready;
   input  in_valid;
   input [DATA_WIDTH-1:0] in_data;
   
   input                  out_ready;
   output                 out_valid;
   output [DATA_WIDTH-1:0] out_data;
   
   reg                     internal_sclr;
   reg                     full0;
   reg                     full1;
   reg [DATA_WIDTH-1:0]    data0;
   reg [DATA_WIDTH-1:0]    data1;

   assign out_valid = full1;
   assign out_data  = data1;    

   always @(posedge clk) begin
      internal_sclr <= reset;
   end
   
   generate if (PIPELINE_READY == 1) 
     begin : REGISTERED_READY_PLINE
        
        assign in_ready  = !full0;

        always @(posedge clk) begin
           // ----------------------------
           // always load the second slot if we can
           // ----------------------------
           if (~full0)
             data0 <= in_data;
           // ----------------------------
           // first slot is loaded either from the second,
           // or with new data
           // ----------------------------
           if (~full1 || (out_ready && out_valid)) begin
              if (full0)
                data1 <= data0;
              else
                data1 <= in_data;
           end
        end
        
        always @(posedge clk) begin
           if (internal_sclr) begin
              full0 <= 1'b0;
              full1 <= 1'b0;
           end else begin
              // no data in pipeline
              if (~full0 & ~full1) begin
                 if (in_valid) begin
                    full1 <= 1'b1;
                 end
              end // ~f1 & ~f0

              // one datum in pipeline 
              if (full1 & ~full0) begin
                 if (in_valid & ~out_ready) begin
                    full0 <= 1'b1;
                 end
                 // back to empty
                 if (~in_valid & out_ready) begin
                    full1 <= 1'b0;
                 end
              end // f1 & ~f0
              
              // two data in pipeline 
              if (full1 & full0) begin
                 // go back to one datum state
                 if (out_ready) begin
                    full0 <= 1'b0;
                 end
              end // end go back to one datum stage
           end
        end

     end 
   else 
     begin : UNREGISTERED_READY_PLINE
        
        // we're ready if the slot is unoccupied, or if the output is ready
        assign in_ready = (~full1) | out_ready;
        
        always @(posedge clk) begin
           if (in_ready) begin
              data1 <= in_data;
           end
        end                

        always @(posedge clk) begin
           if (internal_sclr) begin
              full1 <= 1'b0;
           end
           else begin
              if (in_ready) begin
                 full1 <= in_valid;
              end
           end
        end

     end
   endgenerate
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "Uvb1RXDYA9UDTGON5pfGJPuL4j7hJVCNfWkSTJVvFo7zxw5rwC1G1nW0lMejrfWDp2SUNNBhmK9lw3dBKxdQJtYrgW7DcG+Un1On5eLthnlyT8jptzHh3Udih41mqUZiB01eJZ92cOfgb6gwyHY22V4yxhRp4jgKMhH06DnlFYOiL2hvdYYJTA5dW7HZ1reY4F9l8vaJ6gTS8CyiKwF3H5PlPgIrxdVnnffXi6z3wfnXV4HzhdJ1WmthMEBghSa1FzjUuUzvLhR7MEVWh8Od9U+R5KWsHqVPLuL1pE5zVlQwZTsd+ZvQTCMZnI6OH7aLI5Qlhau1SNn7taWW2B9bDh/Lyk6QJBwymgylNJ6e94fKSS9YHNA0Cyw8ZHlhTKQCW/opDdCgYfIPjluJQQww66F7ccohMcijZbQCu4BLBlQtasY+XvNjhCDaZHpFw34wLbN0WmCXfeTB4Hc3vWt5/Moy6HFDJN3G/IWoxrWITCXcvyhFTJRp7BYSIQrvDQ0gk6B28EYl8DRz6ylRao9uMDOQNOs2l8qTFyQnGKm6Efo+98vRylj6C4sSsMquQwegIfGwZP30/4bljwNvLdVlM5b1j+n07RbOHnMRTqnNmq0gaKxSAegxnCOo/Hq1Qni5yIBmPWD7UOsUa+/vZ3/3A4+EcKP/yjIsp1YrlwLp1zpbRGHhGZovsyJTV1F385CPPaW2xErZErBi9SepzRMYghypdzWLHXZ0J0Gx4jHuqj6BtKlcFUEKVx/15DmTaf9rFw9vTrFoZpatW2uApcoLmzY0o+bgn/SQrkRrQLz7XVFMC9rnMTcrRsVcA00WCAFVc9l7BMMiRWHXCvJIs90REsdpGb6Dk9wbpiIhlNAKRh4HT3YaQT7vcGgWOp7Y0KraA/0TTer5+GCwPmv1oVcXm2Qkcq3tmyMeAQyLog0bnBxvRIhzZm4nHba0n4BoTI3SFGCgcsTEGWaDujET2sovw6jbFm1CzaLcQ1edgo066waWVN3uXkBpfIMVuwcNHDc1"
`endif