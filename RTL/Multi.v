// file: unsigmult.v
// author: @fadwaelsaqa

`timescale 1ns/1ns
module nMult(a,b,p);
 
    parameter n=16;
    parameter m=16;
   
    input [n-1:0] a;
    input [m-1:0] b;
    output [n+m-1:0] p;
 
 
    wire [n-1:0] s [m-1:0];
    wire [m-1:0] c;
   
    nbit_RCA #(n) adder1 ({n{1'b0}}, ({n{b[0]}} & a)
                        , 1'b0
                        , s[0][n-1:0]
                        , c[0]
                        );
   
    genvar i,j;
   
    generate
        for (i=1; i<m; i=i+1)
         begin
            nbit_RCA #(n) adder2 ( {c[i-1],s[i-1][n-1:1]}
                                , ({n{b[i]}} & a)
                                , 1'b0
                                , s[i][n-1:0]
                                , c[i]
                                );
         end
   
 
        for (j=0; j<m-1; j=j+1)
         begin
            assign p[j] = s[j][0];
         end
 
    endgenerate
   
    assign p[n+m-1:m-1] = {c[m-1], s[m-1][n-1:0]};
   
endmodule

module nbit_RCA ( a , b, ci, s , co );
  parameter n = 16;

  input [n-1 : 0] a, b ;
  input ci;

  output [n-1: 0] s;
  output co;
  wire [n:0] c;

  assign c[0]= ci;
  assign co = c[n];

  genvar i;
     generate
          for ( i = 0 ; i < n ; i = i +1)  begin: addbit 
             full_adder fa (.a(a[i]), .b(b[i]), .ci(c[i]), .s(s[i]), .co(c[i+1]));
            end
      endgenerate
      
endmodule

module full_adder ( a, b , ci , s ,co );
  input a, b , ci;
  output s , co;

  assign s = a ^ b ^ ci;
  assign co = (a & b) | (a & ci) | (b & ci) ;

endmodule

