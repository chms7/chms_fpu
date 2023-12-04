
module CSA_L (
        A,//
        B,//
        Ci,//
        D,//
        Co//
       );
parameter     DW = 8;
input [(DW-1):0]  A,B,Ci;
output[(DW-1):0]  D;
output[DW:1]  Co;
assign D = A ^ B ^ Ci;
assign Co = A & B | B & Ci | Ci & A;
endmodule

