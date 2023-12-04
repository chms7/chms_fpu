//////////////////////////////////////////////////////////////////////////////////
// Copyright by FuxionLab
// 
// Designer     : Zhao Siwei
// Create Date  : 2023/9/19
// Project Name : ZeroCore
// File Name    : fpu_utils_lzc.sv
//
// Description  : Leading-zero count module
//
// Revision: 
// Revision 3.0 - File Created
//
//////////////////////////////////////////////////////////////////////////////////
   
module fpu_utils_lzc #(
  parameter int unsigned WIDTH = 51
) (
  input  logic [WIDTH-1:0]         in_i,
  output logic [$clog2(WIDTH)-1:0] leading_zero_cnt_o,
  output logic                     leading_zero_empty_o
);
  localparam int unsigned NUM_LEVELS = $clog2(WIDTH);

  logic [2**NUM_LEVELS-1:0]                  sel_nodes;
  logic [2**NUM_LEVELS-1:0][NUM_LEVELS-1:0]  index_nodes;

  logic [WIDTH-1:0] in_flipped;

  // flip input vector
  always @ (*) begin
    for (int unsigned i = 0; i < WIDTH; i++) begin
      in_flipped[i] = in_i[WIDTH-1-i];
    end
  end

  for (genvar level = 0; unsigned'(level) < NUM_LEVELS; level++) begin : g_levels
    if (unsigned'(level) == NUM_LEVELS-1) begin : g_last_level
      for (genvar k = 0; k < 2**level; k++) begin : g_level
         
        if (unsigned'(k) * 2 < WIDTH-1) begin
          assign sel_nodes[2**level-1+k]   = in_flipped[k*2] | in_flipped[k*2+1];
          assign index_nodes[2**level-1+k] = (in_flipped[k*2] == 1'b1) ? k*2 :
                                                                     k*2+1;
        end
         
        if (unsigned'(k) * 2 == WIDTH-1) begin
          assign sel_nodes[2**level-1+k]   = in_flipped[k*2];
          assign index_nodes[2**level-1+k] = k*2;
        end
         
        if (unsigned'(k) * 2 > WIDTH-1) begin
          assign sel_nodes[2**level-1+k]   = 1'b0;
          assign index_nodes[2**level-1+k] = '0;
        end
      end
    end else begin
      for (genvar l = 0; l < 2**level; l++) begin : g_level
        assign sel_nodes[2**level-1+l]   = sel_nodes[2**(level+1)-1+l*2] | sel_nodes[2**(level+1)-1+l*2+1];
        assign index_nodes[2**level-1+l] = (sel_nodes[2**(level+1)-1+l*2] == 1'b1) ? index_nodes[2**(level+1)-1+l*2] :
                                                                                     index_nodes[2**(level+1)-1+l*2+1];
      end
    end
  end

  assign leading_zero_cnt_o   = NUM_LEVELS > unsigned'(0) ? index_nodes[0] : $clog2(WIDTH)'(0);
  assign leading_zero_empty_o = NUM_LEVELS > unsigned'(0) ? ~sel_nodes[0]  : ~(|in_i);

endmodule : fpu_utils_lzc