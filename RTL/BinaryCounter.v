module BinaryCounter(clk,clr,dir, temp);
    input clk,clr,dir;
    output reg[3:0] temp;
    always@(posedge clk,posedge clr)
begin
if(clr==0)
begin
if(dir==0)
temp=temp+1;
else temp=temp-1;
end
else
temp=4'd0;
end
endmodule