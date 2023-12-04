//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_utils_fpinfo.sv
//
// Description  : Decode infomation of input operands
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_utils_rsinfo #(
  // config
  parameter  fpu_pkg::fp_format_e FP_FMT = fpu_pkg::fp_format_e'(0),
  parameter  RS_NUM = 3,
  // local
  localparam FLEN     = fpu_pkg::flen_bits(FP_FMT),
  localparam EXP_BITS = fpu_pkg::exp_bits (FP_FMT),
  localparam MAN_BITS = fpu_pkg::man_bits (FP_FMT)
) (
  input  logic [RS_NUM:1] [FLEN-1:0]   i_rs,
  output fpu_pkg::fp_info_t [RS_NUM:1] o_rs_info,
  output fpu_pkg::fp_info_any_t        o_rs_info_any
);
  // operand
  typedef struct packed {
    logic                sign;
    logic [EXP_BITS-1:0] exponent;
    logic [MAN_BITS-1:0] mantissa;
  } fp_num_t;
  fp_num_t [3:1] rs;

  genvar i;
  generate // each operand is normal/inf/...
    for (i = 1; i <= RS_NUM; i++) begin: gen_fp_info
      assign rs[i] = '{sign:     i_rs[i][FLEN-1],
                       exponent: i_rs[i][FLEN-2:FLEN-EXP_BITS-1],
                       mantissa: i_rs[i][MAN_BITS-1:0]};
      assign o_rs_info[i] = '{is_normal:    (rs[i].exponent != '0) & (rs[i].exponent != '1),
                              is_inf:       (rs[i].exponent == '1) & (rs[i].mantissa == '0),
                              is_nan:       (rs[i].exponent == '1) & (rs[i].mantissa != '0),
                              is_zero:      (rs[i].exponent == '0) & (rs[i].mantissa == '0),
                              is_subnormal: (rs[i].exponent == '0) & !o_rs_info[i].is_zero,
                              is_signalling: o_rs_info[i].is_nan   & (rs[i].mantissa[MAN_BITS-1] == 1'b0),
                              is_quiet:      o_rs_info[i].is_nan   & !o_rs_info[i].is_signalling};
    end
  endgenerate

  generate // any operand is inf/nan/signalling_nan
    if (RS_NUM == 3) begin
      assign o_rs_info_any.any_inf             = (| {o_rs_info[1].is_inf,        o_rs_info[2].is_inf,        o_rs_info[3].is_inf});
      assign o_rs_info_any.any_nan             = (| {o_rs_info[1].is_nan,        o_rs_info[2].is_nan,        o_rs_info[3].is_nan});
      assign o_rs_info_any.any_signalling_nan  = (| {o_rs_info[1].is_signalling, o_rs_info[2].is_signalling, o_rs_info[3].is_signalling});
    end else if (RS_NUM == 2) begin
      assign o_rs_info_any.any_inf             = (| {o_rs_info[1].is_inf,        o_rs_info[2].is_inf});
      assign o_rs_info_any.any_nan             = (| {o_rs_info[1].is_nan,        o_rs_info[2].is_nan});
      assign o_rs_info_any.any_signalling_nan  = (| {o_rs_info[1].is_signalling, o_rs_info[2].is_signalling});
    end else begin
      assign o_rs_info_any.any_inf             = o_rs_info[1].is_inf       ;
      assign o_rs_info_any.any_nan             = o_rs_info[1].is_nan       ;
      assign o_rs_info_any.any_signalling_nan  = o_rs_info[1].is_signalling;
    end
  endgenerate
  
endmodule