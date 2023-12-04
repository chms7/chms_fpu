//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_pkg.sv
//
// Description  : Package for fpu
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/10ps
package fpu_pkg;

// * fpu format
typedef enum logic [3:0] {
  FP32    = 'd0, // ! only fp32 now
  FP64    = 'd1,
  FP16    = 'd2,
  FP8     = 'd3
} fp_format_e;

// * encoding
typedef struct packed {
  int unsigned exp_bits;
  int unsigned man_bits;
} fp_encoding_t;

localparam fp_encoding_t [0:3] FP_ENCODINGS  = '{
  '{8,  23}, // IEEE binary32 (single)
  '{11, 52}, // IEEE binary64 (double)
  '{5,  10}, // IEEE binary16 (half)
  '{5,  2}   // custom binary8
};

// get fp operand width
function automatic int unsigned flen_bits(fp_format_e fmt);
  return FP_ENCODINGS[fmt].exp_bits + FP_ENCODINGS[fmt].man_bits + 1;
endfunction
// get exponent bits
function automatic int unsigned exp_bits(fp_format_e fmt);
  return FP_ENCODINGS[fmt].exp_bits;
endfunction
// get mantissa bits
function automatic int unsigned man_bits(fp_format_e fmt);
  return FP_ENCODINGS[fmt].man_bits;
endfunction
// get bias
function automatic int unsigned bias(fp_format_e fmt);
  return unsigned'(2**(FP_ENCODINGS[fmt].exp_bits-1)-1);
endfunction

// * operation
localparam int unsigned FPU_OP_NUM = 19;
typedef enum logic [FPU_OP_NUM-1:0] {
  // fma
  FPU_OP_FMADD   = 19'b000_0000_0000_0000_0001,
  FPU_OP_FMSUB   = 19'b000_0000_0000_0000_0010,
  FPU_OP_FNMSUB  = 19'b000_0000_0000_0000_0100,
  FPU_OP_FNMADD  = 19'b000_0000_0000_0000_1000,
  FPU_OP_FADD    = 19'b000_0000_0000_0001_0000,
  FPU_OP_FSUB    = 19'b000_0000_0000_0010_0000,
  FPU_OP_FMUL    = 19'b000_0000_0000_0100_0000,
  // fdivsqrt
  FPU_OP_FDIV    = 19'b000_0000_0000_1000_0000,
  FPU_OP_FSQRT   = 19'b000_0000_0001_0000_0000,
  // fcmp
  FPU_OP_FCMP    = 19'b000_0000_0010_0000_0000,
  FPU_OP_FMINMAX = 19'b000_0000_0100_0000_0000,
  FPU_OP_FSGNJ   = 19'b000_0000_1000_0000_0000,
  FPU_OP_FCLASS  = 19'b000_0001_0000_0000_0000,
  // fconv
  FPU_OP_FMVXW   = 19'b000_0010_0000_0000_0000,
  FPU_OP_FMVWX   = 19'b000_0100_0000_0000_0000,
  FPU_OP_FCVTSW  = 19'b000_1000_0000_0000_0000,
  FPU_OP_FCVTSWU = 19'b001_0000_0000_0000_0000,
  FPU_OP_FCVTWS  = 19'b010_0000_0000_0000_0000,
  FPU_OP_FCVTWUS = 19'b100_0000_0000_0000_0000
} operation_e;

// * round mode
typedef enum logic [2:0] {
  RNE = 3'b000,
  RTZ = 3'b001,
  RDN = 3'b010,
  RUP = 3'b011,
  RMM = 3'b100,
  DYN = 3'b111
} roundmode_e;

// * fflags
typedef struct packed {
  logic NV; // Invalid
  logic DZ; // Divide by zero
  logic OF; // Overflow
  logic UF; // Underflow
  logic NX; // Inexact
} fflags_t;

// * operand info
typedef struct packed {
  logic is_normal;     // is the value normal
  logic is_subnormal;  // is the value subnormal
  logic is_zero;       // is the value zero
  logic is_inf;        // is the value infinity
  logic is_nan;        // is the value NaN
  logic is_signalling; // is the value a signalling NaN
  logic is_quiet;      // is the value a quiet NaN
  // logic is_boxed;      // is the value properly NaN-boxed (RISC-V specific)
} fp_info_t;

typedef struct packed {
  logic any_inf;
  logic any_nan;
  logic any_signalling_nan;
} fp_info_any_t;

// * class info
typedef enum logic [9:0] {
  NEGINF     = 10'b00_0000_0001,
  NEGNORM    = 10'b00_0000_0010,
  NEGSUBNORM = 10'b00_0000_0100,
  NEGZERO    = 10'b00_0000_1000,
  POSZERO    = 10'b00_0001_0000,
  POSSUBNORM = 10'b00_0010_0000,
  POSNORM    = 10'b00_0100_0000,
  POSINF     = 10'b00_1000_0000,
  SNAN       = 10'b01_0000_0000,
  QNAN       = 10'b10_0000_0000
} class_info_e;
  
endpackage