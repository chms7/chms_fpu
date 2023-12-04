module Booth (
       
      Encode,//
      AS,
        Source,//
        Result,//
        Carry//
      );
parameter DW = 8;
input [ 2:0]  Encode;	
input AS;

input [DW+1:0]  Source;
output[DW+3:0]  Result;
//output[DW+1:0] Result_0;
output[ 1:0]  Carry;
wire E;

wire          Add_Sub,// Add_sub=0为加，=1为减
              Once_Valid,// once is valid if it is '1' else zero
              Twice_Enable,// twice is valid when it is '1' else zero
              Zero;
wire[DW+1:0] Result_0;

assign Add_Sub = Encode[2];
assign Once_Valid = (Encode[1] ^ Encode[0]);
assign Twice_Enable =~(Encode[1] ^ Encode[0]);
assign Zero=~(Encode[2] ^ Encode[1]);
          
assign Result_0 = ~{(~(Source ^ {(DW+2){Add_Sub}}) |{(DW+2){Twice_Enable}} ) &
                (~({Source,1'b0} ^ {(DW+2){Add_Sub}}) | {(DW+2){Zero}}|{(DW+2){Once_Valid}})};
                //Source与Add_sub同或， Add_sub=0为加，Source先取相反数，若为+2X，Twice_Enable =1,Once_Valid=0,Zero=0；
                //                     Source取相反数后，与(DW+2){Twice_Enable}的与全为1；
                //                     {Source,1'b0}将Source左移一位，即为X2，和{(DW+2){Zero}}以及{(DW+2){Once_Valid}相与为其自身，然后再取相反数。
                //                     Add_sub=1为减，Source不变，Source先不变，然后与加法内容相似，最后按位取反
assign Carry = {1'b0,{Add_Sub & {Once_Valid &(~(Twice_Enable))|{(~(Once_Valid) &(Twice_Enable))&(~Zero)}}}};
                //如果是减法，需取反加1，加1补给下一个部分积低位
assign Result ={1'b1,E,Result_0};

assign E = (~(Encode[2] | Encode[1] | Encode[0])) | (Encode[2] & Encode[1] & Encode[0])
      | ((~(Source[DW] ^ Encode[2])) & AS )| (~(Encode[2] | AS));  
      //Encode为000，Result_0的前三位为000;
      //Encode为111，Result_0的前三位为000;
      //Source[DW]与Encode[2]相同且AS=1. AS=1,Source前三位为000或111,
      //当Source[DW]=Encode[2]=0,Result_0的前三位为000或00X,当Source[DW]=Encode[2]=1,Result_0的前三位为000或00X;
      //Encode[2]=0且AS=0,Source前三位为000或001,
      //当Encode[2]=0，Result_0为000或001或00X或01X;
      //E为1，即为Result_0的首位为0.
endmodule



