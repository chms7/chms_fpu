module multiply_32bit (
        AD,// A operand
        AS,// extend style for A        
           // 当BD为有符号数需要符号位拓展时，AS为1，BD为无符号数不需要符号位拓展时，AS为0 
           // BD被拓展两位符号位，代入后续计算
        BS,
        BD,// B operand         
        D// result data
        
       );
input [31:0]  AD,BD;
input         AS,BS;

output[63:0]  D;

wire  [63:0]  TAR;// temp leading adder result
wire  [63:0]  TES,// temp counter array pseudo sum
              TEC;// temp counter array pseudo carry
//  *  *  output

assign D = TAR;


wire  [63:0]  TAG,TAP;//g & p         
wire  [64:1]  TAC;// carry   
wire  [7:0]  TAG_S0,TAP_S0;

wire  [8:1]  TAC_S1;

wire  [ 4:1]  TAC_S2;


assign TAG = TES & TEC;
assign TAP = TES ^ TEC;
assign TAR = TAP ^ {TAC,1'b0};



CL4 				 CL_S0_P0 (TAG[ 7: 0],TAP[ 7: 0],1'b0,TAC[ 8: 1],TAG_S0[0],TAP_S0[0]),
                CL_S0_P1 (TAG[15: 8],TAP[15: 8],TAC_S1[1],TAC[16: 9],TAG_S0[1],TAP_S0[1]),
                CL_S0_P2 (TAG[23:16],TAP[23:16],TAC_S1[2],TAC[24:17],TAG_S0[2],TAP_S0[2]),
                CL_S0_P3 (TAG[31:24],TAP[31:24],TAC_S1[3],TAC[32:25],TAG_S0[3],TAP_S0[3]),
                CL_S0_P4 (TAG[39:32],TAP[39:32],TAC_S1[4],TAC[40:33],TAG_S0[4],TAP_S0[4]),
                CL_S0_P5 (TAG[47:40],TAP[47:40],TAC_S1[5],TAC[48:41],TAG_S0[5],TAP_S0[5]),
                CL_S0_P6 (TAG[55:48],TAP[55:48],TAC_S1[6],TAC[56:49],TAG_S0[6],TAP_S0[6]),
                CL_S0_P7 (TAG[63:56],TAP[63:56],TAC_S1[7],TAC[64:57],TAG_S0[7],TAP_S0[7]);
 
					 
					 
CL4 CL_S1_P0 (TAG_S0[7:0],TAP_S0[7:0],1'b0,TAC_S1[8:1],,);




//  *  *  booth encode & booth process

wire  [33: 0] TD_BP_I0_0;
wire  [37: 2] TD_BP_I1;
wire  [39: 4] TD_BP_I2;
wire  [41: 6] TD_BP_I3;
wire  [43: 8] TD_BP_I4;
wire  [45:10] TD_BP_I5;
wire  [47:12] TD_BP_I6; 
wire  [49:14] TD_BP_I7;
wire  [51:16] TD_BP_I8;
wire  [53:18] TD_BP_I9;
wire  [55:20] TD_BP_I10;
wire  [57:22] TD_BP_I11;
wire  [59:24] TD_BP_I12;
wire  [61:26] TD_BP_I13;
wire  [63:28] TD_BP_I14;
wire  [63:30] TD_BP_I15_0;
wire  [65:32] TD_BP_I16;

wire  [31:0]  XC_BP;

wire E0,E15;

Booth_1 Booth_I0 ({AD[1:0],1'b0},AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I0_0,XC_BP[ 1: 0],E0);
Booth  Booth_I1 (AD[ 3: 1],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I1,XC_BP[ 3: 2]),
      Booth_I2 (AD[ 5: 3],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I2,XC_BP[ 5: 4]),
      Booth_I3 (AD[ 7: 5],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I3,XC_BP[ 7: 6]),
      Booth_I4 (AD[ 9: 7],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I4,XC_BP[ 9: 8]),
      Booth_I5 (AD[11: 9],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I5,XC_BP[11:10]),
      Booth_I6 (AD[13:11],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I6,XC_BP[13:12]),
      Booth_I7 (AD[15:13],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I7,XC_BP[15:14]),
      Booth_I8 (AD[17:15],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I8,XC_BP[17:16]),
    Booth_I9 (AD[19:17],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I9,XC_BP[19:18]),
    Booth_I10 (AD[21:19],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I10,XC_BP[21:20]),
    Booth_I11 (AD[23:21],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I11,XC_BP[23:22]),
    Booth_I12 (AD[25:23],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I12,XC_BP[25:24]),
    Booth_I13 (AD[27:25],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I13,XC_BP[27:26]),
    Booth_I14 (AD[29:27],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I14,XC_BP[29:28]);
Booth_1	Booth_I15 (AD[31:29],AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I15_0,XC_BP[31:30],E15),
    Booth_I16 ({(BS & AD[31]),(BS & AD[31]),AD[31]},AS,{(AS & BD[31]),(AS & BD[31]),BD},TD_BP_I16,,);


defparam Booth_I0.DW = 32,Booth_I1.DW = 32,Booth_I2.DW = 32,
     Booth_I3.DW = 32,Booth_I4.DW = 32,Booth_I5.DW = 32,
     Booth_I6.DW = 32,Booth_I7.DW = 32,Booth_I8.DW = 32,
  Booth_I9.DW = 32,Booth_I10.DW = 32,Booth_I11.DW = 32,
  Booth_I12.DW = 32,Booth_I13.DW = 32,Booth_I14.DW = 32,
  Booth_I15.DW = 32,Booth_I16.DW = 32;                           //输入34位，输出36位

wire  [36:0] TD_BP_I0;
wire  [64:30] TD_BP_I15;


assign TD_BP_I0 = {E0,~E0,~E0,TD_BP_I0_0};
assign TD_BP_I15 = {E15,TD_BP_I15_0};


//  *  *  counter array
wire  [39:0]  CAV_L1_L1_D;
wire  [40:1]  CAV_L1_L1_C;
wire  [45:6] CAV_L1_L2_D;
wire  [46:7] CAV_L1_L2_C;
wire  [51:12] CAV_L1_L3_D;
wire  [52:13] CAV_L1_L3_C;
wire  [57:18] CAV_L1_L4_D;
wire  [58:19] CAV_L1_L4_C;
wire  [63:24]  CAV_L1_L5_D;
wire  [64:25]  CAV_L1_L5_C;
wire  [69:30] CAV_L1_L6_D;
wire  [70:31] CAV_L1_L6_C;


wire  [47:0]  CAV_L2_L1_D;
wire  [48:1]  CAV_L2_L1_C;//wire  [33:9]  CAV_L2_L1_C;
wire  [59:12]  CAV_L2_L2_D;
wire  [60:13]  CAV_L2_L2_C;
wire  [71:24]  CAV_L2_L3_D;
wire  [72:25]  CAV_L2_L3_C;


wire  [59:0]  CAV_L3_L1_D;
wire  [60:1]  CAV_L3_L1_C;
wire  [72:13]  CAV_L3_L2_D;
wire  [73:14]  CAV_L3_L2_C;

wire  [74:0]  CAV_L4_L1_D;
wire  [75:1]  CAV_L4_L1_C;

// Level 1 Line 1
CSA_L CSA_L1_L1 (
        {3'b000,TD_BP_I0},                          //为什么前面是0，而不是根据符号位判断？
        {2'b00,TD_BP_I1,XC_BP[1:0]},                //后面的XC_BP是如果上一个部分积乘的是负数，上个部分积取反，在该位部分积末尾位加1
        {TD_BP_I2,XC_BP[3:2],2'b00},                 
        CAV_L1_L1_D,
        CAV_L1_L1_C
       );
defparam CSA_L1_L1.DW = 40;                         //使用defparam重新定义参数值为40 在函数名前用#（40）效果相同

// Level 1 Line 2
CSA_L CSA_L1_L2 (
        {4'b000,TD_BP_I3},
        {2'b00,TD_BP_I4,XC_BP[7:6]},
        {TD_BP_I5,XC_BP[9:8],2'b00},
        CAV_L1_L2_D,
        CAV_L1_L2_C
       );
defparam CSA_L1_L2.DW = 40;

// Level 1 Line 3
CSA_L CSA_L1_L3 (
        {4'b000,TD_BP_I6},
        {2'b00,TD_BP_I7,XC_BP[13:12]},
        {TD_BP_I8,XC_BP[15:14],2'b00},
        CAV_L1_L3_D,
        CAV_L1_L3_C
       );
defparam CSA_L1_L3.DW = 40;

// Level 1 Line 4
CSA_L CSA_L1_L4 (
        {4'b000,TD_BP_I9},
        {2'b00,TD_BP_I10,XC_BP[19:18]},
        {TD_BP_I11,XC_BP[21:20],2'b00},
        CAV_L1_L4_D,
        CAV_L1_L4_C
       );
defparam CSA_L1_L4.DW = 40;

// Level 1 Line 5
CSA_L CSA_L1_L5 (
        {4'b000,TD_BP_I12},
        {2'b00,TD_BP_I13,XC_BP[25:24]},
        {TD_BP_I14,XC_BP[27:26],2'b00},
        CAV_L1_L5_D,
        CAV_L1_L5_C
       );
defparam CSA_L1_L5.DW = 40;

// Level 1 Line 6
CSA_L CSA_L1_L6 (
        {5'b000,TD_BP_I15},
        {4'b00,TD_BP_I16,XC_BP[31:30]},
        {40'b00},
        CAV_L1_L6_D,
        CAV_L1_L6_C
       );
defparam CSA_L1_L6.DW = 40;



// Level 2 Line 1
_42C_L _42C_L_L2_L1 (
        {7'b0000_000,CAV_L1_L1_D},                    //第一级压缩器1是40位，压缩后为【39：0】和【40：1】的两行
                                                      //
        {6'b0000_00,CAV_L1_L1_C,1'b0},
        {1'b0,CAV_L1_L2_D,XC_BP[5:4],4'b0000},
        {CAV_L1_L2_C,7'b0000_000},
      1'b0,
        CAV_L2_L1_D,
        CAV_L2_L1_C,
       );
defparam _42C_L_L2_L1.DW = 47;


// Level 2 Line 2

_42C_L _42C_L_L2_L2 (
        {7'b0000_000,CAV_L1_L3_D},
        {6'b0000_00,CAV_L1_L3_C,1'b0},
        {1'b0,CAV_L1_L4_D,XC_BP[17:16],4'b0000},
        {CAV_L1_L4_C,7'b0000_000},
      1'b0,
        CAV_L2_L2_D,
        CAV_L2_L2_C,
       );
defparam _42C_L_L2_L2.DW = 47;


// Level 2 Line 3


_42C_L _42C_L_L2_L3 (
        {7'b0000_000,CAV_L1_L5_D},
        {6'b0000_00,CAV_L1_L5_C,1'b0},
        {1'b0,CAV_L1_L6_D,XC_BP[29:28],4'b0000},
        {CAV_L1_L6_C,7'b0000_000},
         1'b0,
        CAV_L2_L3_D,
        CAV_L2_L3_C,
       );
defparam _42C_L_L2_L3.DW = 47;



// Level 3 Line 1
CSA_L CSA_L3_L1 (
        {12'b0000_0000_0000,CAV_L2_L1_D},
        {11'b0000_0000_000,CAV_L2_L1_C,1'b0},
        {CAV_L2_L2_D,XC_BP[11:10],10'b0000_0000_00},
        CAV_L3_L1_D,
        CAV_L3_L1_C
       );
defparam CSA_L3_L1.DW = 60;


// Level 3 Line 2
CSA_L CSA_L3_L2 (
        {1'b0,CAV_L2_L3_D,XC_BP[23:22],9'b0000_0000_0},
        {CAV_L2_L3_C,12'b0000_0000_0000},
        {12'b0000_0000_0000,CAV_L2_L2_C},
        CAV_L3_L2_D,
        CAV_L3_L2_C
       );
defparam CSA_L3_L2.DW = 60;



// Level 4 Line 1

_42C_L _42C_L_L4_L1 (
        {14'b0000_0000_0000_00,CAV_L3_L1_D},
        {13'b0000_0000_0000_0,CAV_L3_L1_C,1'b0},
        {1'b0,CAV_L3_L2_D,13'b0000_0000_0000_0},
        {CAV_L3_L2_C,14'b0000_0000_0000_00},
        1'b0,
        CAV_L4_L1_D,
        CAV_L4_L1_C,
       );
defparam _42C_L_L4_L1.DW = 74;



assign TES = CAV_L4_L1_D;
assign TEC = {CAV_L4_L1_C,1'b0};
endmodule
