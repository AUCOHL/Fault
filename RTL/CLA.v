// file: cla.v
// author: @manarabdelatty

`timescale 1ns/1ns

module CLA ( a , b ,  cin , s , PG, GG,co);
  input [3:0] a , b;
  input cin;
  
  output [3:0] s, PG, GG;

  wire [3:0] p , g;
  wire [4:0] c;
  output co;
  
  assign c[0]= cin;

  assign c[1] = g[0] || (c[0] & p[0]);
  assign c[2] = g[1] || (g[0] & p[1]) || (c[0] & p[0] & p[1]) ;
  assign c[3] = g[2] || (g[1] & p[2]) || (g[0] & p [1] & p[2])  || ( c[0] & p[0] & p[1] & p[2] );
  assign c[4] = g[3] || (g[2] & p[3]) ||  (g[1] & p[2] & p [3]) || (g[0] & p[1] & p[2] & p[3]) || (c[0] & p[0]& p[1]& p[2] & p[3]);
  assign PG   = p[0] & p [1] & p[2] & p[3];
  assign GG   =  g[3] | (g[2] & p[3] ) | (g[1] & p[3] & p[2]) | ( g[0] & p[3] & p[2] & p[1]);  


  genvar i;
   generate
     for (i=0; i<4;i=i+1) begin: add
       full_adder fa1 ( .a(a[i]), .b(b[i]) , .ci(c[i]) , .s(s[i]) , .p(p[i]) ,.g(g[i]));
     end
  endgenerate

  assign co = c[4];
  
endmodule

module full_adder ( a, b , ci , s , p , g ,co);

  input a, b , ci;
  output s , p , g,co;

  assign s = a ^ b ^ ci;
  assign p = a | b;
  assign g = a & b;
  
endmodule


