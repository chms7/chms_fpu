module CL4(
        G,//
        P,//
        Ci,//
        C,//
        Gx,//
        Px//
       );
input [ 7:0]  G,P;
input         Ci;
output[ 8:1]  C;
output        Gx,Px;
assign C[1] = G[0] | P[0] & Ci;
assign C[2] = G[1] | P[1] & C[1];
assign C[3] = G[2] | P[2] & C[2];
assign C[4] = G[3] | P[3] & C[3];
assign C[5] = G[4] | P[4] & C[4];
assign C[6] = G[5] | P[5] & C[5];
assign C[7] = G[6] | P[6] & C[6];
assign C[8] = G[7] | P[7] & C[7];
assign Gx = G[7] | P[7] & G[6] |P[7] & P[6] & G[5] | P[7] & P[6] & P[5] & G[4] 
        | P[7] & P[6] & P[5] & P[4] &G[3] | P[7] & P[6] & P[5] & P[4] & P[3] & G[2] 
        | P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & G[1] 
        | P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & G[0]; 
        
assign Px = P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & P[0];




endmodule
