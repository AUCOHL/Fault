module signed_mult(
  input [7:0]a,                         // Multiplicend 1
  input [7:0]b,                         // Multiplicend 2
  output reg [15:0]y                    // Result
  );
  
  reg [15:0]temp;
  reg [7:0]p;
  reg [7:0]q;
  reg m;
 
  always@(a or b)
  begin
  case({a[7],b[7]})
  2'b00:begin
		  y=a*b;
		  y=y>>6;
		  end  
		  
  2'b01:begin
        q=(~b)+1;
		  temp=a*q;
		  y=(~temp)+1;
		  end
		  
  2'b10:begin
        p=(~a)+1;
		  temp=p*b;
		  temp=temp>>6;
		  y=(~temp)+1;
		  end
		  
  2'b11:begin
        q=(~b)+1;
		  p=(~a)+1;
		  temp=p*q;
		  y=temp;
		  end	  
   default:begin
		  y=a*b;
		  end  
  
  endcase
  end


endmodule

module butterfly(
    output reg [31:0] sum,diff,                                           // 32-bit output registers to store sum and difference
    input [31:0] x,y,                                                     // 32-bit input nets x and y
    input en                                                              // To enable the operation of butterfly
    );

always @(en or x or y)
begin
  sum=x+y;
  diff=x-y;
end
endmodule

module dct(
	input clk,			                                   //	input clock
	input reset,		  	                                   //	reset
	input wr,		                                           //	writing data to memory
	input oe,		                                           //	displaying the final output
	input [7:0]data_in,	                                           //	8-bit data input
	input [2:0]add,		                                           //	3-bit address for data input
	output reg [7:0]data_out                                           //	8-bit data output
	);	                                        

wire signed [7:0] x01,x11,x21,x31,x41,x51,x61,x71;		            //	 wire for 1-stage butterfly
wire signed [7:0] x02,x12,x22,x32,x42,x52,x62,x72;		            //	wire for 2-stage butterfly
wire signed [7:0] x03,x13,x23,x33,x43,x53,x63,x73,x57,x56;                  // wire for 3-stage butterfly
wire signed [15:0] x04,x14,x24,x34,x44,x54,x64;		                    // wire for output drivers
wire signed [15:0] x55,x65,x75;                                             // intermediate stage values
wire signed [31:0] x1,x2;                                                   // partial products
wire signed [15:0] xx1,xx2,xx3,xx4,xx5,xx6,yy1,yy2,yy3,yy4,yy5,yy6;         // partial products

wire [7:0] 	c5= 8'd55,                                                  // 0.55  // ci = cos (i*pi/2*N)
		c6= 8'd38,                                                  // 0.38
		c7= 8'd19;                                                  // 0.19
		
wire [7:0] 	s5=8'd83,                                                   // 0.83 // si = sin (i*pi/2*N)
		s6=8'd92,                                                   // 0.92
		s7=8'd98;                                                   // 0.98 
				
wire [7:0] sqrt8_inv=8'd35;                                                 //0.35 
wire [15:0] sqrt2=16'b0101_1001_1001_1001;

reg [7:0]x[7:0];	                                    //	8-bit 8 locations data storage after reading

/****************************WRITING DATA TO MEMORY***********************/
always @( posedge clk) 
begin
if(reset)
x[add]=0;
else if(wr)
x[add]= data_in;
end

/*****************************1-STAGE BUTTERFLY****************************/
butterfly b1(x01,x71,x[0],x[7]);
butterfly b2(x11,x61,x[1],x[6]);
butterfly b3(x21,x51,x[2],x[5]);
butterfly b4(x31,x41,x[3],x[4]);

/******************************2-STAGE BUTTERFLY**************************/
butterfly b5(x02,x32,x01,x31);
butterfly b6(x12,x22,x11,x21);
signed_mult sm1(.a(x41),.b(c7),.y(xx1));
signed_mult sm2(.a(x41),.b(s7),.y(xx2));
signed_mult sm3(.a(x71),.b(c7),.y(yy1));
signed_mult sm4(.a(x71),.b(s7),.y(yy2));

assign x42=xx1+yy2;
assign x72=-xx2+yy1;

signed_mult sm5(.a(x51),.b(c5),.y(xx3));
signed_mult sm6(.a(x51),.b(s5),.y(xx4));
signed_mult sm7(.a(x61),.b(c5),.y(yy3));
signed_mult sm8(.a(x61),.b(s5),.y(yy4));

assign x52=xx3+yy4;
assign x62=yy3-xx4;

/*****************************3-STAGE BUTTERFLY****************************/
butterfly b9(x03,x13,x02,x12);

signed_mult sm9(.a(x22),.b(c6),.y(xx5));
signed_mult sm10(.a(x22),.b(s6),.y(xx6));
signed_mult sm11(.a(x32),.b(c6),.y(yy5));
signed_mult sm12(.a(x32),.b(s6),.y(yy6));
assign x23=xx5+yy6;
assign x33=-xx6+yy5;

butterfly b11(x43,x53,x42,x52);
butterfly b12(x63,x73,x62,x72);

assign x1=(x03*sqrt8);
assign x04=x1>>16;

/***************calculate y4 = x1/sqrt8*****************/
signed_mult sm14(.a(x13),.b(sqrt8_inv),.y(x14));

/**************calculate y2,y6,y1 as x2,x3,x4 divide by 2****************/
assign x24= (x23>>1);
assign x34 = (x33>>1);
assign x44= (x43>>1);

/***************calculate y3, y5 using butterfly*****************/
assign x54 = x53 + x63;
assign x64 = x53 - x63;   
assign x2=(x54*sqrt8);
assign x55=x2>>16;	
assign x56=x55>>2;
assign x57=x56>>4;

signed_mult sm16(.a(x64),.b(sqrt8_inv),.y(x65));


/**************calculate y7=-x7/2*****************/
assign x75 = (x73>>1);

/**************DISPLAY THE FINAL OUTPUT ACC. TO ADDRESS GIVEN*************/
always @(add)
begin
if(oe)
case(add)
	3'b000: data_out=x04;
	3'b001: data_out=x44;
	3'b010: data_out=x24;
	3'b011: data_out=x65;
	3'b100: data_out=x14;
	3'b101: data_out=x57;
	3'b110: data_out=x34;
	3'b111: data_out=x75;
	default: data_out=0;
endcase
else
data_out=0;
end
endmodule
