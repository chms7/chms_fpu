module Booth_1 (
       
      Encode,//
      AS,
        Source,//
        Result,//
        Carry,
        E//
      );
parameter DW = 8;
input [ 2:0]  Encode;	
input AS;

input [DW+1:0]  Source;
output[DW+1:0]  Result;

output[ 1:0]  Carry;
output E;

wire          Add_Sub,// add(0) or sub(1)
              Once_Valid,// once is valid if it is '1' else zero
              Twice_Enable,// twice is valid when it is '1' else zero
              Zero;


assign Add_Sub = Encode[2];                               //首位为0是正，为1是负
assign Once_Valid = (Encode[1] ^ Encode[0]);              //通过末尾两位判断加减1X
assign Twice_Enable =~(Encode[1] ^ Encode[0]);            //通过末尾两位判断加减2X
assign Zero=~(Encode[2] ^ Encode[1]);                     //通过前两位判断0X
          
assign Result = ~{(~(Source ^ {(DW+2){Add_Sub}}) |{(DW+2){Twice_Enable}} ) &
                          (~({Source,1'b0} ^ {(DW+2){Add_Sub}}) | {(DW+2){Zero}}|{(DW+2){Once_Valid}})};            
                          //Source先与Add_sub代码求同或，Add_sub
assign Carry = {1'b0,{Add_Sub & {Once_Valid &(~(Twice_Enable))|{(~(Once_Valid) &(Twice_Enable))&(~Zero)}}}};



assign E = (~(Encode[2] | Encode[1] | Encode[0])) | (Encode[2] & Encode[1] & Encode[0])
      | ((~(Source[DW] ^ Encode[2])) & AS )| (~(Encode[2] | AS));

endmodule


