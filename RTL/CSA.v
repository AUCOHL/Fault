// file: carryselect.v
// author: @mariamlotfi

`timescale 1ns/1ns



module carryselect ( a, b, ci ,co , s);
  parameter n= 8, k=4, type = 1;  // type 1 : CLA , type 0 :RCA
  
  input [n-1 :0]  a, b;
  input ci;
  
  output co;
  output[n-1 :0]  s;
  
  wire [2:0] cc; 
  wire trash ;

  wire [k-1:0] sum1;
  wire [k-1:0] sum2;
  wire sumOut;

  wire cin2, cin3;
  wire joined;
  
  assign cin2= 1'b 0;
  assign cin3= 1'b 1;



   genvar i;
   
     generate
          for ( i = 0 ; i < k ; i = i +1 )  begin: addbit 
          mux2x1 mux(.a(sum1[i]), .b(sum2[i]), .sel(cc[0]), .o(s[i+k]));
           end
           
          
         if (type ==1 && k==4 ) begin
            cla4_adder adder1 ( .a(a[k-1 :0]) , .b(b[k-1:0]) ,  .cin(ci) ,   .s(s[k-1:0])   ,  .co(cc[0]));
            cla4_adder adder2 ( .a(a[n-1: k]) , .b(b[n-1:k]) ,  .cin(cin2) , .s(sum1[k-1:0]) , .co(cc[1]));
            cla4_adder adder3 ( .a(a[n-1 :k]) , .b(b[n-1:k]) ,  .cin(cin3) , .s(sum2[k-1:0]) , .co(cc[2]));
         end
  
        else
           begin
           nbit_RCA #(k) rca1 (.a(a[k-1 :0]), .b(b[k-1:0]), .ci(ci)  , .s(s[k-1:0])   , .co(cc[0]));
           nbit_RCA #(k) rca2 (.a(a[n-1: k]), .b(b[n-1:k]), .ci(cin2), .s(sum1[k-1:0]), .co(cc[1]));
           nbit_RCA #(k) rca3 (.a(a[n-1 :k]), .b(b[n-1:k]), .ci(cin3), .s(sum2[k-1:0]), .co(cc[2]));
    end
      endgenerate
      
    mux2x1 mux2(.a(cc[1]), .b(cc[2]), .sel(cc[0]), .o(co));

endmodule

module cla4_adder ( a , b ,  cin , s , co);
  input [3:0] a , b;
  input cin;
  output co;
  output [3:0] s;

  wire [3:0] p , g;
  wire [4:0] c;
  
  assign c[0]= cin;
  assign c[1] = g[0] || (c[0] & p[0]);
  assign c[2] = g[1] || (g[0] & p[1]) || (c[0] & p[0] & p[1]) ;
  assign c[3] = g[2] || (g[1] & p[2]) || (g[0] & p [1] & p[2])  || ( c[0] & p[0] & p[1] & p[2] );
  assign c[4] = g[3] || (g[2] & p[3]) ||  (g[1] & p[2] & p [3]) || (g[0] & p[1] & p[2] & p[3]) || (c[0] & p[0]& p[1]& p[2] & p[3]);
 


  genvar i;
   generate
     for (i=0; i<4;i=i+1) begin: add
       full_adderCLA fa1 ( .a(a[i]), .b(b[i]) , .ci(c[i]) , .s(s[i]) , .p(p[i]) ,.g(g[i]));
     end
  endgenerate

  assign co = c[4];
  
endmodule


module full_adderCLA ( a, b , ci , s , p , g );
  input a, b , ci;
  output s , p , g;
  
  assign s = a ^ b ^ ci;
  assign p = a | b;
  assign g = a & b;
  
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

module mux2x1 (a, b, sel, o);
  input a,b, sel;
  output o;
  
  assign o= (~sel & a) | (sel & b); 

endmodule

