//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_utils_shift.sv
//
// Description  : Barrel left/right shifter
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module fpu_utils_shift # (
  parameter SHIFT_MODE  = 0,
  parameter DATA_WIDTH  = 77,
  parameter SHAMT_WIDTH = 7
) (
  input  logic [DATA_WIDTH-1:0]  data_i,
  input  logic [SHAMT_WIDTH-1:0] shamt_i,
  output logic [DATA_WIDTH-1:0]  data_shifted_o
);
  generate
    if (SHIFT_MODE == 0) begin
      // left shift
      always @ (*) begin
        data_shifted_o = shamt_i[0] ? {data_i        [DATA_WIDTH-1 :0], 1'd0 } : data_i;
        data_shifted_o = shamt_i[1] ? {data_shifted_o[DATA_WIDTH-2 :0], 2'd0 } : data_shifted_o;
        data_shifted_o = shamt_i[2] ? {data_shifted_o[DATA_WIDTH-4 :0], 4'd0 } : data_shifted_o;
        data_shifted_o = shamt_i[3] ? {data_shifted_o[DATA_WIDTH-8 :0], 8'd0 } : data_shifted_o;
        data_shifted_o = shamt_i[4] ? {data_shifted_o[DATA_WIDTH-16:0], 16'd0} : data_shifted_o;
        data_shifted_o = shamt_i[5] ? {data_shifted_o[DATA_WIDTH-32:0], 32'd0} : data_shifted_o;
        data_shifted_o = shamt_i[6] ? {data_shifted_o[DATA_WIDTH-64:0], 64'd0} : data_shifted_o;
      end
    end else if (SHIFT_MODE == 1) begin
      // right shift
      always @ (*) begin
        data_shifted_o = shamt_i[0] ? {1'd0,  data_i        [DATA_WIDTH-1:1 ]} : data_i;
        data_shifted_o = shamt_i[1] ? {2'd0,  data_shifted_o[DATA_WIDTH-1:2 ]} : data_shifted_o;
        data_shifted_o = shamt_i[2] ? {4'd0,  data_shifted_o[DATA_WIDTH-1:4 ]} : data_shifted_o;
        data_shifted_o = shamt_i[3] ? {8'd0,  data_shifted_o[DATA_WIDTH-1:8 ]} : data_shifted_o;
        data_shifted_o = shamt_i[4] ? {16'd0, data_shifted_o[DATA_WIDTH-1:16]} : data_shifted_o;
        data_shifted_o = shamt_i[5] ? {32'd0, data_shifted_o[DATA_WIDTH-1:32]} : data_shifted_o;
        data_shifted_o = shamt_i[6] ? {64'd0, data_shifted_o[DATA_WIDTH-1:64]} : data_shifted_o;
      end
    end else begin
      assign data_shifted_o = '0;
    end
  endgenerate
  
endmodule