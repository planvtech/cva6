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


// Copyright 2021 Intel Corporation. 
//
// This reference design file is subject licensed to you by the terms and 
// conditions of the applicable License Terms and Conditions for Hardware 
// Reference Designs and/or Design Examples (either as signed by you or 
// found at https://www.altera.com/common/legal/leg-license_agreement.html ).  
//
// As stated in the license, you agree to only use this reference design 
// solely in conjunction with Intel FPGAs or Intel CPLDs.  
//
// THE REFERENCE DESIGN IS PROVIDED "AS IS" WITHOUT ANY EXPRESS OR IMPLIED
// WARRANTY OF ANY KIND INCLUDING WARRANTIES OF MERCHANTABILITY, 
// NONINFRINGEMENT, OR FITNESS FOR A PARTICULAR PURPOSE. Intel does not 
// warrant or assume responsibility for the accuracy or completeness of any
// information, links or other items within the Reference Design and any 
// accompanying materials.
//
// In the event that you do not agree with such terms and conditions, do not
// use the reference design file.
/////////////////////////////////////////////////////////////////////////////

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION OFF" *)
module generic_mlab_sc #(
    parameter WIDTH = 8,
    parameter ADDR_WIDTH = 5,
    parameter FAMILY = "Other" // Agilex, S10, or Other
)(
    input clk,
    input [WIDTH-1:0] din,
    input [ADDR_WIDTH-1:0] waddr,
    input we,
    input re,
    input [ADDR_WIDTH-1:0] raddr,
    output [WIDTH-1:0] dout
);

genvar i;
generate
if (FAMILY == "S10") begin    
    reg [WIDTH-1:0] wdata_hipi;
    always @(posedge clk) wdata_hipi <= din;
        
    for (i=0; i<WIDTH; i=i+1)  begin : ml
        wire wclk_w = clk; // fix strange tristate warning
        wire rclk_w = clk; // fix strange tristate warning
        fourteennm_mlab_cell lrm (
            .clk0(wclk_w),
            .ena0(we),
            .clk1(rclk_w),
            .ena1(re),
                
            // synthesis translate off
            .clr(1'b0),
            .devclrn(1'b1),
            .devpor(1'b1),
            // synthesis translate on           

            .portabyteenamasks(1'b1),
            .portadatain(wdata_hipi[i]),
            .portaaddr(waddr),
            .portbaddr(raddr),
            .portbdataout(dout[i])          
        );

        defparam lrm .mixed_port_feed_through_mode = "dont_care";
        defparam lrm .logical_ram_name = "lrm";
        defparam lrm .logical_ram_depth = 1 << ADDR_WIDTH;
        defparam lrm .logical_ram_width = WIDTH;
        defparam lrm .first_address = 0;
        defparam lrm .last_address = (1 << ADDR_WIDTH)-1;
        defparam lrm .first_bit_number = i;
        defparam lrm .data_width = 1;
        defparam lrm .address_width = ADDR_WIDTH;
        defparam lrm .port_b_data_out_clock = "clock1";
    end
    
end else if (FAMILY == "Agilex") begin    
        
    for (i=0; i<WIDTH; i=i+1)  begin : ml
        wire wclk_w = clk; // fix strange tristate warning
        wire rclk_w = clk; // fix strange tristate warning
        tennm_mlab_cell lrm (
            .clk0(wclk_w),
            .ena0(we),
            .clk1(rclk_w),
            .ena1(re),
                
            // synthesis translate off
            .clr(1'b0),
            .devclrn(1'b1),
            .devpor(1'b1),
            // synthesis translate on           

            .portabyteenamasks(1'b1),
            .portadatain(din[i]),
            .portaaddr(waddr),
            .portbaddr(raddr),
            .portbdataout(dout[i])          
        );

        defparam lrm .mixed_port_feed_through_mode = "dont_care";
        defparam lrm .logical_ram_name = "lrm";
        defparam lrm .logical_ram_depth = 1 << ADDR_WIDTH;
        defparam lrm .logical_ram_width = WIDTH;
        defparam lrm .first_address = 0;
        defparam lrm .last_address = (1 << ADDR_WIDTH)-1;
        defparam lrm .first_bit_number = i;
        defparam lrm .data_width = 1;
        defparam lrm .address_width = ADDR_WIDTH;
        defparam lrm .port_b_data_out_clock = "clock1";
    end
    
    
end else begin

    localparam DEPTH = 1 << ADDR_WIDTH;
    (* ramstyle = "mlab" *) reg [WIDTH-1:0] mem[0:DEPTH-1];

    reg [WIDTH-1:0] dout_r;
    always @(posedge clk) begin
        if (we)
            mem[waddr] <= din;
        if (re)
            dout_r <= mem[raddr];
    end
    assign dout = dout_r;

end
endgenerate    

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "R3irhJhRaBV775Q+lPNblITiagOrEXXY46IvS8uXdKET9f3Dbn1wK/LVY9tbL2G44obBje21CSsgqsh1uXX008/D12XJlJ1OP8Hb23E4b5ohUPbExYnXim20I4k7HneDfRqKDv3rMwQg+yj37YUo5UBkuwTUcbzH3uOCBfONi5B2d4r0wPdKz64BGvf2doVeBT/FMA0aDuc37hGTZDIgrryzsZQq0CLN3DKVyPrPFKLsLBoO/zopx1GXazckGMQRWCrCknQV8DUpCvuuELIhx84N97KYjGInKTAnnGtSWHn3CQt3/gOkQIjh2Ln2TovuK9kTFdRj5mwOVWVpjjNSEuhXGj8hhgSG22LgbYWhhy4Sp2jrSuulmot8GPIkBWcCOOliD57yShAnY4Y7U3c7laRoAJtbxWBt/GnzRFV+u2qbFqrzL5Cl11fytvIkNxPeE7bqQrmy8ZrWhiEoeHokgTvtT46mLOVLgiMNzkr0FmjKliSiLd9yR83MnbSkNhAFCXQmgynTokiRuCSp9TIX/KoLSToa/gnLwBWdMjPluGdtyFysapelMGYBu6W8qaUq3kxNbeDs/dK9RG+AFEVTD2MDOIIBtAFhiSe783sVQaZxvlFNypqMQPmFsACWWQ75xCOkMjQo3k6/4FXFlLqrlA0cLWHyyvmAIGi3ITVb8pcwWFpXb3btBPO2t1+/HC+ZO0A912d3H9x+xM2OLCHAkRWqtEcoSf1oNWUmIKu6OCg1ic1ZXy0bBWUQiS9pLRDV2jLeeImp7/jIMc+2ft9O8hVyN1Qf7VELa7boBL1gMPi+wl14iFRWhvPnIs331dNm7GedMtypm1NWonT5oSXu3M55VBoUMPMPw/cWyAT39Uq3cmoDCYMVP+wstKtfewHGkeqw6Gacu5N8nbihtRZwGbKWA9kcrx7osZtklPPiAisF0MxMSRKHFsIUYaiqIJRf3ZgBCxF1fvpGoMPEOXkNncd1QW278+7UeddJIDd9aWDFJKUjW3en++E9a+Ta/s1/"
`endif