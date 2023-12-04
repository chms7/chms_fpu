//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_fdivsqrt.sv
//
// Description  : Div & sqrt unit of fpu.
//                FDIV FSQRT
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

// ! currently not supported, use gcc -mno-fdiv now
module fpu_fdivsqrt #(
  // config
  parameter fpu_pkg::fp_format_e FP_FMT = fpu_pkg::FP32,
  // local
  localparam FLEN = fpu_pkg::flen_bits(FP_FMT)
)(
  input  logic                           i_clk,
  input  logic                           i_rst_n,
  // operands
  input  logic [3:1] [FLEN-1:0]          i_rs,
  // operation
  input  logic [fpu_pkg::FPU_OP_NUM-1:0] i_op,
  // round mode
  input  fpu_pkg::roundmode_e            i_rm,
  // input handshake
  input  logic                           i_in_valid,
  output logic                           o_in_ready,
  // result & fflags
  output logic [FLEN-1:0]                o_result,
  output fpu_pkg::fflags_t               o_fflags,
  // output handshake
  output logic                           o_out_valid,
  input  logic                           i_out_ready
);
  // parameters
  localparam EXP_WIDTH = fpu_pkg::exp_bits(FP_FMT);
  localparam MAN_WIDTH = fpu_pkg::man_bits(FP_FMT);


  assign o_in_ready = 1'b0;
  assign o_out_valid = 1'b0;
  assign o_result = 0;
  assign o_fflags = 0;

endmodule //fpu_fdivsqrt