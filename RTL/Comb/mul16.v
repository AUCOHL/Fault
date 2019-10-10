module mul16(a,b,c);
 
    input [15:0]a,b;
    output [31:0]c;
     
    wire [15:0]q0,q1,q2,q3,q4,temp1;
    wire [31:0]c;
    wire [23:0]q5,q6,temp2,temp3,temp4;
     
    array8 z1(a[7:0],b[7:0],q0[15:0]);
    array8 z2(a[15:8],b[7:0],q1[15:0]);
    array8 z3(a[7:0],b[15:8],q2[15:0]);
    array8 z4(a[15:8],b[15:8],q3[15:0]);
    assign temp1 ={8'b0,q0[15:8]};
    assign q4 = q1[15:0]+temp1;
    assign temp2 ={8'b0,q2[15:0]};
    assign temp3 ={q3[15:0],8'b0};
    assign q5 = temp2+temp3;
    assign temp4={8'b0,q4[15:0]};
     
    assign q6 = temp4 + q5;
     
    assign c[7:0]=q0[7:0];
    assign c[31:8]=q6[23:0];
 
endmodule
 
module array2(a, b, c);
    input [1:0]a, b;
    output [3:0]c;
    wire [3:0]c, temp;
     
    assign c[0]=a[0]&b[0];
    assign temp[0]=a[1]&b[0];
    assign temp[1]=a[0]&b[1];
    assign temp[2]=a[1]&b[1];
    ha z1(temp[0],temp[1],c[1],temp[3]);
    ha z2(temp[2],temp[3],c[2],c[3]);
 
endmodule
 
module array4(a,b,c);
    input [3:0]a, b;
    output [7:0]c;
     
    wire [3:0]q0,q1,q2,q3,q4,temp1;
     
    wire [7:0]c;
    wire [5:0]q5,q6,temp2,temp3,temp4;
     
    array2 z1(a[1:0],b[1:0],q0[3:0]);
    array2 z2(a[3:2],b[1:0],q1[3:0]);
    array2 z3(a[1:0],b[3:2],q2[3:0]);
    array2 z4(a[3:2],b[3:2],q3[3:0]);
     
    assign temp1 ={2'b0,q0[3:2]};
    assign q4 = q1[3:0]+temp1;
    assign temp2 ={2'b0,q2[3:0]};
    assign temp3 ={q3[3:0],2'b0};
    assign q5 = temp2+temp3;
    assign temp4={2'b0,q4[3:0]};
    assign q6 = temp4+q5;
     
    assign c[1:0]=q0[1:0];
    assign c[7:2]=q6[5:0];
endmodule
 
module array8(a,b,c);
    input [7:0]a,b;
    output [15:0]c;
     
    wire [15:0]q0,q1,q2,q3,c;
    wire [7:0]q4,temp1;
    wire [11:0]q5,q6,temp2temp3,temp4;
     
    array4 z1(a[3:0],b[3:0],q0[15:0]);
    array4 z2(a[7:4],b[3:0],q1[15:0]);
    array4 z3(a[3:0],b[7:4],q2[15:0]);
    array4 z4(a[7:4],b[7:4],q3[15:0]);
     
    assign temp1 ={4'b0,q0[7:4]};
    assign q4 = q1[7:0]+temp1;
    assign temp2 ={4'b0,q2[7:0]};
    assign temp3 ={q3[7:0],4'b0};
    assign q5 = temp2+temp3;
    assign temp4={4'b0,q4[7:0]};
     
    // stage 2 adder
    assign q6 = temp4+q5;
     
    // final output assignment
    assign c[3:0]=q0[3:0];
    assign c[15:4]=q6[11:0];
endmodule
 
module ha(a,b,s,c);
    input a,b;
    output s,c;
     
    assign s = a^b;
    assign c = a&b;
endmodule

