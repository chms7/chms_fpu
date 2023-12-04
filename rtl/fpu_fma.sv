//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_fma.sv
//
// Description  : Mul & add unit of fpu.
//                FMADD FMSUB FNMSUB FNMADD FADD FSUB FMUL
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_fma #(
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
  localparam BIAS               = fpu_pkg::bias    (FP_FMT);
  localparam EXP_WIDTH          = fpu_pkg::exp_bits(FP_FMT);
  localparam EXP_WIDTH_EXT      = EXP_WIDTH+2;
  localparam MAN_WIDTH          = fpu_pkg::man_bits(FP_FMT);
  localparam MAN_WIDTH_EXT      = MAN_WIDTH+1;
  localparam SHIFT_AMOUNT_WIDTH = 7;
  localparam LOWER_SUM_WIDTH    = 2*MAN_WIDTH_EXT+3;
  localparam LZC_RESULT_WIDTH   = 6;

  // fp operand
  typedef struct packed {
    logic                 sign;
    logic [EXP_WIDTH-1:0] exponent;
    logic [MAN_WIDTH-1:0] mantissa;
  } fp_num_t;

  // fp operand with extending-bits
  typedef struct packed {
    logic                            sign;
    logic signed [EXP_WIDTH_EXT-1:0] exponent; // signed & zero-extend
    logic        [MAN_WIDTH_EXT-1:0] mantissa; // additional impicit bit
  } fp_num_ext_t;

  // * ---------------
  // * Input Process
  // * ---------------
  // input operands
  fp_num_t [3:1] rs_in;

  assign rs_in[1] = '{sign:     i_rs[1][FLEN-1],
                      exponent: i_rs[1][FLEN-2:FLEN-EXP_WIDTH-1],
                      mantissa: i_rs[1][MAN_WIDTH-1:0]};
  assign rs_in[2] = '{sign:     i_rs[2][FLEN-1],
                      exponent: i_rs[2][FLEN-2:FLEN-EXP_WIDTH-1],
                      mantissa: i_rs[2][MAN_WIDTH-1:0]};
  assign rs_in[3] = '{sign:     i_rs[3][FLEN-1],
                      exponent: i_rs[3][FLEN-2:FLEN-EXP_WIDTH-1],
                      mantissa: i_rs[3][MAN_WIDTH-1:0]};

  // input operands info
  fpu_pkg::fp_info_t [3:1] rs_in_info;
  fpu_pkg::fp_info_any_t   rs_in_info_any;

  fpu_utils_rsinfo #(
    .FP_FMT        ( FP_FMT                         ),
    .RS_NUM        ( 3                              )
  ) u_fpu_utils_rs_in_info (
    .i_rs          ( {rs_in[3], rs_in[2], rs_in[1]} ),
    .o_rs_info     ( rs_in_info                     ),
    .o_rs_info_any ( rs_in_info_any                 )
  );

  // adjust operands & operands info
  fp_num_t [3:1] rs;
  fpu_pkg::fp_info_t [3:1] rs_info;
  fpu_pkg::fp_info_any_t   rs_info_any;

  always @ (*) begin
    rs          = rs_in;
    rs_info     = rs_in_info;
    rs_info_any = rs_in_info_any;
    case (i_op)
      fpu_pkg::FPU_OP_FMADD: begin
        // FMADD: none
        // rs1 * rs2 + rs3
      end
      fpu_pkg::FPU_OP_FMSUB: begin
        // FMSUB: invert sign of rs3
        // rs1 * rs2 - rs3
        rs[3].sign = ~rs_in[3].sign;
      end
      fpu_pkg::FPU_OP_FNMSUB: begin
        // FNMSUB: invert sign of rs1
        // - rs1 * rs2 + rs3
        rs[1].sign = ~rs_in[1].sign;
      end
      fpu_pkg::FPU_OP_FNMADD: begin
        // FNMADD: invert sign of rs1 & rs3
        // - rs1 * rs2 - rs3
        rs[1].sign = ~rs_in[1].sign;
        rs[3].sign = ~rs_in[3].sign;
      end
      fpu_pkg::FPU_OP_FADD: begin
        // FADD: rs2 -> op3, rs1 -> op2, set op1 to +1.0
        // 1.0 * rs1 + rs2
        rs[3] = '{sign: rs_in[2].sign, exponent: rs_in[2].exponent, mantissa: rs_in[2].mantissa};
        rs[2] = '{sign: rs_in[1].sign, exponent: rs_in[1].exponent, mantissa: rs_in[1].mantissa};
        rs[1] = '{sign: 1'b0,          exponent: BIAS,              mantissa: '0};
        rs_info[3] = rs_in_info[2];
        rs_info[2] = rs_in_info[1];
        rs_info[1] = '{is_normal: 1'b1, default: 1'b0}; // 1.0 is normal
      end
      fpu_pkg::FPU_OP_FSUB: begin
        // FSUB: set op0 to +1.0, invert sign of op2
        // 1.0 * rs1 - rs2
        rs[3] = '{sign: ~rs_in[2].sign, exponent: rs_in[2].exponent, mantissa: rs_in[2].mantissa};
        rs[2] = '{sign:  rs_in[1].sign, exponent: rs_in[1].exponent, mantissa: rs_in[1].mantissa};
        rs[1] = '{sign: 1'b0,           exponent: BIAS,              mantissa: '0};
        rs_info[3] = rs_in_info[2];
        rs_info[2] = rs_in_info[1];
        rs_info[1] = '{is_normal: 1'b1, default: 1'b0}; // 1.0 is normal
      end
      fpu_pkg::FPU_OP_FMUL: begin
        // FMUL: set op3 to +0.0 or -0.0 depending on the rounding mode
        // rs1 * rs2 - 0
        if (i_rm == fpu_pkg::RDN) rs[3] = '{sign: '0, exponent: '0, mantissa: '0}; // +0.0
        else                      rs[3] = '{sign: '1, exponent: '0, mantissa: '0}; // -0.0
        rs_info[3] = '{is_zero: 1'b1, default: 1'b0};
      end
      default: begin
        // other: invalid
        rs[1]       = '{default: '0};
        rs[2]       = '{default: '0};
        rs[3]       = '{default: '0};
        rs_info[1]  = '{default: '0};
        rs_info[2]  = '{default: '0};
        rs_info[3]  = '{default: '0};
        rs_info_any = '{default: '0};
      end
    endcase
  end

  // operands with extend-bits
  fp_num_ext_t [3:1] rs_ext;

  assign rs_ext[1] = '{sign:     rs[1].sign,
                       exponent: signed'({1'b0, rs[1].exponent}),         // signed & zero-extend
                       mantissa: {rs_info[1].is_normal, rs[1].mantissa}}; // additional impicit bit
  assign rs_ext[2] = '{sign:     rs[2].sign,
                       exponent: signed'({1'b0, rs[2].exponent}),
                       mantissa: {rs_info[2].is_normal, rs[2].mantissa}};
  assign rs_ext[3] = '{sign:     rs[3].sign,
                       exponent: signed'({1'b0, rs[3].exponent}),
                       mantissa: {rs_info[3].is_normal, rs[3].mantissa}};

  // * -------------------
  // * Exponent Datapath
  // * -------------------
  logic signed [EXP_WIDTH_EXT-1:0] exp_addend, exp_product, exp_delta;
  logic signed [EXP_WIDTH_EXT-1:0] exp_tentative;

  // exponent of rs[1] * rs[2] product
  assign exp_product = (rs_info[1].is_zero || rs_info[2].is_zero) ?
                          // zero
                          // 2 - signed'(BIAS) :
                          '0 :
                          // exp1 + subnormal1 + exp2 + subnormal2 - bias
                          signed'(rs_ext[1].exponent + rs_info[1].is_subnormal + rs_ext[2].exponent + rs_info[2].is_subnormal
                                  - signed'(BIAS));
  // exponent of rs[3] addend
  assign exp_addend  = signed'(rs_ext[3].exponent + $signed({1'b0, ~rs_info[3].is_normal}));
  // take the larger, shift the smaller
  assign exp_delta     = exp_addend - exp_product;
  assign exp_tentative = (exp_delta > 0) ? exp_addend : exp_product;

  // shift amount of smaller operand (unsigned as only right shifts)
  logic [SHIFT_AMOUNT_WIDTH-1:0] shamt_addend;

  always @ (*) begin
    // product-anchored case, saturated shift (addend is only in the sticky bit)
    // exponent of addend is too small
    if (exp_delta <= signed'(-2 * MAN_WIDTH_EXT - 1))
      shamt_addend = 3 * MAN_WIDTH_EXT + 4;
    // addend and product will have mutual bits to add
    else if (exp_delta <= signed'(MAN_WIDTH_EXT + 2))
      shamt_addend = unsigned'(signed'(MAN_WIDTH_EXT) + 3 - exp_delta);
    // addend-anchored case, saturated shift (product is only in the sticky bit)
    // exponent of product is too small
    else
      shamt_addend = 0;
  end

  // * --------------------
  // * Mantissa of Product
  // * --------------------
  logic [2*MAN_WIDTH_EXT-1:0] man_product_t;
  logic [3*MAN_WIDTH_EXT+3:0] man_product;

  // assign man_product_t = rs_ext[1].mantissa * rs_ext[2].mantissa;
  multiply_32bit u_mul_man24bit (
    .AD ( {8'd0, rs_ext[1].mantissa}),
    .AS ( 1'b0                      ), // unsigned
    .BD ( {8'd0, rs_ext[2].mantissa}),
    .BS ( 1'b0                      ),
    .D  ( man_product_t             )
  );

  // product is placed into a 3p+4 bit wide vector, padded with 2 bits for round and sticky:
  // | 000...000 | product | RS |
  //  <-  p+2  -> <-  2p -> < 2>
  assign man_product = man_product_t << 2;

  // * -------------------
  // * Mantissa of Addend
  // * -------------------
  logic [4*MAN_WIDTH_EXT+3:0] man_addend_t;
  logic [3*MAN_WIDTH_EXT+3:0] addend_after_shift;  // upper 3p+4 bits are needed to go on
  logic                       sticky_before_add;   // sticky bit
  logic [MAN_WIDTH_EXT-1:0]   addend_sticky_bits;  // up to p bit of shifted addend are sticky
  logic [3*MAN_WIDTH_EXT+3:0] man_addend;          // addends are 3p+4 bit wide (including G/R)
  logic                       inject_carry_in;     // inject carry for subtractions if needed

  // effective subtraction: sign(rs1 * rs2) != sign(rs3)
  wire effect_sub = rs[1].sign ^ rs[2].sign ^ rs[3].sign;
  wire product_sign = rs[1].sign ^ rs[2].sign;

  // right-shift the addend according to the exponent difference
  // up to p bits are shifted out and compressed into a sticky bit
  // before shift:
  // | rs[3].mantissa | 000..000 |
  //  <-      p     -> <- 3p+4 ->
  assign man_addend_t = rs_ext[3].mantissa << (3 * MAN_WIDTH_EXT + 4);
  // after  shift:
  // | 000..........000 | rs[3].mantissa | 000...............0GR |  sticky bits  |
  //  <- shamt_addend -> <-      p     -> <- 2p+4-shamt_addend -> <-  up to p  ->
  fpu_utils_shift #(
    .SHIFT_MODE     ( 1                                        ), // right shift
    .DATA_WIDTH     ( 4*MAN_WIDTH_EXT+4                        ),
    .SHAMT_WIDTH    ( SHIFT_AMOUNT_WIDTH                       )
  ) u_fpu_utils_right_shift (
    .data_i         ( man_addend_t                             ),
    .shamt_i        ( shamt_addend                             ),
    .data_shifted_o ( {addend_after_shift, addend_sticky_bits} )
  );

  assign sticky_before_add = (| addend_sticky_bits);

  // for subtraction, the addend is inverted
  assign man_addend = effect_sub ? ~addend_after_shift : addend_after_shift;
  assign inject_carry_in = effect_sub & ~sticky_before_add;

  // * ---------------
  // * Mantissa Adder
  // * ---------------
  logic [3*MAN_WIDTH_EXT+4:0] sum_raw;   // added one bit for the carry
  logic                       sum_carry; // observe carry bit from sum for sign fixing
  logic [3*MAN_WIDTH_EXT+4:0] sum;       // discard carry as sum won't overflow
  logic                       final_sign;

  // mantissa adder
  assign sum_raw   = man_product + man_addend + inject_carry_in;
  assign sum_carry = sum_raw[3*MAN_WIDTH_EXT+4];

  // complement negative sum (can only happen in subtraction -> overflows for positive results)
  assign sum        = (effect_sub && ~sum_carry) ? -sum_raw : sum_raw;

  // in case of a mispredicted subtraction result, do a sign flip
  assign final_sign = (effect_sub && (sum_carry == product_sign))
                      ? 1'b1
                      : (effect_sub ? 1'b0 : product_sign);

  // * -------------------
  // * Normalize
  // * -------------------
  logic        [LOWER_SUM_WIDTH-1:0]    sum_lower;              // lower 2p+3 bits of sum are searched
  logic        [LZC_RESULT_WIDTH-1:0]   leading_zero_count;     // the number of leading zeroes
  logic signed [LZC_RESULT_WIDTH:0]     leading_zero_count_sgn; // signed leading-zero count
  logic                                 lzc_zeroes;             // in case only zeroes found

  logic        [SHIFT_AMOUNT_WIDTH-1:0] norm_shamt; // Normalization shift amount
  logic signed [EXP_WIDTH_EXT-1:0]      normalized_exponent;

  logic [3*MAN_WIDTH_EXT+4:0] sum_shifted;       // result after first normalization shift
  logic [MAN_WIDTH_EXT:0]     final_mantissa;    // final mantissa before rounding with round bit
  logic [2*MAN_WIDTH_EXT+2:0] sum_sticky_bits;   // remaining 2p+3 sticky bits after normalization
  logic                       sticky_after_norm; // sticky bit after normalization

  logic signed [EXP_WIDTH_EXT-1:0] final_exponent;

  assign sum_lower = sum[LOWER_SUM_WIDTH-1:0];

  // leading-zero counter for cancellations
  fpu_utils_lzc #(
    .WIDTH                ( LOWER_SUM_WIDTH )
  ) u_fpu_utils_lzc (
    .in_i                 ( sum_lower          ),
    .leading_zero_cnt_o   ( leading_zero_count ),
    .leading_zero_empty_o ( lzc_zeroes         )
  );

  assign leading_zero_count_sgn = signed'({1'b0, leading_zero_count});

  // normalization shift amount based on exponents and LZC (unsigned as only left shifts)
  always @ (*) begin
    // product-anchored case or cancellations require LZC
    if ((exp_delta <= 0) || (effect_sub && (exp_delta <= 2))) begin
      // normal result (biased exponent > 0 and not a zero)
      if ((exp_product - leading_zero_count_sgn + 1 >= 0) && !lzc_zeroes) begin
        // undo initial product shift, remove the counted zeroes
        norm_shamt          = MAN_WIDTH_EXT + 2 + leading_zero_count;
        normalized_exponent = exp_product - leading_zero_count_sgn + 1; // account for shift
      // subnormal result
      end else begin
        // cap the shift distance to align mantissa with minimum exponent
        norm_shamt          = unsigned'(signed'(MAN_WIDTH_EXT) + 2 + exp_product);
        normalized_exponent = 0; // subnormals encoded as 0
      end
    // addend-anchored case
    end else begin
      norm_shamt          = shamt_addend; // Undo the initial shift
      normalized_exponent = exp_tentative;
    end
  end

  // do the large normalization shift
  fpu_utils_shift #(
    .SHIFT_MODE     ( 0                  ), // left shift
    .DATA_WIDTH     ( 3*MAN_WIDTH_EXT+5  ),
    .SHAMT_WIDTH    ( SHIFT_AMOUNT_WIDTH )
  ) u_fpu_utils_left_shift (
    .data_i         ( sum                ),
    .shamt_i        ( norm_shamt         ),
    .data_shifted_o ( sum_shifted        )
  );

  // the addend-anchored case needs a 1-bit normalization since the leading-one can be to the left
  // or right of the (non-carry) MSB of the sum.
  always @ (*) begin
    // default assignment, discarding carry bit
    {final_mantissa, sum_sticky_bits} = sum_shifted;
    final_exponent                    = normalized_exponent;

    // the normalized sum has overflown, align right and fix exponent
    if (sum_shifted[3*MAN_WIDTH_EXT+4]) begin // check the carry bit
      {final_mantissa, sum_sticky_bits} = sum_shifted >> 1;
      final_exponent                    = normalized_exponent + 1;
    // the normalized sum is normal, nothing to do
    end else if (sum_shifted[3*MAN_WIDTH_EXT+3]) begin // check the sum MSB
      // do nothing
    // the normalized sum is still denormal, align left - unless the result is not already subnormal
    end else if (normalized_exponent > 1) begin
      {final_mantissa, sum_sticky_bits} = sum_shifted << 1;
      final_exponent                    = normalized_exponent - 1;
    // otherwise we're denormal
    end else begin
      final_exponent = '0;
    end
  end

  // update the sticky bit with the shifted-out bits
  assign sticky_after_norm = (| {sum_sticky_bits}) | sticky_before_add;

  // * -------------------
  // * Round & Classify
  // * -------------------
  logic                           pre_round_sign;
  logic [EXP_WIDTH-1:0]           pre_round_exponent;
  logic [MAN_WIDTH-1:0]           pre_round_mantissa;
  logic [EXP_WIDTH+MAN_WIDTH-1:0] pre_round_abs; // absolute value of result before rounding
  logic [1:0]                     round_sticky_bits;

  logic of_before_round, of_after_round; // overflow
  logic uf_before_round, uf_after_round; // underflow
  logic result_zero;

  logic                           rounded_sign;
  logic [EXP_WIDTH+MAN_WIDTH-1:0] rounded_abs; // absolute value of result after rounding

  // classification before round. RISC-V mandates checking underflow AFTER rounding!
  assign of_before_round = final_exponent >= 2**(EXP_WIDTH)-1; // infinity exponent is all ones
  assign uf_before_round = final_exponent == 0;               // exponent for subnormals capped to 0

  // assemble result before rounding. In case of overflow, the largest normal value is set.
  assign pre_round_sign     = final_sign;
  assign pre_round_exponent = (of_before_round) ? 2**EXP_WIDTH-2 : unsigned'(final_exponent[EXP_WIDTH-1:0]);
  assign pre_round_mantissa = (of_before_round) ? '1 : final_mantissa[MAN_WIDTH:1]; // bit 0 is R bit
  assign pre_round_abs      = {pre_round_exponent, pre_round_mantissa};

  // in case of overflow, the round and sticky bits are set for proper rounding
  assign round_sticky_bits  = (of_before_round) ? 2'b11 : {final_mantissa[0], sticky_after_norm};

  // round
  fpu_utils_round #(
    .AbsWidth                ( EXP_WIDTH + MAN_WIDTH   )
  ) u_fpu_utils_round (
    .abs_value_i             ( pre_round_abs           ),
    .sign_i                  ( pre_round_sign          ),
    .round_sticky_bits_i     ( round_sticky_bits       ),
    .rnd_mode_i              ( i_rm                    ),
    .effective_subtraction_i ( effect_sub              ),
    .abs_rounded_o           ( rounded_abs             ),
    .sign_o                  ( rounded_sign            ),
    .exact_zero_o            ( result_zero             )
  );

  // classify
  assign uf_after_round = rounded_abs[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH] == '0; // exponent = 0
  assign of_after_round = rounded_abs[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH] == '1; // exponent all ones
  
  // regular result
  logic [FLEN-1:0]  regular_result;
  fpu_pkg::fflags_t regular_fflags;

  assign regular_result    = {rounded_sign, rounded_abs};
  assign regular_fflags.NV = 1'b0; // only valid cases are handled in regular path
  assign regular_fflags.DZ = 1'b0; // no divisions
  assign regular_fflags.OF = of_before_round | of_after_round;   // rounding can introduce overflow
  assign regular_fflags.UF = uf_after_round & regular_fflags.NX; // only inexact results raise UF
  assign regular_fflags.NX = (| round_sticky_bits) | of_before_round | of_after_round;

  // * ---------------
  // * special case
  // * ---------------
  fp_num_t          special_result;
  fpu_pkg::fflags_t special_fflags;
  logic             is_special_result;

  always @ (*) begin
    // default: qNaN
    special_result    = '{sign: '0, exponent: '1, mantissa: 2**(MAN_WIDTH-1)};
    special_fflags    = '{default: '0};
    is_special_result = 1'b0;

    // (inf * 0 + rs3) or (0 * inf + rs3)
    if ((rs_info[1].is_inf && rs_info[2].is_zero) || (rs_info[1].is_zero && rs_info[2].is_inf)) begin
      // invalid, result qNaN
      special_fflags.NV = 1'b1;
      is_special_result = 1'b1;
    // any input is nan
    end else if (rs_info_any.any_nan) begin
      // invalid if signalling, result qNaN
      special_fflags.NV = rs_info_any.any_signalling_nan;
      is_special_result = 1'b1;
    // any input is inf
    end else if (rs_info_any.any_inf) begin
      is_special_result = 1'b1;
      // (inf +- inf)
      if ((rs_info[1].is_inf || rs_info[2].is_inf) && rs_info[3].is_inf && effect_sub)
        // invalid, result qNaN
        special_fflags.NV = 1'b1;
      // (inf +- rs3)
      else if (rs_info[1].is_inf || rs_info[2].is_inf) begin
        // valid, result is inf with rs[1].sign ^ rs[2].sign
        special_result = '{sign: rs[1].sign ^ rs[2].sign, exponent: '1, mantissa: '0};
      // (rs1 * rs2 +- inf)
      end else if (rs_info[3].is_inf) begin
        // valid, inf with rs[3].sign
        special_result = '{sign: rs[3].sign, exponent: '1, mantissa: '0};
      end
    end
  end

  // * ---------------
  // * Result Select
  // * ---------------
  assign o_result = is_special_result ? special_result : regular_result;
  assign o_fflags = is_special_result ? special_fflags : regular_fflags;

  // * ---------------
  // * Handshake
  // * ---------------
  assign o_out_valid = i_in_valid;
  assign o_in_ready  = 1'b1;

endmodule //fpu_fma