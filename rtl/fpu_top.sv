//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_top.sv
//
// Description  : Floating-point unit supporting rvf isa extension.
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_top #(
  // config
  parameter fpu_pkg::fp_format_e FP_FMT = fpu_pkg::FP32, // ! only fp32 now
  // local
  localparam FLEN = fpu_pkg::flen_bits(FP_FMT)
)(
  input  logic                           i_clk,
  input  logic                           i_rst_n,
  // operands
  input  logic [3:1] [FLEN-1:0]          i_rs,
  // operation type
  input  logic [fpu_pkg::FPU_OP_NUM-1:0] i_op,
  // rounding mode
  input  logic [2:0]                     i_rm_inst,
  input  logic [2:0]                     i_rm_fcsr,
  // input handshake
  input  logic                           i_in_valid,
  output logic                           o_in_ready,
  // result & fflags
  output logic [FLEN-1:0]                o_result,
  output logic [4:0]                     o_fflags,
  // output handshake
  output logic                           o_out_valid,
  input  logic                           i_out_ready
);
  // * ----------------
  // * Operation Group
  // * ----------------
  wire op_fma         = (i_op == fpu_pkg::FPU_OP_FMADD ) | (i_op == fpu_pkg::FPU_OP_FMSUB  ) |
                        (i_op == fpu_pkg::FPU_OP_FNMSUB) | (i_op == fpu_pkg::FPU_OP_FNMADD ) |
                        (i_op == fpu_pkg::FPU_OP_FADD  ) | (i_op == fpu_pkg::FPU_OP_FSUB   ) |
                        (i_op == fpu_pkg::FPU_OP_FMUL  )                                     ;
  wire op_fcmp        = (i_op == fpu_pkg::FPU_OP_FCMP  ) | (i_op == fpu_pkg::FPU_OP_FMINMAX) |
                        (i_op == fpu_pkg::FPU_OP_FSGNJ ) | (i_op == fpu_pkg::FPU_OP_FCLASS ) ;
  wire op_fconv       = (i_op == fpu_pkg::FPU_OP_FMVXW ) | (i_op == fpu_pkg::FPU_OP_FMVWX  ) |
                        (i_op == fpu_pkg::FPU_OP_FCVTSW) | (i_op == fpu_pkg::FPU_OP_FCVTSWU) |
                        (i_op == fpu_pkg::FPU_OP_FCVTWS) | (i_op == fpu_pkg::FPU_OP_FCVTWUS) ;
  wire op_fdivsqrt    = (i_op == fpu_pkg::FPU_OP_FDIV  ) | (i_op == fpu_pkg::FPU_OP_FSQRT  ) ;
  
  // * --------------
  // * Round Mode
  // * --------------
  fpu_pkg::roundmode_e rm;
  always @ (*) begin
    if ((i_op == fpu_pkg::FPU_OP_FSGNJ) | (i_op == fpu_pkg::FPU_OP_FMINMAX) | (i_op == fpu_pkg::FPU_OP_FCMP  ) |
        (i_op == fpu_pkg::FPU_OP_FMVWX) | (i_op == fpu_pkg::FPU_OP_FMVXW  ) | (i_op == fpu_pkg::FPU_OP_FCLASS) ) begin
      rm = fpu_pkg::roundmode_e'(i_rm_inst); // don't need rm
    end else if (i_rm_inst == 3'b111) begin
      rm = fpu_pkg::roundmode_e'(i_rm_fcsr); // use fcsr dynamic rm
    end else begin
      rm = fpu_pkg::roundmode_e'(i_rm_inst); // use inst encoded rm
    end
  end

  // * ------------------
  // * Dispatch & Select
  // * ------------------
  // handshake
  logic fma_i_in_valid,  fdivsqrt_i_in_valid,  fcmp_i_in_valid,  fconv_i_in_valid;
  logic fma_o_in_ready,  fdivsqrt_o_in_ready,  fcmp_o_in_ready,  fconv_o_in_ready;
  logic fma_o_out_valid, fdivsqrt_o_out_valid, fcmp_o_out_valid, fconv_o_out_valid;
  logic fma_i_out_ready, fdivsqrt_i_out_ready, fcmp_i_out_ready, fconv_i_out_ready;
  // output
  logic [FLEN-1:0] fma_o_result, fdivsqrt_o_result, fcmp_o_result, fconv_o_result;
  fpu_pkg::fflags_t fma_o_fflags, fdivsqrt_o_fflags, fcmp_o_fflags, fconv_o_fflags;

  always @ (*) begin
      fma_i_in_valid       = '0;
      fdivsqrt_i_in_valid  = '0;
      fcmp_i_in_valid      = '0;
      fconv_i_in_valid     = '0;
      o_in_ready           = '0;
      o_out_valid          = '0;
      fma_i_out_ready      = '0;
      fdivsqrt_i_out_ready = '0;
      fcmp_i_out_ready     = '0;
      fconv_i_out_ready    = '0;
      o_result             = '0;
      o_fflags             = '0;
    if          (op_fma)      begin
      fma_i_in_valid       = i_in_valid;
      o_in_ready           = fma_o_in_ready;
      o_out_valid          = fma_o_out_valid;
      fma_i_out_ready      = i_out_ready;
      o_result             = fma_o_result;
      o_fflags             = fma_o_fflags;
    end else if (op_fdivsqrt) begin
      fdivsqrt_i_in_valid  = i_in_valid;
      o_in_ready           = fdivsqrt_o_in_ready;
      o_out_valid          = fdivsqrt_o_out_valid;
      fdivsqrt_i_out_ready = i_out_ready;
      o_result             = fdivsqrt_o_result;
      o_fflags             = fdivsqrt_o_fflags;
    end else if (op_fcmp)     begin
      fcmp_i_in_valid      = i_in_valid;
      o_in_ready           = fcmp_o_in_ready;
      o_out_valid          = fcmp_o_out_valid;
      fcmp_i_out_ready     = i_out_ready;
      o_result             = fcmp_o_result;
      o_fflags             = fcmp_o_fflags;
    end else if (op_fconv)    begin
      fconv_i_in_valid     = i_in_valid;
      o_in_ready           = fconv_o_in_ready;
      o_out_valid          = fconv_o_out_valid;
      fconv_i_out_ready    = i_out_ready;
      o_result             = fconv_o_result;
      o_fflags             = fconv_o_fflags;
    end
  end
  
  // * --------------------
  // * Instantiate 4 Units
  // * --------------------
  fpu_fma #(
    .FP_FMT      ( FP_FMT          )
  ) u_fpu_fma (
    .i_clk       ( i_clk           ),
    .i_rst_n     ( i_rst_n         ),
    .i_rs        ( i_rs            ),
    .i_op        ( i_op            ),
    .i_rm        ( rm              ),
    .i_in_valid  ( fma_i_in_valid  ),
    .o_in_ready  ( fma_o_in_ready  ),
    .i_out_ready ( fma_i_out_ready ),
    .o_out_valid ( fma_o_out_valid ),
    .o_result    ( fma_o_result    ),
    .o_fflags    ( fma_o_fflags    )
  );

  fpu_fdivsqrt #(
    .FP_FMT      ( FP_FMT          )
  ) u_fpu_fdivsqrt (
    .i_clk       ( i_clk                ),
    .i_rst_n     ( i_rst_n              ),
    .i_rs        ( i_rs                 ),
    .i_op        ( i_op                 ),
    .i_rm        ( rm                   ),
    .i_in_valid  ( fdivsqrt_i_in_valid  ),
    .o_in_ready  ( fdivsqrt_o_in_ready  ),
    .i_out_ready ( fdivsqrt_i_out_ready ),
    .o_out_valid ( fdivsqrt_o_out_valid ),
    .o_result    ( fdivsqrt_o_result    ),
    .o_fflags    ( fdivsqrt_o_fflags    )
  );

  fpu_fcmp #(
    .FP_FMT      ( FP_FMT          )
  ) u_fpu_fcmp (
    .i_clk       ( i_clk            ),
    .i_rst_n     ( i_rst_n          ),
    .i_rs        ( i_rs             ),
    .i_op        ( i_op             ),
    .i_rm        ( rm               ),
    .i_in_valid  ( fcmp_i_in_valid  ),
    .o_in_ready  ( fcmp_o_in_ready  ),
    .i_out_ready ( fcmp_i_out_ready ),
    .o_out_valid ( fcmp_o_out_valid ),
    .o_result    ( fcmp_o_result    ),
    .o_fflags    ( fcmp_o_fflags    )
  );

  fpu_fconv #(
    .FP_FMT      ( FP_FMT          )
  ) u_fpu_fconv (
    .i_clk       ( i_clk             ),
    .i_rst_n     ( i_rst_n           ),
    .i_rs        ( i_rs              ),
    .i_op        ( i_op              ),
    .i_rm        ( rm                ),
    .i_in_valid  ( fconv_i_in_valid  ),
    .o_in_ready  ( fconv_o_in_ready  ),
    .i_out_ready ( fconv_i_out_ready ),
    .o_out_valid ( fconv_o_out_valid ),
    .o_result    ( fconv_o_result    ),
    .o_fflags    ( fconv_o_fflags    )
  );

endmodule