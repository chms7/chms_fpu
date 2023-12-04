//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_fconv.sv
//
// Description  : Converse unit of fpu
//                FMVXW FMVWX FCVTSW FCVTSWU FCVTWS FCVTWUS
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_fconv #(
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
  localparam int unsigned EXP_WIDTH = fpu_pkg::exp_bits(FP_FMT);
  localparam int unsigned MAN_WIDTH = fpu_pkg::man_bits(FP_FMT);
  localparam int unsigned BIAS      = 2**(EXP_WIDTH - 1) - 1;

  // internal mantissa width is the maximum of (fp mantissa + normal bit, integer)
  localparam int unsigned MAN_INTER_WIDTH = FLEN;

  // lzc result width
  localparam int unsigned LZC_RESULT_WIDTH = $clog2(MAN_INTER_WIDTH);

  // the internal exponent must be able to represent the smallest denormal input value as signed
  // or the number of bits in an integer
  localparam int unsigned EXP_INTER_WIDTH = $clog2(BIAS + MAN_WIDTH) + 1;

  // * ---------------
  // * Input Operands
  // * ---------------
  // operands
  typedef struct packed {
    logic                 sign;
    logic [EXP_WIDTH-1:0] exponent;
    logic [MAN_WIDTH-1:0] mantissa;
  } fp_num_t;

  logic [FLEN-1:0] rs_int;
  fp_num_t              rs_fp;
  assign rs_int = i_rs[1];
  assign rs_fp  = '{sign:     i_rs[1][FLEN-1],
                    exponent: i_rs[1][FLEN-2:FLEN-EXP_WIDTH-1],
                    mantissa: i_rs[1][MAN_WIDTH-1:0]};

  // operands info
  fpu_pkg::fp_info_t rs_info;
  fpu_utils_rsinfo #(
    .FP_FMT        ( FP_FMT             ),
    .RS_NUM        ( 1                  )
  ) u_fpu_utils_rsinfo (
    .i_rs          ( i_rs[1]            ),
    .o_rs_info     ( rs_info            ),
    .o_rs_info_any (                    )
  );

  // * --------------
  // * FMV
  // * --------------
  logic [FLEN-1:0]  fmv_result;
  fpu_pkg::fflags_t fmv_fflags;
  assign fmv_result = i_rs[1];
  assign fmv_fflags = '{default: '0}; // fmv never set fflags
  
  // * --------------
  // * FCVT
  // * --------------
  // * Input process
  // int -> float
  wire src_is_int = (i_op == fpu_pkg::FPU_OP_FCVTSW)  | (i_op == fpu_pkg::FPU_OP_FCVTSWU);
  // float -> int
  wire dst_is_int = (i_op == fpu_pkg::FPU_OP_FCVTWS)  | (i_op == fpu_pkg::FPU_OP_FCVTWUS);
  wire cvt_uint   = (i_op == fpu_pkg::FPU_OP_FCVTWUS) | (i_op == fpu_pkg::FPU_OP_FCVTSWU);

  // fp input
  logic                              fp_sign;
  logic signed [EXP_INTER_WIDTH-1:0] fp_exponent;
  logic        [MAN_INTER_WIDTH-1:0] fp_mantissa;
  logic signed [EXP_INTER_WIDTH-1:0] fp_shift_compensation; // for LZC

  assign fp_sign     = rs_fp.sign;
  assign fp_exponent = signed'({1'b0, rs_fp.exponent});
  assign fp_mantissa = {rs_info.is_normal, rs_fp.mantissa}; // with implicit bit
  // compensation for the difference in mantissa widths used for leading-zero count
  assign fp_shift_compensation = signed'(MAN_INTER_WIDTH - 1 - MAN_WIDTH);

  // int input
  logic                       int_sign;
  logic [MAN_INTER_WIDTH-1:0] int_mantissa;

  // construct input mantissa from integer
  assign int_sign     = rs_int[MAN_INTER_WIDTH-1] & ~cvt_uint;
  assign int_mantissa = int_sign ? unsigned'(-rs_int) : rs_int; // get magnitude of negative

  // select mantissa with source format
  logic [MAN_INTER_WIDTH-1:0] man_ext;
  assign man_ext = src_is_int ? int_mantissa : fp_mantissa;

  // * Normalization
  logic signed [EXP_INTER_WIDTH-1:0] src_exp;       // src format exponent (biased)
  logic signed [EXP_INTER_WIDTH-1:0] src_subnormal; // src is subnormal
  logic signed [EXP_INTER_WIDTH-1:0] src_offset;    // src offset within mantissa

  assign src_exp       = fp_exponent;
  assign src_subnormal = signed'({1'b0, rs_info.is_subnormal});
  assign src_offset    = fp_shift_compensation;

  logic                              input_sign;   // input sign
  logic signed [EXP_INTER_WIDTH-1:0] input_exp;    // unbiased true exponent
  logic        [MAN_INTER_WIDTH-1:0] input_man;    // normalized input mantissa
  logic                              man_is_zero; // for integer zeroes

  logic signed [EXP_INTER_WIDTH-1:0] fp_input_exp;
  logic signed [EXP_INTER_WIDTH-1:0] int_input_exp;

  // input mantissa needs to be normalized
  logic [LZC_RESULT_WIDTH-1:0] renorm_shamt;     // renormalization shift amount
  logic [LZC_RESULT_WIDTH:0]   renorm_shamt_sgn; // signed form for calculations

  // leading-zero counter for renormalization
  fpu_utils_lzc #(
    .WIDTH                ( MAN_INTER_WIDTH )
  ) u_fpu_utils_lzc (
    .in_i                 ( man_ext         ),
    .leading_zero_cnt_o   ( renorm_shamt    ),
    .leading_zero_empty_o ( man_is_zero     )
  );
  assign renorm_shamt_sgn = signed'({1'b0, renorm_shamt});

  assign input_sign = src_is_int ? int_sign : fp_sign;
  // realign input mantissa, append zeroes if destination is wider
  assign input_man = man_ext << renorm_shamt;
  // unbias exponent and compensate for shift
  assign fp_input_exp  = signed'(src_exp + src_subnormal - BIAS -
                                 renorm_shamt_sgn + src_offset); // compensate for shift
  assign int_input_exp = signed'(MAN_INTER_WIDTH - 1 - renorm_shamt_sgn);

  assign input_exp     = src_is_int ? int_input_exp : fp_input_exp;

  // rebias the exponent
  logic signed [EXP_INTER_WIDTH-1:0] destination_exp;  // re-biased exponent for destination
  assign destination_exp = input_exp + BIAS;

  // * Casting
  logic [EXP_INTER_WIDTH-1:0] final_exp;       // after eventual adjustments

  logic [2*MAN_INTER_WIDTH:0] preshift_man;    // mantissa before final shift
  logic [2*MAN_INTER_WIDTH:0] destination_man; // mantissa from shifter, with rnd bit
  logic [MAN_WIDTH-1:0]       final_man;       // mantissa after adjustments
  logic [FLEN-1:0]            final_int;       // integer shifted in position

  logic [$clog2(MAN_INTER_WIDTH+1)-1:0] denorm_shamt; // shift amount for denormalization

  logic [1:0] fp_round_sticky_bits, int_round_sticky_bits, round_sticky_bits;
  logic       of_before_round, uf_before_round;

  // perform adjustments to mantissa and exponent
  always @ (*) begin
    // default assignment
    final_exp       = unsigned'(destination_exp); // take exponent as is, only look at lower bits
    preshift_man    = '0;  // initialize mantissa container with zeroes
    denorm_shamt    = '0; // right of mantissa
    of_before_round = 1'b0;
    uf_before_round = 1'b0;

    // place mantissa to the left of the shifter
    preshift_man = input_man << (MAN_INTER_WIDTH + 1);

    // handle int casts
    if (dst_is_int) begin
      // by default right shift mantissa to be an integer
      denorm_shamt = unsigned'(FLEN - 1 - input_exp);
      // overflow: when converting to unsigned the range is larger by one
      if (input_exp >= signed'(FLEN - 1 + cvt_uint)) begin
        denorm_shamt    = '0; // prevent shifting
        of_before_round = 1'b1;
      // underflow
      end else if (input_exp < -1) begin
        denorm_shamt    = FLEN + 1; // all bits go to the sticky
        uf_before_round = 1'b1;
      end
    // handle fp over-/underflows
    end else begin
      // overflow or infinities (for proper rounding)
      if ((destination_exp >= signed'(2**EXP_WIDTH)-1) ||
          (~src_is_int && rs_info.is_inf)) begin
        final_exp       = unsigned'(2**EXP_WIDTH-2); // largest normal value
        preshift_man    = '1;                           // largest normal value and RS bits set
        of_before_round = 1'b1;
      // denormalize underflowing values
      end else if (destination_exp < 1 &&
                   destination_exp >= -signed'(MAN_WIDTH)) begin
        final_exp       = '0; // denormal result
        denorm_shamt    = unsigned'(denorm_shamt + 1 - destination_exp); // adjust right shifting
        uf_before_round = 1'b1;
      // limit the shift to retain sticky bits
      end else if (destination_exp < -signed'(MAN_WIDTH)) begin
        final_exp       = '0; // denormal result
        denorm_shamt    = unsigned'(denorm_shamt + 2 + MAN_WIDTH); // to sticky
        uf_before_round = 1'b1;
      end
    end
  end

  localparam NUM_FP_STICKY  = 2 * MAN_INTER_WIDTH - MAN_WIDTH - 1; // removed mantissa, 1. and R
  localparam NUM_INT_STICKY = 2 * MAN_INTER_WIDTH - FLEN; // removed int and R

  // mantissa adjustment shift
  assign destination_man = preshift_man >> denorm_shamt;
  // extract final mantissa and round bit, discard the normal bit (for FP)
  assign {final_man, fp_round_sticky_bits[1]} =
      destination_man[2*MAN_INTER_WIDTH-1-:MAN_WIDTH+1];
  assign {final_int, int_round_sticky_bits[1]} = destination_man[2*MAN_INTER_WIDTH-:FLEN+1];
  // collapse sticky bits
  assign fp_round_sticky_bits[0]  = (| {destination_man[NUM_FP_STICKY-1:0]});
  assign int_round_sticky_bits[0] = (| {destination_man[NUM_INT_STICKY-1:0]});

  // select RS bits for destination operation
  assign round_sticky_bits = dst_is_int ? int_round_sticky_bits : fp_round_sticky_bits;

  // * Rounding and classification
  logic [FLEN-1:0]  pre_round_abs;  // absolute value of result before rnd
  logic             of_after_round; // overflow
  logic             uf_after_round; // underflow

  logic [FLEN-1:0]  fp_pre_round_abs;
  logic             fp_of_after_round;
  logic             fp_uf_after_round;

  logic [FLEN-1:0]  int_pre_round_abs;
  logic             int_of_after_round;

  logic             rounded_sign;
  logic [FLEN-1:0]  rounded_abs; // absolute value of result after rounding
  logic             result_true_zero;

  logic [FLEN-1:0]  rounded_int_res; // after possible inversion
  logic [FLEN-1:0]  int_regular_result;
  logic             rounded_int_res_zero; // after rounding

  // pack exponent and mantissa into proper rounding form
  assign fp_pre_round_abs = {final_exp[EXP_WIDTH-1:0], final_man[MAN_WIDTH-1:0]}; // 0-extend

  assign int_pre_round_abs = final_int;

  // select output with destination format and operation
  assign pre_round_abs = dst_is_int ? int_pre_round_abs : fp_pre_round_abs;
  fpu_pkg::roundmode_e rnd_mode;
  assign rnd_mode = i_rm;

  fpu_utils_round #(
    .AbsWidth                ( FLEN              )
  ) u_fpu_utils_round (
    .abs_value_i             ( pre_round_abs     ),
    .sign_i                  ( input_sign        ), // source format
    .round_sticky_bits_i     ( round_sticky_bits ),
    .rnd_mode_i              ( rnd_mode          ),
    .effective_subtraction_i ( 1'b0              ), // no operation happened
    .abs_rounded_o           ( rounded_abs       ),
    .sign_o                  ( rounded_sign      ),
    .exact_zero_o            ( result_true_zero  )
  );

  logic [FLEN-1:0] fp_regular_result;

  // detect overflows and inject sign
  always @ (*) begin // post_process
    // detect of / uf
    fp_uf_after_round = rounded_abs[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH] == '0; // denormal
    fp_of_after_round = rounded_abs[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH] == '1; // inf exp.

    // assemble regular result, nan box short ones. Int zeroes need to be detected`
    fp_regular_result               = '1;
    fp_regular_result[FLEN-1:0] = src_is_int & man_is_zero
                                    ? '0
                                    : {rounded_sign, rounded_abs[EXP_WIDTH+MAN_WIDTH-1:0]};
  end

  // negative integer result needs to be brought into two's complement
  assign rounded_int_res      = rounded_sign ? unsigned'(-rounded_abs) : rounded_abs;
  assign rounded_int_res_zero = (rounded_int_res == '0);
  assign int_regular_result   = rounded_int_res;

  // detect integer overflows after rounding (only positives)
  always @ (*) begin // detect_overflow
    int_of_after_round = 1'b0;
    // int result can overflow if we're at the max exponent
    if (!rounded_sign && input_exp == signed'(FLEN - 2 + cvt_uint)) begin
      // Check whether the rounded MSB differs from unrounded MSB
      int_of_after_round = ~rounded_int_res[FLEN-2+cvt_uint];
    end
  end

  // classification after rounding select by destination format
  assign uf_after_round = fp_uf_after_round;
  assign of_after_round = dst_is_int ? int_of_after_round : fp_of_after_round;

  // * Fp special case handling
  logic [FLEN-1:0]   fp_special_result;
  fpu_pkg::fflags_t fp_special_fflags;
  logic               fp_result_is_special;

  // detect special case from source format, int2float casts don't produce a special result
  assign fp_result_is_special = ~src_is_int & (rs_info.is_zero |
                                                 rs_info.is_nan );

  // special result construction
  assign fp_special_result = rs_info.is_zero ? input_sign << FLEN-1 // signed zero
                                             : {1'b0, {EXP_WIDTH{1'b1}}, 2**(MAN_WIDTH-1)}; // qNaN

  // signalling input NaNs raise invalid flag, otherwise no flags set
  assign fp_special_fflags = '{NV: rs_info.is_signalling, default: 1'b0};

  // * Int special case handling
  logic [FLEN-1:0]   int_special_result;
  fpu_pkg::fflags_t int_special_fflags;
  logic               int_result_is_special;

  // detect special case from source format (inf, nan, overflow or negative unsigned)
  assign int_result_is_special = rs_info.is_nan | rs_info.is_inf |
                                 of_before_round | of_after_round |
                                 (input_sign & cvt_uint & ~rounded_int_res_zero);

  // special result construction
  always @ (*) begin
    // default is overflow to positive max, which is 2**FLEN-1 or 2**(FLEN-1)-1
    int_special_result[FLEN-2:0] = '1;       // alone yields 2**(FLEN-1)-1
    int_special_result[FLEN-1]   = cvt_uint; // for unsigned casts yields 2**FLEN-1

    // negative special case (except for nans) tie to -max or 0
    if (input_sign && !rs_info.is_nan)
      int_special_result = ~int_special_result;
  end

  // all integer special cases are invalid
  assign int_special_fflags = '{NV: 1'b1, default: 1'b0};

  // * fcvt result select
  fpu_pkg::fflags_t fp_regular_fflags, int_regular_fflags;

  assign fp_regular_fflags.NV = src_is_int & (of_before_round | of_after_round); // overflow is invalid for int2float casts
  assign fp_regular_fflags.DZ = 1'b0; // no divisions
  assign fp_regular_fflags.OF = ~src_is_int & (~rs_info.is_inf & (of_before_round | of_after_round)); // inf casts no OF
  assign fp_regular_fflags.UF = uf_after_round & fp_regular_fflags.NX;
  assign fp_regular_fflags.NX = src_is_int ? (| fp_round_sticky_bits) // overflow is invalid in i2f
            : (| fp_round_sticky_bits) | (~rs_info.is_inf & (of_before_round | of_after_round));
  assign int_regular_fflags = '{NX: (| int_round_sticky_bits), default: 1'b0};

  // select regular/special results
  logic [FLEN-1:0]   fp_result, int_result;
  fpu_pkg::fflags_t fp_fflags, int_fflags;

  assign fp_result  = fp_result_is_special  ? fp_special_result  : fp_regular_result;
  assign fp_fflags  = fp_result_is_special  ? fp_special_fflags  : fp_regular_fflags;
  assign int_result = int_result_is_special ? int_special_result : int_regular_result;
  assign int_fflags = int_result_is_special ? int_special_fflags : int_regular_fflags;

  // select fp/int results
  logic [FLEN-1:0]   fcvt_result;
  fpu_pkg::fflags_t fcvt_fflags;

  assign fcvt_result = dst_is_int ? int_result : fp_result;
  assign fcvt_fflags = dst_is_int ? int_fflags : fp_fflags;
  
  // * --------------
  // * Result Select
  // * --------------
  always @ (*) begin
    case (i_op)
      fpu_pkg::FPU_OP_FMVWX,
      fpu_pkg::FPU_OP_FMVXW: begin
        o_result = fmv_result;
        o_fflags = fmv_fflags;
      end
      fpu_pkg::FPU_OP_FCVTSW,
      fpu_pkg::FPU_OP_FCVTSWU,
      fpu_pkg::FPU_OP_FCVTWS,
      fpu_pkg::FPU_OP_FCVTWUS: begin
        o_result = fcvt_result;
        o_fflags = fcvt_fflags;
      end
      default: begin
        o_result = '0;
        o_fflags = '{default: '0};
      end
    endcase
  end
  
  // * ----------
  // * Handshake
  // * ----------
  assign o_out_valid = i_in_valid;
  assign o_in_ready  = 1'b1;

endmodule //fpu_fconv