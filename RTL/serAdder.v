// file: serAdder.v
// author: @Mohamed Shalan

`timescale 1ns/1ns

module serAdder(clk, rst, a, b, s);
input clk;
input rst;
input a, b;
output s;

reg c;
wire co;

assign {co,s} = a + b + c;

always @ (posedge clk)
   if(rst) c <= 0;
   else c <= co;

endmodule