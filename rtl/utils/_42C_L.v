module _42C_L (
        I0,//
        I1,//
        I2,//
        I3,//
        Ci,//
        D,//
        C,//
        Co//
       );

parameter     DW = 8;
input [(DW-1):0]  I0,I1,I2,I3;
input         Ci;
output[DW:0]  D;
output[(DW+1):1]  C;
output        Co;
wire  [(DW-1):0]  TXR,TAO,TOA;
assign TXR = I0 ^ I1 ^ I2 ^ I3;                             //确定有1个，3个1

assign TAO = (I0 & I1) | (I2 & I3);                         //确定I0=I1=1或I2=I3=1或I1=I2=I3=I4=1
assign TOA = (I0 | I1) & (I2 | I3);                         //确定I0,I1或I2,I3中各至少有一个1
assign D = {TXR[DW-1],TXR} ^ {TOA,Ci};                      //
assign Co = TOA[DW-1];
assign C = ({TXR[(DW-1)],TXR} & {TOA,Ci}) | ((~ {TXR[(DW-1)],TXR}) & {TAO[(DW-1)],TAO});
endmodule

/*module _42C_L (
        I0,//
        I1,//
        I2,//
        I3,//
        Ci,//
        D,//
        C,//
        Co//
       );

parameter     DW = 8;
input [(DW-1):0]  I0,I1,I2,I3;
input         Ci;
output[DW:0]  D;
output[(DW+1):1]  C;
output        Co;

assign D=I0^I1^I2^I3^Ci;
assign C=((I0^I1^I2|I3)&Ci)|((~(I0^I1^I2^I3))&I3);
assign Co=((I0^I1)&I3)|((~(I0^I1))&I0);
endmodule
*/