//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_utils_round.sv
//
// Description  : Round module
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_utils_round #(
  parameter int unsigned AbsWidth=2 // Width of the abolute value, without sign bit
) (
  // Input value
  input logic [AbsWidth-1:0]   abs_value_i,             // absolute value without sign
  input logic                  sign_i,
  // Rounding information
  input logic [1:0]            round_sticky_bits_i,     // round and sticky bits {RS}
  input fpu_pkg::roundmode_e   rnd_mode_i,
  input logic                  effective_subtraction_i, // sign of inputs affects rounding of zeroes
  // Output value
  output logic [AbsWidth-1:0]  abs_rounded_o,           // absolute value without sign
  output logic                 sign_o,
  // Output classification
  output logic                 exact_zero_o             // output is an exact zero
);
  // Rounding decision
  logic round_up;

  // Take the rounding decision according to RISC-V spec
  // RoundMode | Mnemonic | Meaning
  // :--------:|:--------:|:-------
  //    000    |   RNE    | Round to Nearest, ties to Even
  //    001    |   RTZ    | Round towards Zero
  //    010    |   RDN    | Round Down (towards -\infty)
  //    011    |   RUP    | Round Up (towards \infty)
  //    100    |   RMM    | Round to Nearest, ties to Max Magnitude
  //    101    |   ROD    | Round towards odd (this mode is not define in RISC-V FP-SPEC)
  //  others   |          | *invalid*
  always @ (*) begin
    case (rnd_mode_i)
      fpu_pkg::RNE: // Decide accoring to round/sticky bits
        case (round_sticky_bits_i)
          2'b00,
          2'b01:    round_up = 1'b0;           // < ulp/2 away, round down
          2'b10:    round_up = abs_value_i[0]; // = ulp/2 away, round towards even result
          2'b11:    round_up = 1'b1;           // > ulp/2 away, round up
          default:  round_up = 1'b0;
        endcase
      fpu_pkg::RTZ: round_up = 1'b0; // always round down
      fpu_pkg::RDN: round_up = (| round_sticky_bits_i) ? sign_i  : 1'b0; // to 0 if +, away if -
      fpu_pkg::RUP: round_up = (| round_sticky_bits_i) ? ~sign_i : 1'b0; // to 0 if -, away if +
      fpu_pkg::RMM: round_up = round_sticky_bits_i[1]; // round down if < ulp/2 away, else up
      default:      round_up = 1'b0;
    endcase
  end

  // Perform the rounding, exponent change and overflow to inf happens automagically
  assign abs_rounded_o = abs_value_i + round_up;

  // True zero result is a zero result without dirty round/sticky bits
  assign exact_zero_o = (abs_value_i == '0) && (round_sticky_bits_i == '0);

  // In case of effective subtraction (thus signs of addition operands must have differed) and a
  // true zero result, the result sign is '-' in case of RDN and '+' for other modes.
  assign sign_o = (exact_zero_o && effective_subtraction_i)
                  ? (rnd_mode_i == fpu_pkg::RDN)
                  : sign_i;

endmodule
