module Mux(in,out,sel);

input [7:0]in;
input [2:0]sel;
output out;

reg out;
wire [2:0]sel;
wire [7:0]in;

always @(sel or in)
begin

if (sel==0)
out = in[0];
else if (sel==1)
out = in[1];
else if (sel==2)
out = in[2];
else if (sel==3)
out = in[3];
else if (sel==4)
out = in[4];
else if (sel==5)
out = in[5];
else if (sel==6)
out = in[6];
else
out = in[7];
end

endmodule