//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_fcmp.sv
//
// Description  : Compare unit of fpu
//                FLE FLT FEQ FMIN FMAX FSGNJ FSGNJN FSGNJX FCLASS
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_fcmp #(
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
  // * ---------------------
  // * Parameters & Defines
  // * ---------------------
  localparam EXP_WIDTH = fpu_pkg::exp_bits(FP_FMT);
  localparam MAN_WIDTH = fpu_pkg::man_bits(FP_FMT);
  // fp operand
  typedef struct packed {
    logic                sign;
    logic [EXP_WIDTH-1:0] exponent;
    logic [MAN_WIDTH-1:0] mantissa;
  } fp_num_t;

  // * ---------------
  // * Input Process
  // * ---------------
  // input operands
  fp_num_t [2:1] rs;
  assign rs[1] = '{sign:     i_rs[1][FLEN-1],
                   exponent: i_rs[1][FLEN-2:FLEN-EXP_WIDTH-1],
                   mantissa: i_rs[1][MAN_WIDTH-1:0]};
  assign rs[2] = '{sign:     i_rs[2][FLEN-1],
                   exponent: i_rs[2][FLEN-2:FLEN-EXP_WIDTH-1],
                   mantissa: i_rs[2][MAN_WIDTH-1:0]};

  // operands info
  fpu_pkg::fp_info_t [2:1] rs_info;
  fpu_pkg::fp_info_any_t   rs_info_any;
  fpu_utils_rsinfo #(
    .FP_FMT        ( FP_FMT             ),
    .RS_NUM        ( 2                  )
  ) u_fpu_utils_rsinfo (
    .i_rs          ( {i_rs[2], i_rs[1]} ),
    .o_rs_info     ( rs_info            ),
    .o_rs_info_any ( rs_info_any        )
  );
  wire rs_equal    = (i_rs[1] == i_rs[2]) || (rs_info[1].is_zero && rs_info[2].is_zero);
  wire rs1_smaller = (i_rs[1] <  i_rs[2]) ^  (rs[1].sign || rs[2].sign);

  // * ---------
  // * CMP
  // * ---------
  logic [FLEN-1:0]     cmp_result;
  fpu_pkg::fflags_t    cmp_fflags;

  always @ (*) begin
    cmp_result = '0;
    cmp_fflags = '0;
    if (rs_info_any.any_signalling_nan) cmp_fflags.NV = 1'b1;
    else begin
      case (i_rm)
        fpu_pkg::RNE: begin // LE
          if (rs_info_any.any_nan) cmp_fflags.NV = 1'b1;
          else cmp_result = rs1_smaller | rs_equal;
        end
        fpu_pkg::RTZ: begin // LT
          if (rs_info_any.any_nan) cmp_fflags.NV = 1'b1;
          else cmp_result = rs1_smaller & ~rs_equal;
        end
        fpu_pkg::RDN: begin // EQ
          if (rs_info_any.any_nan) cmp_result = '0; // nan not equal
          else                     cmp_result = rs_equal;
        end
        default: begin
          cmp_result = '0;
          cmp_fflags = '0;
        end
      endcase
    end
  end
  
  // * ---------
  // * MINMAX
  // * ---------
  logic [FLEN-1:0]     minmax_result;
  fpu_pkg::fflags_t    minmax_fflags;
  
  always @ (*) begin
    minmax_fflags = '0;
    minmax_fflags.NV = rs_info_any.any_signalling_nan;
    if (rs_info[1].is_nan & rs_info[2].is_nan) // both nan -> qNaN
      minmax_result = {1'b0, {EXP_WIDTH{1'b1}}, {1'b1, {(MAN_WIDTH-1){1'b0}}}};
    else if (rs_info[1].is_nan)                // rs1 nan  -> rs2
      minmax_result = {rs[2].sign, rs[2].exponent, rs[2].mantissa};
    else if (rs_info[2].is_nan)                // rs2 nan  -> rs1
      minmax_result = {rs[1].sign, rs[1].exponent, rs[1].mantissa};
    else begin
      case (i_rm)
        fpu_pkg::RNE: begin // MIN
          if (rs1_smaller) minmax_result = {rs[1].sign, rs[1].exponent, rs[1].mantissa};
          else             minmax_result = {rs[2].sign, rs[2].exponent, rs[2].mantissa};
        end
        fpu_pkg::RTZ: begin // MAX
          if (rs1_smaller) minmax_result = {rs[2].sign, rs[2].exponent, rs[2].mantissa};
          else             minmax_result = {rs[1].sign, rs[1].exponent, rs[1].mantissa};
        end
        default: minmax_result = '0;
      endcase
    end
  end
  
  // * ---------
  // * SGNJ
  // * ---------
  logic [FLEN-1:0]     sgnj_result;
  fpu_pkg::fflags_t    sgnj_fflags = '{default: '0}; // sgnj never set fflags

  always @ (*) begin
    case (i_rm)
      fpu_pkg::RNE: sgnj_result = { rs[2].sign,              rs[1].exponent, rs[1].mantissa}; // SGNJ
      fpu_pkg::RTZ: sgnj_result = {~rs[2].sign,              rs[1].exponent, rs[1].mantissa}; // SGNJN
      fpu_pkg::RDN: sgnj_result = { rs[1].sign ^ rs[2].sign, rs[1].exponent, rs[1].mantissa}; // SGNJX
      default:      sgnj_result = { rs[1].sign,              rs[1].exponent, rs[1].mantissa};
    endcase
  end
  
  // * ---------
  // * CLASS
  // * ---------
  fpu_pkg::class_info_e class_info;
  wire [FLEN-1:0]       class_result = {'0, class_info};
  fpu_pkg::fflags_t     class_fflags = '{default: '0}; // classify never set fflags

  always @ (*) begin
    if      (rs_info[1].is_normal   ) class_info = rs[1].sign ? fpu_pkg::NEGNORM    : fpu_pkg::POSNORM;
    else if (rs_info[1].is_subnormal) class_info = rs[1].sign ? fpu_pkg::NEGSUBNORM : fpu_pkg::POSSUBNORM;
    else if (rs_info[1].is_zero     ) class_info = rs[1].sign ? fpu_pkg::NEGZERO    : fpu_pkg::POSZERO;
    else if (rs_info[1].is_inf      ) class_info = rs[1].sign ? fpu_pkg::NEGINF     : fpu_pkg::POSINF;
    else if (rs_info[1].is_nan      ) class_info = rs_info[1].is_signalling ?
                                                                fpu_pkg::SNAN       : fpu_pkg::QNAN;
    else                              class_info =              fpu_pkg::QNAN;
  end
  
  // * --------------
  // * Result Select
  // * --------------
  always @ (*) begin
    case (i_op)
      fpu_pkg::FPU_OP_FCMP: begin
        o_result = cmp_result;
        o_fflags = cmp_fflags;
      end
      fpu_pkg::FPU_OP_FMINMAX: begin
        o_result = minmax_result;
        o_fflags = minmax_fflags;
      end
      fpu_pkg::FPU_OP_FSGNJ: begin
        o_result = sgnj_result;
        o_fflags = sgnj_fflags;
      end
      fpu_pkg::FPU_OP_FCLASS: begin
        o_result = class_result;
        o_fflags = class_fflags;
      end
      default: begin
        o_result = '0;
        o_fflags = '{default: '0};
      end
    endcase
  end

  // * --------------
  // * Handshake
  // * --------------
  assign o_out_valid = i_in_valid;
  assign o_in_ready  = 1'b1;

endmodule //fpu_fcmp