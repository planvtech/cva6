// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Description: This file contains power-related cells
//              Mainly shifters at the moment.


module tc_pwr_level_shifter_in (
  input  logic in_i,
  output logic out_o
);

  assign out_o = in_i;

endmodule

module tc_pwr_level_shifter_in_clamp_lo (
  input  logic in_i,
  output logic out_o,
  input  logic clamp_i
);

  assign out_o = clamp_i ? 1'b0 : in_i;

endmodule

module tc_pwr_level_shifter_in_clamp_hi (
  input  logic in_i,
  output logic out_o,
  input  logic clamp_i
);

  assign out_o = clamp_i ? 1'b1 : in_i;

endmodule

module tc_pwr_level_shifter_out (
  input  logic in_i,
  output logic out_o
);

  assign out_o = in_i;

endmodule

module tc_pwr_level_shifter_out_clamp_lo (
  input  logic in_i,
  output logic out_o,
  input  logic clamp_i
);

  assign out_o = clamp_i ? 1'b0 : in_i;

endmodule

module tc_pwr_level_shifter_out_clamp_hi (
  input  logic in_i,
  output logic out_o,
  input  logic clamp_i
);

  assign out_o = clamp_i ? 1'b1 : in_i;

endmodule

module tc_pwr_power_gating (
  input  logic sleep_i,
  output logic sleepout_o
);

  assign sleepout_o = sleep_i;

endmodule

module tc_pwr_isolation_lo (
  input  logic data_i,
  input  logic ena_i,
  output logic data_o
);

  assign data_o = ena_i ? data_i : 1'b0;

endmodule

module tc_pwr_isolation_hi (
  input  logic data_i,
  input  logic ena_i,
  output logic data_o
);

  assign data_o = ena_i ? data_i : 1'b1;

endmodule
