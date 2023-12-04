/*
 * @Design: tb_fpu_top
 * @Author: Zhao Siwei
 * @Email:  cheems@foxmail.com
 * @Description: Testbench of fpu_top
 */
`timescale 1ns/10ps

module tb_fpu;

// Parameters
parameter PERIOD     = 10;
parameter FPU_OP_NUM = 19;
parameter FLEN       = 32;
parameter FP_P_3_5        = 32'h40600000;
parameter FP_P_2_5        = 32'h40200000;
parameter FP_P_1_5        = 32'h3fc00000;
parameter FP_P_1_0        = 32'h3f800000;
parameter FP_P_1_1        = 32'h3f8ccccd;
parameter FP_P_3_14159    = 32'h40490fdb;
parameter FP_P_3_14159E_8 = 32'h3306ee2d;


// Inputs & Outputs
logic i_clk                 = 0;
logic i_rst_n               = 0;
logic [3:1] [FLEN-1:0] i_rs = 0;
logic [FPU_OP_NUM-1:0] i_op = 0;
logic [2:0]  i_rm_inst      = 0;
logic [2:0]  i_rm_fcsr      = 0;
logic i_in_valid            = 0;
logic i_out_ready           = 0;
logic o_in_ready               ;
logic [FLEN-1:0]  o_result     ;
logic [4:0]  o_fflags          ;
logic o_out_valid              ;

// clk & rst
initial forever #(PERIOD/2) i_clk = ~i_clk;
initial         #(PERIOD*2) i_rst_n = 1;

// fpu_top
fpu_top u_fpu_top (
    .i_clk                   ( i_clk       ),
    .i_rst_n                 ( i_rst_n     ),
    .i_rs                    ( i_rs       ),
    .i_op                    ( i_op        ),
    .i_rm_inst               ( i_rm_inst   ),
    .i_rm_fcsr               ( i_rm_fcsr   ),
    .i_in_valid              ( i_in_valid  ),
    .i_out_ready             ( i_out_ready ),

    .o_in_ready              ( o_in_ready  ),
    .o_result                ( o_result   ),
    .o_fflags                ( o_fflags    ),
    .o_out_valid             ( o_out_valid )
);

initial begin
  // FADD
  fp_drive(fpu_pkg::FPU_OP_FADD, 32'h3f800000, 32'h40200000, 32'h00000000);
  fp_monitor("FADD: 1.0 + 2.5 = 3.5", 32'h40600000);

  fp_drive(fpu_pkg::FPU_OP_FADD, 32'hc49a6333, 32'h3f8ccccd, 32'h00000000);
  fp_monitor("FADD: -1235.1 + 1.1 = -1234", 32'hc49a4000);

  fp_drive(fpu_pkg::FPU_OP_FADD, 32'h40490fdb, 32'h322bcc77, 32'h00000000);
  fp_monitor("FADD: 3.14159265 + 0.00000001 = 3.14159265", 32'h40490fdb);

  // FSUB
  fp_drive(fpu_pkg::FPU_OP_FSUB, 32'h40200000, 32'h3f800000, 32'h00000000);
  fp_monitor("FSUB: 2.5 - 1.0 = 1.5", 32'h3fc00000);

  fp_drive(fpu_pkg::FPU_OP_FSUB, 32'hc49a6333, 32'hbf8ccccd, 32'h00000000);
  fp_monitor("FSUB: -1235.1 - -1.1 = -1234", 32'hc49a4000);

  fp_drive(fpu_pkg::FPU_OP_FSUB, 32'h40490fdb, 32'h322bcc77, 32'h00000000);
  fp_monitor("FSUB: 3.14159265 - 0.00000001 = 3.14159265", 32'h40490fdb);
  
  // FMUL
  fp_drive(fpu_pkg::FPU_OP_FMUL, 32'h3f800000, 32'h40200000, 32'h00000000);
  fp_monitor("FMUL: 1.0 * 2.5 = 2.5", 32'h40200000);

  fp_drive(fpu_pkg::FPU_OP_FMUL, 32'hc49a6333, 32'hbf8ccccd, 32'h00000000);
  fp_monitor("FMUL: -1235.1 * -1.1 = 1358.61", 32'h44a9d385);

  fp_drive(fpu_pkg::FPU_OP_FMUL, 32'h40490fdb, 32'h322bcc77, 32'h00000000);
  fp_monitor("FMUL: 3.14159265 * 0.00000001 = 3.14159265e-8", 32'h3306ee2d);
  
  // FMADD
  fp_drive(fpu_pkg::FPU_OP_FMADD, 32'h3f800000, 32'h40200000, 32'h3f800000);
  fp_monitor("FMADD: 1.0 * 2.5 + 1.0 = 3.5", 32'h40600000);

  fp_drive(fpu_pkg::FPU_OP_FMADD, 32'hc49a6333, 32'hbf800000, 32'h3f8ccccd);
  fp_monitor("FMADD: -1235.1 * -1.0 + 1.1 = 1236.2", 32'h449a8666);
  
  fp_drive(fpu_pkg::FPU_OP_FMADD, 32'h40000000, 32'hc0a00000, 32'hc0000000);
  fp_monitor("FMADD: 2.0 * -5.0 + -2.0 = -12.0", 32'hc1400000);
  
  #100 $finish;
end

// test task
logic [FPU_OP_NUM-1:0] op_data;
logic [FLEN-1:0]       rs1_data;
logic [FLEN-1:0]       rs2_data;
logic [FLEN-1:0]       rs3_data;
task automatic fp_drive(
  input logic [FPU_OP_NUM-1:0] op,
  input logic [FLEN-1:0]       rs1,
  input logic [FLEN-1:0]       rs2,
  input logic [FLEN-1:0]       rs3
);
  op_data  = op;
  rs1_data = rs1;
  rs2_data = rs2;
  rs3_data = rs3;
  
  #PERIOD
    i_op    = op_data;
    i_rs[1] = rs1_data;
    i_rs[2] = rs2_data;
    i_rs[3] = rs3_data;
endtask

logic [FLEN-1:0] result_data;
task automatic fp_monitor(
  input string           op_type,
  input logic [FLEN-1:0] result
);
  result_data = result;
  #PERIOD
    $display("--------------------------- TEST BEGIN --------------------------------");
    $display("\033[0;33mTEST %s\033[0m", op_type);
    $display("rs1 = %h, rs2 = %h, rs3 = %h", rs1_data, rs2_data, rs3_data);
    if (o_result[FLEN-1:8] == result_data[FLEN-1:8])
      $display("\033[0;32mPASS: result = %h, expected = %h\n\033[0m", o_result, result_data);
    else
      $display("\033[0;31mFAIL: result = %h, expected = %h\n\033[0m", o_result, result_data);
  
endtask

// dump wave
initial begin            
    $dumpfile("sim/simv.vcd");
    $dumpvars(0, tb_fpu);
end

endmodule