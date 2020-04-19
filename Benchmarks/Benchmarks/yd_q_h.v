/////////////////////////////////////////////////////////////////////
////                                                             ////
////  JPEG Encoder Core - Verilog                                ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

/* This module combines the dct, quantizer, and huffman modules. */

`timescale 1ns / 100ps

module yd_q_h(clk, rst, enable, data_in,
JPEG_bitstream, 
  data_ready, y_orc, end_of_block_output,
   end_of_block_empty);
input		clk;
input		rst;
input		enable;
input	[7:0]	data_in;
output  [31:0]  JPEG_bitstream;
output		data_ready;
output [4:0] y_orc;
output	end_of_block_output;
output	end_of_block_empty;


wire	dct_enable, quantizer_enable;
wire [10:0] Z11_final, Z12_final, Z13_final, Z14_final;
wire [10:0] Z15_final, Z16_final, Z17_final, Z18_final;
wire [10:0] Z21_final, Z22_final, Z23_final, Z24_final;
wire [10:0] Z25_final, Z26_final, Z27_final, Z28_final;
wire [10:0] Z31_final, Z32_final, Z33_final, Z34_final;
wire [10:0] Z35_final, Z36_final, Z37_final, Z38_final;
wire [10:0] Z41_final, Z42_final, Z43_final, Z44_final;
wire [10:0] Z45_final, Z46_final, Z47_final, Z48_final;
wire [10:0] Z51_final, Z52_final, Z53_final, Z54_final;
wire [10:0] Z55_final, Z56_final, Z57_final, Z58_final;
wire [10:0] Z61_final, Z62_final, Z63_final, Z64_final;
wire [10:0] Z65_final, Z66_final, Z67_final, Z68_final;
wire [10:0] Z71_final, Z72_final, Z73_final, Z74_final;
wire [10:0] Z75_final, Z76_final, Z77_final, Z78_final;
wire [10:0] Z81_final, Z82_final, Z83_final, Z84_final;
wire [10:0] Z85_final, Z86_final, Z87_final, Z88_final;
wire [10:0] Q11, Q12, Q13, Q14, Q15, Q16, Q17, Q18; 	
wire [10:0] Q21, Q22, Q23, Q24, Q25, Q26, Q27, Q28; 
wire [10:0] Q31, Q32, Q33, Q34, Q35, Q36, Q37, Q38; 
wire [10:0] Q41, Q42, Q43, Q44, Q45, Q46, Q47, Q48; 
wire [10:0] Q51, Q52, Q53, Q54, Q55, Q56, Q57, Q58; 
wire [10:0] Q61, Q62, Q63, Q64, Q65, Q66, Q67, Q68; 
wire [10:0] Q71, Q72, Q73, Q74, Q75, Q76, Q77, Q78; 
wire [10:0] Q81, Q82, Q83, Q84, Q85, Q86, Q87, Q88; 

	y_dct u1(
	.clk(clk),.rst(rst), .enable(enable), .data_in(data_in), 
	.Z11_final(Z11_final), .Z12_final(Z12_final), 
	.Z13_final(Z13_final), .Z14_final(Z14_final), .Z15_final(Z15_final), .Z16_final(Z16_final), 
	.Z17_final(Z17_final), .Z18_final(Z18_final), .Z21_final(Z21_final), .Z22_final(Z22_final), 
	.Z23_final(Z23_final), .Z24_final(Z24_final), .Z25_final(Z25_final), .Z26_final(Z26_final), 
	.Z27_final(Z27_final), .Z28_final(Z28_final), .Z31_final(Z31_final), .Z32_final(Z32_final), 
	.Z33_final(Z33_final), .Z34_final(Z34_final), .Z35_final(Z35_final), .Z36_final(Z36_final), 
	.Z37_final(Z37_final), .Z38_final(Z38_final), .Z41_final(Z41_final), .Z42_final(Z42_final), 
	.Z43_final(Z43_final), .Z44_final(Z44_final), .Z45_final(Z45_final), .Z46_final(Z46_final), 
	.Z47_final(Z47_final), .Z48_final(Z48_final), .Z51_final(Z51_final), .Z52_final(Z52_final), 
	.Z53_final(Z53_final), .Z54_final(Z54_final), .Z55_final(Z55_final), .Z56_final(Z56_final), 
	.Z57_final(Z57_final), .Z58_final(Z58_final), .Z61_final(Z61_final), .Z62_final(Z62_final), 
	.Z63_final(Z63_final), .Z64_final(Z64_final), .Z65_final(Z65_final), .Z66_final(Z66_final), 
	.Z67_final(Z67_final), .Z68_final(Z68_final), .Z71_final(Z71_final), .Z72_final(Z72_final), 
	.Z73_final(Z73_final), .Z74_final(Z74_final), .Z75_final(Z75_final), .Z76_final(Z76_final), 
	.Z77_final(Z77_final), .Z78_final(Z78_final), .Z81_final(Z81_final), .Z82_final(Z82_final), 
	.Z83_final(Z83_final), .Z84_final(Z84_final), .Z85_final(Z85_final), .Z86_final(Z86_final), 
	.Z87_final(Z87_final), .Z88_final(Z88_final), .output_enable(dct_enable)); 
	
	y_quantizer u2(
	.clk(clk),.rst(rst),.enable(dct_enable),
	.Z11(Z11_final), .Z12(Z12_final), .Z13(Z13_final), .Z14(Z14_final), 
	.Z15(Z15_final), .Z16(Z16_final), .Z17(Z17_final), .Z18(Z18_final), 
	.Z21(Z21_final), .Z22(Z22_final), .Z23(Z23_final), .Z24(Z24_final), 
	.Z25(Z25_final), .Z26(Z26_final), .Z27(Z27_final), .Z28(Z28_final),
	.Z31(Z31_final), .Z32(Z32_final), .Z33(Z33_final), .Z34(Z34_final), 
	.Z35(Z35_final), .Z36(Z36_final), .Z37(Z37_final), .Z38(Z38_final), 
	.Z41(Z41_final), .Z42(Z42_final), .Z43(Z43_final), .Z44(Z44_final), 
	.Z45(Z45_final), .Z46(Z46_final), .Z47(Z47_final), .Z48(Z48_final),
	.Z51(Z51_final), .Z52(Z52_final), .Z53(Z53_final), .Z54(Z54_final), 
	.Z55(Z55_final), .Z56(Z56_final), .Z57(Z57_final), .Z58(Z58_final), 
	.Z61(Z61_final), .Z62(Z62_final), .Z63(Z63_final), .Z64(Z64_final), 
	.Z65(Z65_final), .Z66(Z66_final), .Z67(Z67_final), .Z68(Z68_final),
	.Z71(Z71_final), .Z72(Z72_final), .Z73(Z73_final), .Z74(Z74_final), 
	.Z75(Z75_final), .Z76(Z76_final), .Z77(Z77_final), .Z78(Z78_final), 
	.Z81(Z81_final), .Z82(Z82_final), .Z83(Z83_final), .Z84(Z84_final), 
	.Z85(Z85_final), .Z86(Z86_final), .Z87(Z87_final), .Z88(Z88_final),
	.Q11(Q11), .Q12(Q12), .Q13(Q13), .Q14(Q14), .Q15(Q15), .Q16(Q16), .Q17(Q17), .Q18(Q18), 
	.Q21(Q21), .Q22(Q22), .Q23(Q23), .Q24(Q24), .Q25(Q25), .Q26(Q26), .Q27(Q27), .Q28(Q28),
	.Q31(Q31), .Q32(Q32), .Q33(Q33), .Q34(Q34), .Q35(Q35), .Q36(Q36), .Q37(Q37), .Q38(Q38), 
	.Q41(Q41), .Q42(Q42), .Q43(Q43), .Q44(Q44), .Q45(Q45), .Q46(Q46), .Q47(Q47), .Q48(Q48),
	.Q51(Q51), .Q52(Q52), .Q53(Q53), .Q54(Q54), .Q55(Q55), .Q56(Q56), .Q57(Q57), .Q58(Q58), 
	.Q61(Q61), .Q62(Q62), .Q63(Q63), .Q64(Q64), .Q65(Q65), .Q66(Q66), .Q67(Q67), .Q68(Q68),
	.Q71(Q71), .Q72(Q72), .Q73(Q73), .Q74(Q74), .Q75(Q75), .Q76(Q76), .Q77(Q77), .Q78(Q78), 
	.Q81(Q81), .Q82(Q82), .Q83(Q83), .Q84(Q84), .Q85(Q85), .Q86(Q86), .Q87(Q87), .Q88(Q88),
	.out_enable(quantizer_enable));

	y_huff u3(.clk(clk), .rst(rst), .enable(quantizer_enable), 
	.Y11(Q11), .Y12(Q21), .Y13(Q31), .Y14(Q41), .Y15(Q51), .Y16(Q61), .Y17(Q71), .Y18(Q81), 
	.Y21(Q12), .Y22(Q22), .Y23(Q32), .Y24(Q42), .Y25(Q52), .Y26(Q62), .Y27(Q72), .Y28(Q82),
	.Y31(Q13), .Y32(Q23), .Y33(Q33), .Y34(Q43), .Y35(Q53), .Y36(Q63), .Y37(Q73), .Y38(Q83), 
	.Y41(Q14), .Y42(Q24), .Y43(Q34), .Y44(Q44), .Y45(Q54), .Y46(Q64), .Y47(Q74), .Y48(Q84),
	.Y51(Q15), .Y52(Q25), .Y53(Q35), .Y54(Q45), .Y55(Q55), .Y56(Q65), .Y57(Q75), .Y58(Q85), 
	.Y61(Q16), .Y62(Q26), .Y63(Q36), .Y64(Q46), .Y65(Q56), .Y66(Q66), .Y67(Q76), .Y68(Q86),
	.Y71(Q17), .Y72(Q27), .Y73(Q37), .Y74(Q47), .Y75(Q57), .Y76(Q67), .Y77(Q77), .Y78(Q87), 
	.Y81(Q18), .Y82(Q28), .Y83(Q38), .Y84(Q48), .Y85(Q58), .Y86(Q68), .Y87(Q78), .Y88(Q88),
	.JPEG_bitstream(JPEG_bitstream), .data_ready(data_ready), .output_reg_count(y_orc),
	.end_of_block_output(end_of_block_output),
	 .end_of_block_empty(end_of_block_empty));	

	endmodule
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  JPEG Encoder Core - Verilog                                ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

/* This module converts the incoming Y data.
The incoming data is unsigned 8 bits, so the data is in the range of 0-255
Unlike a typical DCT, the data is not subtracted by 128 to center it around 0.
It is only required for the first row, and instead of subtracting 128 from each
pixel value, a total value can be subtracted at the end of the first row/column multiply,
involving the 8 pixel values and the 8 DCT matrix values.
For the other 7 rows of the DCT matrix, the values in each row add up to 0,
so it is not necessary to subtract 128 from each Y, Cb, and Cr pixel value.
Then the Discrete Cosine Transform is performed by multiplying the 8x8 pixel block values
by the 8x8 DCT matrix. */

`timescale 1ns / 100ps

module y_dct(clk, rst, enable, data_in,
Z11_final, Z12_final, Z13_final, Z14_final, Z15_final, Z16_final, Z17_final, Z18_final,
Z21_final, Z22_final, Z23_final, Z24_final, Z25_final, Z26_final, Z27_final, Z28_final,
Z31_final, Z32_final, Z33_final, Z34_final, Z35_final, Z36_final, Z37_final, Z38_final,
Z41_final, Z42_final, Z43_final, Z44_final, Z45_final, Z46_final, Z47_final, Z48_final,
Z51_final, Z52_final, Z53_final, Z54_final, Z55_final, Z56_final, Z57_final, Z58_final,
Z61_final, Z62_final, Z63_final, Z64_final, Z65_final, Z66_final, Z67_final, Z68_final,
Z71_final, Z72_final, Z73_final, Z74_final, Z75_final, Z76_final, Z77_final, Z78_final,
Z81_final, Z82_final, Z83_final, Z84_final, Z85_final, Z86_final, Z87_final, Z88_final, 
output_enable);
input		clk;
input		rst;
input		enable;
input	[7:0]	data_in;
output  [10:0]  Z11_final, Z12_final, Z13_final, Z14_final;
output  [10:0]  Z15_final, Z16_final, Z17_final, Z18_final;
output  [10:0]  Z21_final, Z22_final, Z23_final, Z24_final;
output  [10:0]  Z25_final, Z26_final, Z27_final, Z28_final;
output  [10:0]  Z31_final, Z32_final, Z33_final, Z34_final;
output  [10:0]  Z35_final, Z36_final, Z37_final, Z38_final;
output  [10:0]  Z41_final, Z42_final, Z43_final, Z44_final;
output  [10:0]  Z45_final, Z46_final, Z47_final, Z48_final;
output  [10:0]  Z51_final, Z52_final, Z53_final, Z54_final;
output  [10:0]  Z55_final, Z56_final, Z57_final, Z58_final;
output  [10:0]  Z61_final, Z62_final, Z63_final, Z64_final;
output  [10:0]  Z65_final, Z66_final, Z67_final, Z68_final;
output  [10:0]  Z71_final, Z72_final, Z73_final, Z74_final;
output  [10:0]  Z75_final, Z76_final, Z77_final, Z78_final;
output  [10:0]  Z81_final, Z82_final, Z83_final, Z84_final;
output  [10:0]  Z85_final, Z86_final, Z87_final, Z88_final;
output	output_enable;


integer T1, T21, T22, T23, T24, T25, T26, T27, T28, T31, T32, T33, T34, T52; 
integer Ti1, Ti21, Ti22, Ti23, Ti24, Ti25, Ti26, Ti27, Ti28, Ti31, Ti32, Ti33, Ti34, Ti52; 

reg [24:0] Y_temp_11;
reg [24:0] Y11, Y21, Y31, Y41, Y51, Y61, Y71, Y81, Y11_final;
reg [31:0] Y_temp_21, Y_temp_31, Y_temp_41, Y_temp_51;
reg [31:0] Y_temp_61, Y_temp_71, Y_temp_81;
reg [31:0] Z_temp_11, Z_temp_12, Z_temp_13, Z_temp_14;
reg [31:0] Z_temp_15, Z_temp_16, Z_temp_17, Z_temp_18;
reg [31:0] Z_temp_21, Z_temp_22, Z_temp_23, Z_temp_24;
reg [31:0] Z_temp_25, Z_temp_26, Z_temp_27, Z_temp_28;
reg [31:0] Z_temp_31, Z_temp_32, Z_temp_33, Z_temp_34;
reg [31:0] Z_temp_35, Z_temp_36, Z_temp_37, Z_temp_38;
reg [31:0] Z_temp_41, Z_temp_42, Z_temp_43, Z_temp_44;
reg [31:0] Z_temp_45, Z_temp_46, Z_temp_47, Z_temp_48;
reg [31:0] Z_temp_51, Z_temp_52, Z_temp_53, Z_temp_54;
reg [31:0] Z_temp_55, Z_temp_56, Z_temp_57, Z_temp_58;
reg [31:0] Z_temp_61, Z_temp_62, Z_temp_63, Z_temp_64;
reg [31:0] Z_temp_65, Z_temp_66, Z_temp_67, Z_temp_68;
reg [31:0] Z_temp_71, Z_temp_72, Z_temp_73, Z_temp_74;
reg [31:0] Z_temp_75, Z_temp_76, Z_temp_77, Z_temp_78;
reg [31:0] Z_temp_81, Z_temp_82, Z_temp_83, Z_temp_84;
reg [31:0] Z_temp_85, Z_temp_86, Z_temp_87, Z_temp_88;
reg [26:0] Z11, Z12, Z13, Z14, Z15, Z16, Z17, Z18;
reg [26:0] Z21, Z22, Z23, Z24, Z25, Z26, Z27, Z28;
reg [26:0] Z31, Z32, Z33, Z34, Z35, Z36, Z37, Z38;
reg [26:0] Z41, Z42, Z43, Z44, Z45, Z46, Z47, Z48;
reg [26:0] Z51, Z52, Z53, Z54, Z55, Z56, Z57, Z58;
reg [26:0] Z61, Z62, Z63, Z64, Z65, Z66, Z67, Z68;
reg [26:0] Z71, Z72, Z73, Z74, Z75, Z76, Z77, Z78;
reg [26:0] Z81, Z82, Z83, Z84, Z85, Z86, Z87, Z88;
reg [31:0]  Y11_final_2, Y21_final_2, Y11_final_3, Y11_final_4, Y31_final_2, Y41_final_2;
reg [31:0]  Y51_final_2, Y61_final_2, Y71_final_2, Y81_final_2;
reg [12:0]  Y11_final_1, Y21_final_1, Y31_final_1, Y41_final_1;
reg [12:0]  Y51_final_1, Y61_final_1, Y71_final_1, Y81_final_1;
reg [24:0] Y21_final, Y31_final, Y41_final, Y51_final;
reg [24:0] Y61_final, Y71_final, Y81_final;
reg [24:0] Y21_final_prev, Y21_final_diff;
reg [24:0] Y31_final_prev, Y31_final_diff;
reg [24:0] Y41_final_prev, Y41_final_diff;
reg [24:0] Y51_final_prev, Y51_final_diff;
reg [24:0] Y61_final_prev, Y61_final_diff;
reg [24:0] Y71_final_prev, Y71_final_diff;
reg [24:0] Y81_final_prev, Y81_final_diff;
reg [10:0] Z11_final, Z12_final, Z13_final, Z14_final;
reg [10:0] Z15_final, Z16_final, Z17_final, Z18_final;
reg [10:0] Z21_final, Z22_final, Z23_final, Z24_final;
reg [10:0] Z25_final, Z26_final, Z27_final, Z28_final;
reg [10:0] Z31_final, Z32_final, Z33_final, Z34_final;
reg [10:0] Z35_final, Z36_final, Z37_final, Z38_final;
reg [10:0] Z41_final, Z42_final, Z43_final, Z44_final;
reg [10:0] Z45_final, Z46_final, Z47_final, Z48_final;
reg [10:0] Z51_final, Z52_final, Z53_final, Z54_final;
reg [10:0] Z55_final, Z56_final, Z57_final, Z58_final;
reg [10:0] Z61_final, Z62_final, Z63_final, Z64_final;
reg [10:0] Z65_final, Z66_final, Z67_final, Z68_final;
reg [10:0] Z71_final, Z72_final, Z73_final, Z74_final;
reg [10:0] Z75_final, Z76_final, Z77_final, Z78_final;
reg [10:0] Z81_final, Z82_final, Z83_final, Z84_final;
reg [10:0] Z85_final, Z86_final, Z87_final, Z88_final;
reg [2:0] count;
reg	[2:0] count_of, count_of_copy;
reg	count_1, count_3, count_4, count_5, count_6, count_7, count_8, enable_1, output_enable;
reg count_9, count_10;
reg [7:0] data_1;
integer Y2_mul_input, Y3_mul_input, Y4_mul_input, Y5_mul_input;
integer Y6_mul_input, Y7_mul_input, Y8_mul_input;	
integer Ti2_mul_input, Ti3_mul_input, Ti4_mul_input, Ti5_mul_input;
integer Ti6_mul_input, Ti7_mul_input, Ti8_mul_input;

always @(posedge clk)		
begin // DCT matrix entries
	T1 = 5793; // .3536
	T21 = 8035; // .4904
	T22 = 6811; // .4157
	T23 = 4551; // .2778
	T24 = 1598; // .0975
	T25 = -1598; // -.0975
	T26 = -4551; // -.2778
	T27 = -6811; // -.4157
	T28 = -8035; // -.4904
	T31 = 7568; // .4619
	T32 = 3135; // .1913
	T33 = -3135; // -.1913
	T34 = -7568; // -.4619
	T52 = -5793; // -.3536
end 
  
always @(posedge clk)		
begin // The inverse DCT matrix entries
	Ti1 = 5793; // .3536
	Ti21 = 8035; // .4904
	Ti22 = 6811; // .4157
	Ti23 = 4551; // .2778
	Ti24 = 1598; // .0975
	Ti25 = -1598; // -.0975
	Ti26 = -4551; // -.2778
	Ti27 = -6811; // -.4157
	Ti28 = -8035; // -.4904
	Ti31 = 7568; // .4619
	Ti32 = 3135; // .1913
	Ti33 = -3135; // -.1913
	Ti34 = -7568; // -.4619
	Ti52 = -5793; // -.3536
end 

always @(posedge clk)
begin
	if (rst) begin
 		Z_temp_11 <= 0; Z_temp_12 <= 0; Z_temp_13 <= 0; Z_temp_14 <= 0;
		Z_temp_15 <= 0; Z_temp_16 <= 0; Z_temp_17 <= 0; Z_temp_18 <= 0;
		Z_temp_21 <= 0; Z_temp_22 <= 0; Z_temp_23 <= 0; Z_temp_24 <= 0;
		Z_temp_25 <= 0; Z_temp_26 <= 0; Z_temp_27 <= 0; Z_temp_28 <= 0;
		Z_temp_31 <= 0; Z_temp_32 <= 0; Z_temp_33 <= 0; Z_temp_34 <= 0;
		Z_temp_35 <= 0; Z_temp_36 <= 0; Z_temp_37 <= 0; Z_temp_38 <= 0;
		Z_temp_41 <= 0; Z_temp_42 <= 0; Z_temp_43 <= 0; Z_temp_44 <= 0;
		Z_temp_45 <= 0; Z_temp_46 <= 0; Z_temp_47 <= 0; Z_temp_48 <= 0;
		Z_temp_51 <= 0; Z_temp_52 <= 0; Z_temp_53 <= 0; Z_temp_54 <= 0;
		Z_temp_55 <= 0; Z_temp_56 <= 0; Z_temp_57 <= 0; Z_temp_58 <= 0;
		Z_temp_61 <= 0; Z_temp_62 <= 0; Z_temp_63 <= 0; Z_temp_64 <= 0;
		Z_temp_65 <= 0; Z_temp_66 <= 0; Z_temp_67 <= 0; Z_temp_68 <= 0;
		Z_temp_71 <= 0; Z_temp_72 <= 0; Z_temp_73 <= 0; Z_temp_74 <= 0;
		Z_temp_75 <= 0; Z_temp_76 <= 0; Z_temp_77 <= 0; Z_temp_78 <= 0;
		Z_temp_81 <= 0; Z_temp_82 <= 0; Z_temp_83 <= 0; Z_temp_84 <= 0;
		Z_temp_85 <= 0; Z_temp_86 <= 0; Z_temp_87 <= 0; Z_temp_88 <= 0;
		end
	else if (enable_1 & count_8) begin
		Z_temp_11 <= Y11_final_4 * Ti1; Z_temp_12 <= Y11_final_4 * Ti2_mul_input;
		Z_temp_13 <= Y11_final_4 * Ti3_mul_input; Z_temp_14 <= Y11_final_4 * Ti4_mul_input;
		Z_temp_15 <= Y11_final_4 * Ti5_mul_input; Z_temp_16 <= Y11_final_4 * Ti6_mul_input;
		Z_temp_17 <= Y11_final_4 * Ti7_mul_input; Z_temp_18 <= Y11_final_4 * Ti8_mul_input;
		Z_temp_21 <= Y21_final_2 * Ti1; Z_temp_22 <= Y21_final_2 * Ti2_mul_input;
		Z_temp_23 <= Y21_final_2 * Ti3_mul_input; Z_temp_24 <= Y21_final_2 * Ti4_mul_input;
		Z_temp_25 <= Y21_final_2 * Ti5_mul_input; Z_temp_26 <= Y21_final_2 * Ti6_mul_input;
		Z_temp_27 <= Y21_final_2 * Ti7_mul_input; Z_temp_28 <= Y21_final_2 * Ti8_mul_input;
		Z_temp_31 <= Y31_final_2 * Ti1; Z_temp_32 <= Y31_final_2 * Ti2_mul_input;
		Z_temp_33 <= Y31_final_2 * Ti3_mul_input; Z_temp_34 <= Y31_final_2 * Ti4_mul_input;
		Z_temp_35 <= Y31_final_2 * Ti5_mul_input; Z_temp_36 <= Y31_final_2 * Ti6_mul_input;
		Z_temp_37 <= Y31_final_2 * Ti7_mul_input; Z_temp_38 <= Y31_final_2 * Ti8_mul_input;
		Z_temp_41 <= Y41_final_2 * Ti1; Z_temp_42 <= Y41_final_2 * Ti2_mul_input;
		Z_temp_43 <= Y41_final_2 * Ti3_mul_input; Z_temp_44 <= Y41_final_2 * Ti4_mul_input;
		Z_temp_45 <= Y41_final_2 * Ti5_mul_input; Z_temp_46 <= Y41_final_2 * Ti6_mul_input;
		Z_temp_47 <= Y41_final_2 * Ti7_mul_input; Z_temp_48 <= Y41_final_2 * Ti8_mul_input;
		Z_temp_51 <= Y51_final_2 * Ti1; Z_temp_52 <= Y51_final_2 * Ti2_mul_input;
		Z_temp_53 <= Y51_final_2 * Ti3_mul_input; Z_temp_54 <= Y51_final_2 * Ti4_mul_input;
		Z_temp_55 <= Y51_final_2 * Ti5_mul_input; Z_temp_56 <= Y51_final_2 * Ti6_mul_input;
		Z_temp_57 <= Y51_final_2 * Ti7_mul_input; Z_temp_58 <= Y51_final_2 * Ti8_mul_input;
		Z_temp_61 <= Y61_final_2 * Ti1; Z_temp_62 <= Y61_final_2 * Ti2_mul_input;
		Z_temp_63 <= Y61_final_2 * Ti3_mul_input; Z_temp_64 <= Y61_final_2 * Ti4_mul_input;
		Z_temp_65 <= Y61_final_2 * Ti5_mul_input; Z_temp_66 <= Y61_final_2 * Ti6_mul_input;
		Z_temp_67 <= Y61_final_2 * Ti7_mul_input; Z_temp_68 <= Y61_final_2 * Ti8_mul_input;
		Z_temp_71 <= Y71_final_2 * Ti1; Z_temp_72 <= Y71_final_2 * Ti2_mul_input;
		Z_temp_73 <= Y71_final_2 * Ti3_mul_input; Z_temp_74 <= Y71_final_2 * Ti4_mul_input;
		Z_temp_75 <= Y71_final_2 * Ti5_mul_input; Z_temp_76 <= Y71_final_2 * Ti6_mul_input;
		Z_temp_77 <= Y71_final_2 * Ti7_mul_input; Z_temp_78 <= Y71_final_2 * Ti8_mul_input;
		Z_temp_81 <= Y81_final_2 * Ti1; Z_temp_82 <= Y81_final_2 * Ti2_mul_input;
		Z_temp_83 <= Y81_final_2 * Ti3_mul_input; Z_temp_84 <= Y81_final_2 * Ti4_mul_input;
		Z_temp_85 <= Y81_final_2 * Ti5_mul_input; Z_temp_86 <= Y81_final_2 * Ti6_mul_input;
		Z_temp_87 <= Y81_final_2 * Ti7_mul_input; Z_temp_88 <= Y81_final_2 * Ti8_mul_input;
		end
end

always @(posedge clk)
begin
	if (rst) begin
		Z11 <= 0; Z12 <= 0; Z13 <= 0; Z14 <= 0; Z15 <= 0; Z16 <= 0; Z17 <= 0; Z18 <= 0;
		Z21 <= 0; Z22 <= 0; Z23 <= 0; Z24 <= 0; Z25 <= 0; Z26 <= 0; Z27 <= 0; Z28 <= 0;
		Z31 <= 0; Z32 <= 0; Z33 <= 0; Z34 <= 0; Z35 <= 0; Z36 <= 0; Z37 <= 0; Z38 <= 0;
		Z41 <= 0; Z42 <= 0; Z43 <= 0; Z44 <= 0; Z45 <= 0; Z46 <= 0; Z47 <= 0; Z48 <= 0;
		Z51 <= 0; Z52 <= 0; Z53 <= 0; Z54 <= 0; Z55 <= 0; Z56 <= 0; Z57 <= 0; Z58 <= 0;
		Z61 <= 0; Z62 <= 0; Z63 <= 0; Z64 <= 0; Z65 <= 0; Z66 <= 0; Z67 <= 0; Z68 <= 0;
		Z71 <= 0; Z72 <= 0; Z73 <= 0; Z74 <= 0; Z75 <= 0; Z76 <= 0; Z77 <= 0; Z78 <= 0;
		Z81 <= 0; Z82 <= 0; Z83 <= 0; Z84 <= 0; Z85 <= 0; Z86 <= 0; Z87 <= 0; Z88 <= 0;
		end
	else if (count_8 & count_of == 1) begin
		Z11 <= 0; Z12 <= 0; Z13 <= 0; Z14 <= 0;
		Z15 <= 0; Z16 <= 0; Z17 <= 0; Z18 <= 0;
		Z21 <= 0; Z22 <= 0; Z23 <= 0; Z24 <= 0;
		Z25 <= 0; Z26 <= 0; Z27 <= 0; Z28 <= 0;
		Z31 <= 0; Z32 <= 0; Z33 <= 0; Z34 <= 0;
		Z35 <= 0; Z36 <= 0; Z37 <= 0; Z38 <= 0;
		Z41 <= 0; Z42 <= 0; Z43 <= 0; Z44 <= 0;
		Z45 <= 0; Z46 <= 0; Z47 <= 0; Z48 <= 0;
		Z51 <= 0; Z52 <= 0; Z53 <= 0; Z54 <= 0;
		Z55 <= 0; Z56 <= 0; Z57 <= 0; Z58 <= 0;
		Z61 <= 0; Z62 <= 0; Z63 <= 0; Z64 <= 0;
		Z65 <= 0; Z66 <= 0; Z67 <= 0; Z68 <= 0;
		Z71 <= 0; Z72 <= 0; Z73 <= 0; Z74 <= 0;
		Z75 <= 0; Z76 <= 0; Z77 <= 0; Z78 <= 0;
		Z81 <= 0; Z82 <= 0; Z83 <= 0; Z84 <= 0;
		Z85 <= 0; Z86 <= 0; Z87 <= 0; Z88 <= 0;
		end
	else if (enable & count_9) begin
		Z11 <= Z_temp_11 + Z11; Z12 <= Z_temp_12 + Z12; Z13 <= Z_temp_13 + Z13; Z14 <= Z_temp_14 + Z14;
		Z15 <= Z_temp_15 + Z15; Z16 <= Z_temp_16 + Z16; Z17 <= Z_temp_17 + Z17; Z18 <= Z_temp_18 + Z18;
		Z21 <= Z_temp_21 + Z21; Z22 <= Z_temp_22 + Z22; Z23 <= Z_temp_23 + Z23; Z24 <= Z_temp_24 + Z24;
		Z25 <= Z_temp_25 + Z25; Z26 <= Z_temp_26 + Z26; Z27 <= Z_temp_27 + Z27; Z28 <= Z_temp_28 + Z28;
		Z31 <= Z_temp_31 + Z31; Z32 <= Z_temp_32 + Z32; Z33 <= Z_temp_33 + Z33; Z34 <= Z_temp_34 + Z34;
		Z35 <= Z_temp_35 + Z35; Z36 <= Z_temp_36 + Z36; Z37 <= Z_temp_37 + Z37; Z38 <= Z_temp_38 + Z38;
		Z41 <= Z_temp_41 + Z41; Z42 <= Z_temp_42 + Z42; Z43 <= Z_temp_43 + Z43; Z44 <= Z_temp_44 + Z44;
		Z45 <= Z_temp_45 + Z45; Z46 <= Z_temp_46 + Z46; Z47 <= Z_temp_47 + Z47; Z48 <= Z_temp_48 + Z48;
		Z51 <= Z_temp_51 + Z51; Z52 <= Z_temp_52 + Z52; Z53 <= Z_temp_53 + Z53; Z54 <= Z_temp_54 + Z54;
		Z55 <= Z_temp_55 + Z55; Z56 <= Z_temp_56 + Z56; Z57 <= Z_temp_57 + Z57; Z58 <= Z_temp_58 + Z58;
		Z61 <= Z_temp_61 + Z61; Z62 <= Z_temp_62 + Z62; Z63 <= Z_temp_63 + Z63; Z64 <= Z_temp_64 + Z64;
		Z65 <= Z_temp_65 + Z65; Z66 <= Z_temp_66 + Z66; Z67 <= Z_temp_67 + Z67; Z68 <= Z_temp_68 + Z68;
		Z71 <= Z_temp_71 + Z71; Z72 <= Z_temp_72 + Z72; Z73 <= Z_temp_73 + Z73; Z74 <= Z_temp_74 + Z74;
		Z75 <= Z_temp_75 + Z75; Z76 <= Z_temp_76 + Z76; Z77 <= Z_temp_77 + Z77; Z78 <= Z_temp_78 + Z78;
		Z81 <= Z_temp_81 + Z81; Z82 <= Z_temp_82 + Z82; Z83 <= Z_temp_83 + Z83; Z84 <= Z_temp_84 + Z84;
		Z85 <= Z_temp_85 + Z85; Z86 <= Z_temp_86 + Z86; Z87 <= Z_temp_87 + Z87; Z88 <= Z_temp_88 + Z88;
		end	
end

always @(posedge clk)
begin
	if (rst) begin
		Z11_final <= 0; Z12_final <= 0; Z13_final <= 0; Z14_final <= 0;
		Z15_final <= 0; Z16_final <= 0; Z17_final <= 0; Z18_final <= 0;
		Z21_final <= 0; Z22_final <= 0; Z23_final <= 0; Z24_final <= 0;
		Z25_final <= 0; Z26_final <= 0; Z27_final <= 0; Z28_final <= 0;
		Z31_final <= 0; Z32_final <= 0; Z33_final <= 0; Z34_final <= 0;
		Z35_final <= 0; Z36_final <= 0; Z37_final <= 0; Z38_final <= 0;
		Z41_final <= 0; Z42_final <= 0; Z43_final <= 0; Z44_final <= 0;
		Z45_final <= 0; Z46_final <= 0; Z47_final <= 0; Z48_final <= 0;
		Z51_final <= 0; Z52_final <= 0; Z53_final <= 0; Z54_final <= 0;
		Z55_final <= 0; Z56_final <= 0; Z57_final <= 0; Z58_final <= 0;
		Z61_final <= 0; Z62_final <= 0; Z63_final <= 0; Z64_final <= 0;
		Z65_final <= 0; Z66_final <= 0; Z67_final <= 0; Z68_final <= 0;
		Z71_final <= 0; Z72_final <= 0; Z73_final <= 0; Z74_final <= 0;
		Z75_final <= 0; Z76_final <= 0; Z77_final <= 0; Z78_final <= 0;
		Z81_final <= 0; Z82_final <= 0; Z83_final <= 0; Z84_final <= 0;
		Z85_final <= 0; Z86_final <= 0; Z87_final <= 0; Z88_final <= 0;
		end
	else if (count_10 & count_of == 0) begin
		Z11_final <= Z11[15] ? Z11[26:16] + 1 : Z11[26:16];
		Z12_final <= Z12[15] ? Z12[26:16] + 1 : Z12[26:16];
		Z13_final <= Z13[15] ? Z13[26:16] + 1 : Z13[26:16];
		Z14_final <= Z14[15] ? Z14[26:16] + 1 : Z14[26:16];
		Z15_final <= Z15[15] ? Z15[26:16] + 1 : Z15[26:16];
		Z16_final <= Z16[15] ? Z16[26:16] + 1 : Z16[26:16];
		Z17_final <= Z17[15] ? Z17[26:16] + 1 : Z17[26:16];
		Z18_final <= Z18[15] ? Z18[26:16] + 1 : Z18[26:16]; 
		Z21_final <= Z21[15] ? Z21[26:16] + 1 : Z21[26:16];
		Z22_final <= Z22[15] ? Z22[26:16] + 1 : Z22[26:16];
		Z23_final <= Z23[15] ? Z23[26:16] + 1 : Z23[26:16];
		Z24_final <= Z24[15] ? Z24[26:16] + 1 : Z24[26:16];
		Z25_final <= Z25[15] ? Z25[26:16] + 1 : Z25[26:16];
		Z26_final <= Z26[15] ? Z26[26:16] + 1 : Z26[26:16];
		Z27_final <= Z27[15] ? Z27[26:16] + 1 : Z27[26:16];
		Z28_final <= Z28[15] ? Z28[26:16] + 1 : Z28[26:16]; 
		Z31_final <= Z31[15] ? Z31[26:16] + 1 : Z31[26:16];
		Z32_final <= Z32[15] ? Z32[26:16] + 1 : Z32[26:16];
		Z33_final <= Z33[15] ? Z33[26:16] + 1 : Z33[26:16];
		Z34_final <= Z34[15] ? Z34[26:16] + 1 : Z34[26:16];
		Z35_final <= Z35[15] ? Z35[26:16] + 1 : Z35[26:16];
		Z36_final <= Z36[15] ? Z36[26:16] + 1 : Z36[26:16];
		Z37_final <= Z37[15] ? Z37[26:16] + 1 : Z37[26:16];
		Z38_final <= Z38[15] ? Z38[26:16] + 1 : Z38[26:16]; 
		Z41_final <= Z41[15] ? Z41[26:16] + 1 : Z41[26:16];
		Z42_final <= Z42[15] ? Z42[26:16] + 1 : Z42[26:16];
		Z43_final <= Z43[15] ? Z43[26:16] + 1 : Z43[26:16];
		Z44_final <= Z44[15] ? Z44[26:16] + 1 : Z44[26:16];
		Z45_final <= Z45[15] ? Z45[26:16] + 1 : Z45[26:16];
		Z46_final <= Z46[15] ? Z46[26:16] + 1 : Z46[26:16];
		Z47_final <= Z47[15] ? Z47[26:16] + 1 : Z47[26:16];
		Z48_final <= Z48[15] ? Z48[26:16] + 1 : Z48[26:16]; 
		Z51_final <= Z51[15] ? Z51[26:16] + 1 : Z51[26:16];
		Z52_final <= Z52[15] ? Z52[26:16] + 1 : Z52[26:16];
		Z53_final <= Z53[15] ? Z53[26:16] + 1 : Z53[26:16];
		Z54_final <= Z54[15] ? Z54[26:16] + 1 : Z54[26:16];
		Z55_final <= Z55[15] ? Z55[26:16] + 1 : Z55[26:16];
		Z56_final <= Z56[15] ? Z56[26:16] + 1 : Z56[26:16];
		Z57_final <= Z57[15] ? Z57[26:16] + 1 : Z57[26:16];
		Z58_final <= Z58[15] ? Z58[26:16] + 1 : Z58[26:16]; 
		Z61_final <= Z61[15] ? Z61[26:16] + 1 : Z61[26:16];
		Z62_final <= Z62[15] ? Z62[26:16] + 1 : Z62[26:16];
		Z63_final <= Z63[15] ? Z63[26:16] + 1 : Z63[26:16];
		Z64_final <= Z64[15] ? Z64[26:16] + 1 : Z64[26:16];
		Z65_final <= Z65[15] ? Z65[26:16] + 1 : Z65[26:16];
		Z66_final <= Z66[15] ? Z66[26:16] + 1 : Z66[26:16];
		Z67_final <= Z67[15] ? Z67[26:16] + 1 : Z67[26:16];
		Z68_final <= Z68[15] ? Z68[26:16] + 1 : Z68[26:16]; 
		Z71_final <= Z71[15] ? Z71[26:16] + 1 : Z71[26:16];
		Z72_final <= Z72[15] ? Z72[26:16] + 1 : Z72[26:16];
		Z73_final <= Z73[15] ? Z73[26:16] + 1 : Z73[26:16];
		Z74_final <= Z74[15] ? Z74[26:16] + 1 : Z74[26:16];
		Z75_final <= Z75[15] ? Z75[26:16] + 1 : Z75[26:16];
		Z76_final <= Z76[15] ? Z76[26:16] + 1 : Z76[26:16];
		Z77_final <= Z77[15] ? Z77[26:16] + 1 : Z77[26:16];
		Z78_final <= Z78[15] ? Z78[26:16] + 1 : Z78[26:16]; 
		Z81_final <= Z81[15] ? Z81[26:16] + 1 : Z81[26:16];
		Z82_final <= Z82[15] ? Z82[26:16] + 1 : Z82[26:16];
		Z83_final <= Z83[15] ? Z83[26:16] + 1 : Z83[26:16];
		Z84_final <= Z84[15] ? Z84[26:16] + 1 : Z84[26:16];
		Z85_final <= Z85[15] ? Z85[26:16] + 1 : Z85[26:16];
		Z86_final <= Z86[15] ? Z86[26:16] + 1 : Z86[26:16];
		Z87_final <= Z87[15] ? Z87[26:16] + 1 : Z87[26:16];
		Z88_final <= Z88[15] ? Z88[26:16] + 1 : Z88[26:16]; 
		end
end

// output_enable signals the next block, the quantizer, that the input data is ready
always @(posedge clk)
begin
	if (rst) 
 		output_enable <= 0;
	else if (!enable_1)
		output_enable <= 0;
	else if (count_10 == 0 | count_of)
		output_enable <= 0;
	else if (count_10 & count_of == 0)
		output_enable <= 1;
end
always @(posedge clk)
begin
	if (rst)
		Y_temp_11 <= 0;
	else if (enable)
		Y_temp_11 <= data_in * T1; 
end  

always @(posedge clk)
begin
	if (rst)
		Y11 <= 0;
	else if (count == 1 & enable == 1)
		Y11 <= Y_temp_11;
	else if (enable)
		Y11 <= Y_temp_11 + Y11;
end

always @(posedge clk)
begin
	if (rst) begin
		Y_temp_21 <= 0;
		Y_temp_31 <= 0;
		Y_temp_41 <= 0;
		Y_temp_51 <= 0;
		Y_temp_61 <= 0;
		Y_temp_71 <= 0;
		Y_temp_81 <= 0;
		end
	else if (!enable_1) begin
		Y_temp_21 <= 0;
		Y_temp_31 <= 0;
		Y_temp_41 <= 0;
		Y_temp_51 <= 0;
		Y_temp_61 <= 0;
		Y_temp_71 <= 0;
		Y_temp_81 <= 0;
		end
	else if (enable_1) begin
		Y_temp_21 <= data_1 * Y2_mul_input; 
		Y_temp_31 <= data_1 * Y3_mul_input; 
		Y_temp_41 <= data_1 * Y4_mul_input; 
		Y_temp_51 <= data_1 * Y5_mul_input; 
		Y_temp_61 <= data_1 * Y6_mul_input; 
		Y_temp_71 <= data_1 * Y7_mul_input; 
		Y_temp_81 <= data_1 * Y8_mul_input; 
		end
end

always @(posedge clk)
begin
	if (rst) begin
		Y21 <= 0;
		Y31 <= 0;
		Y41 <= 0;
		Y51 <= 0;
		Y61 <= 0;
		Y71 <= 0;
		Y81 <= 0;
		end
	else if (!enable_1) begin
		Y21 <= 0;
		Y31 <= 0;
		Y41 <= 0;
		Y51 <= 0;
		Y61 <= 0;
		Y71 <= 0;
		Y81 <= 0;
		end
	else if (enable_1) begin
		Y21 <= Y_temp_21 + Y21;
		Y31 <= Y_temp_31 + Y31;
		Y41 <= Y_temp_41 + Y41;
		Y51 <= Y_temp_51 + Y51;
		Y61 <= Y_temp_61 + Y61;
		Y71 <= Y_temp_71 + Y71;
		Y81 <= Y_temp_81 + Y81;
		end
end 

always @(posedge clk)
begin
	if (rst) begin
 		count <= 0; count_3 <= 0; count_4 <= 0; count_5 <= 0;
 		count_6 <= 0; count_7 <= 0; count_8 <= 0; count_9 <= 0;
 		count_10 <= 0;
		end
	else if (!enable) begin
		count <= 0; count_3 <= 0; count_4 <= 0; count_5 <= 0;
 		count_6 <= 0; count_7 <= 0; count_8 <= 0; count_9 <= 0;
 		count_10 <= 0;
		end
	else if (enable) begin
		count <= count + 1; count_3 <= count_1; count_4 <= count_3;
		count_5 <= count_4; count_6 <= count_5; count_7 <= count_6;
		count_8 <= count_7; count_9 <= count_8; count_10 <= count_9;
		end
end

always @(posedge clk)
begin
	if (rst) begin
		count_1 <= 0;
		end
	else if (count != 7 | !enable) begin
		count_1 <= 0;
		end
	else if (count == 7) begin
		count_1 <= 1;
		end
end

always @(posedge clk)
begin
	if (rst) begin
 		count_of <= 0;
 		count_of_copy <= 0;
 		end
	else if (!enable) begin
		count_of <= 0;
		count_of_copy <= 0;
		end
	else if (count_1 == 1) begin
		count_of <= count_of + 1;
		count_of_copy <= count_of_copy + 1;
		end
end

always @(posedge clk)
begin
	if (rst) begin
 		Y11_final <= 0;
		end
	else if (count_3 & enable_1) begin
		Y11_final <= Y11 - 25'd5932032;  
		/* The Y values weren't centered on 0 before doing the DCT	
		 128 needs to be subtracted from each Y value before, or in this
		 case, 362 is subtracted from the total, because this is the 
		 total obtained by subtracting 128 from each element 
		 and then multiplying by the weight
		 assigned by the DCT matrix : 128*8*5793 = 5932032
		 This is only needed for the first row, the values in the rest of
		 the rows add up to 0 */
		end
end


always @(posedge clk)
begin
	if (rst) begin
 		Y21_final <= 0; Y21_final_prev <= 0;
 		Y31_final <= 0; Y31_final_prev <= 0;
 		Y41_final <= 0; Y41_final_prev <= 0;
 		Y51_final <= 0; Y51_final_prev <= 0;
 		Y61_final <= 0; Y61_final_prev <= 0;
 		Y71_final <= 0; Y71_final_prev <= 0;
 		Y81_final <= 0; Y81_final_prev <= 0;
		end
	else if (!enable_1) begin
		Y21_final <= 0; Y21_final_prev <= 0;
 		Y31_final <= 0; Y31_final_prev <= 0;
 		Y41_final <= 0; Y41_final_prev <= 0;
 		Y51_final <= 0; Y51_final_prev <= 0;
 		Y61_final <= 0; Y61_final_prev <= 0;
 		Y71_final <= 0; Y71_final_prev <= 0;
 		Y81_final <= 0; Y81_final_prev <= 0;
		end
	else if (count_4 & enable_1) begin
		Y21_final <= Y21; Y21_final_prev <= Y21_final;
		Y31_final <= Y31; Y31_final_prev <= Y31_final;
		Y41_final <= Y41; Y41_final_prev <= Y41_final;
		Y51_final <= Y51; Y51_final_prev <= Y51_final;
		Y61_final <= Y61; Y61_final_prev <= Y61_final;
		Y71_final <= Y71; Y71_final_prev <= Y71_final;
		Y81_final <= Y81; Y81_final_prev <= Y81_final;
		end
end

always @(posedge clk)
begin
	if (rst) begin
 		Y21_final_diff <= 0; Y31_final_diff <= 0;
 		Y41_final_diff <= 0; Y51_final_diff <= 0;
 		Y61_final_diff <= 0; Y71_final_diff <= 0;
 		Y81_final_diff <= 0;	
		end
	else if (count_5 & enable_1) begin 
		Y21_final_diff <= Y21_final - Y21_final_prev;	
		Y31_final_diff <= Y31_final - Y31_final_prev;	
		Y41_final_diff <= Y41_final - Y41_final_prev;	
		Y51_final_diff <= Y51_final - Y51_final_prev;	
		Y61_final_diff <= Y61_final - Y61_final_prev;	
		Y71_final_diff <= Y71_final - Y71_final_prev;	
		Y81_final_diff <= Y81_final - Y81_final_prev;		
		end
end
always @(posedge clk)
begin
	case (count)
	3'b000:		Y2_mul_input <= T21;
	3'b001:		Y2_mul_input <= T22;
	3'b010:		Y2_mul_input <= T23;
	3'b011:		Y2_mul_input <= T24;
	3'b100:		Y2_mul_input <= T25;
	3'b101:		Y2_mul_input <= T26;
	3'b110:		Y2_mul_input <= T27;
	3'b111:		Y2_mul_input <= T28;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y3_mul_input <= T31;
	3'b001:		Y3_mul_input <= T32;
	3'b010:		Y3_mul_input <= T33;
	3'b011:		Y3_mul_input <= T34;
	3'b100:		Y3_mul_input <= T34;
	3'b101:		Y3_mul_input <= T33;
	3'b110:		Y3_mul_input <= T32;
	3'b111:		Y3_mul_input <= T31;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y4_mul_input <= T22;
	3'b001:		Y4_mul_input <= T25;
	3'b010:		Y4_mul_input <= T28;
	3'b011:		Y4_mul_input <= T26;
	3'b100:		Y4_mul_input <= T23;
	3'b101:		Y4_mul_input <= T21;
	3'b110:		Y4_mul_input <= T24;
	3'b111:		Y4_mul_input <= T27;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y5_mul_input <= T1;
	3'b001:		Y5_mul_input <= T52;
	3'b010:		Y5_mul_input <= T52;
	3'b011:		Y5_mul_input <= T1;
	3'b100:		Y5_mul_input <= T1;
	3'b101:		Y5_mul_input <= T52;
	3'b110:		Y5_mul_input <= T52;
	3'b111:		Y5_mul_input <= T1;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y6_mul_input <= T23;
	3'b001:		Y6_mul_input <= T28;
	3'b010:		Y6_mul_input <= T24;
	3'b011:		Y6_mul_input <= T22;
	3'b100:		Y6_mul_input <= T27;
	3'b101:		Y6_mul_input <= T25;
	3'b110:		Y6_mul_input <= T21;
	3'b111:		Y6_mul_input <= T26;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y7_mul_input <= T32;
	3'b001:		Y7_mul_input <= T34;
	3'b010:		Y7_mul_input <= T31;
	3'b011:		Y7_mul_input <= T33;
	3'b100:		Y7_mul_input <= T33;
	3'b101:		Y7_mul_input <= T31;
	3'b110:		Y7_mul_input <= T34;
	3'b111:		Y7_mul_input <= T32;
	endcase
end

always @(posedge clk)
begin
	case (count)
	3'b000:		Y8_mul_input <= T24;
	3'b001:		Y8_mul_input <= T26;
	3'b010:		Y8_mul_input <= T22;
	3'b011:		Y8_mul_input <= T28;
	3'b100:		Y8_mul_input <= T21;
	3'b101:		Y8_mul_input <= T27;
	3'b110:		Y8_mul_input <= T23;
	3'b111:		Y8_mul_input <= T25;
	endcase
end

// Inverse DCT matrix entries
always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti2_mul_input <= Ti28;
	3'b001:		Ti2_mul_input <= Ti21;
	3'b010:		Ti2_mul_input <= Ti22;
	3'b011:		Ti2_mul_input <= Ti23;
	3'b100:		Ti2_mul_input <= Ti24;
	3'b101:		Ti2_mul_input <= Ti25;
	3'b110:		Ti2_mul_input <= Ti26;
	3'b111:		Ti2_mul_input <= Ti27;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti3_mul_input <= Ti31;
	3'b001:		Ti3_mul_input <= Ti31;
	3'b010:		Ti3_mul_input <= Ti32;
	3'b011:		Ti3_mul_input <= Ti33;
	3'b100:		Ti3_mul_input <= Ti34;
	3'b101:		Ti3_mul_input <= Ti34;
	3'b110:		Ti3_mul_input <= Ti33;
	3'b111:		Ti3_mul_input <= Ti32;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti4_mul_input <= Ti27;
	3'b001:		Ti4_mul_input <= Ti22;
	3'b010:		Ti4_mul_input <= Ti25;
	3'b011:		Ti4_mul_input <= Ti28;
	3'b100:		Ti4_mul_input <= Ti26;
	3'b101:		Ti4_mul_input <= Ti23;
	3'b110:		Ti4_mul_input <= Ti21;
	3'b111:		Ti4_mul_input <= Ti24;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti5_mul_input <= Ti1;
	3'b001:		Ti5_mul_input <= Ti1;
	3'b010:		Ti5_mul_input <= Ti52;
	3'b011:		Ti5_mul_input <= Ti52;
	3'b100:		Ti5_mul_input <= Ti1;
	3'b101:		Ti5_mul_input <= Ti1;
	3'b110:		Ti5_mul_input <= Ti52;
	3'b111:		Ti5_mul_input <= Ti52;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti6_mul_input <= Ti26;
	3'b001:		Ti6_mul_input <= Ti23;
	3'b010:		Ti6_mul_input <= Ti28;
	3'b011:		Ti6_mul_input <= Ti24;
	3'b100:		Ti6_mul_input <= Ti22;
	3'b101:		Ti6_mul_input <= Ti27;
	3'b110:		Ti6_mul_input <= Ti25;
	3'b111:		Ti6_mul_input <= Ti21;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti7_mul_input <= Ti32;
	3'b001:		Ti7_mul_input <= Ti32;
	3'b010:		Ti7_mul_input <= Ti34;
	3'b011:		Ti7_mul_input <= Ti31;
	3'b100:		Ti7_mul_input <= Ti33;
	3'b101:		Ti7_mul_input <= Ti33;
	3'b110:		Ti7_mul_input <= Ti31;
	3'b111:		Ti7_mul_input <= Ti34;
	endcase
end

always @(posedge clk)
begin
	case (count_of_copy)
	3'b000:		Ti8_mul_input <= Ti25;
	3'b001:		Ti8_mul_input <= Ti24;
	3'b010:		Ti8_mul_input <= Ti26;
	3'b011:		Ti8_mul_input <= Ti22;
	3'b100:		Ti8_mul_input <= Ti28;
	3'b101:		Ti8_mul_input <= Ti21;
	3'b110:		Ti8_mul_input <= Ti27;
	3'b111:		Ti8_mul_input <= Ti23;
	endcase
end

// Rounding stage
always @(posedge clk)
begin
	if (rst) begin
 		data_1 <= 0;
 		Y11_final_1 <= 0; Y21_final_1 <= 0; Y31_final_1 <= 0; Y41_final_1 <= 0;
		Y51_final_1 <= 0; Y61_final_1 <= 0; Y71_final_1 <= 0; Y81_final_1 <= 0;
		Y11_final_2 <= 0; Y21_final_2 <= 0; Y31_final_2 <= 0; Y41_final_2 <= 0;
		Y51_final_2 <= 0; Y61_final_2 <= 0; Y71_final_2 <= 0; Y81_final_2 <= 0;
		Y11_final_3 <= 0; Y11_final_4 <= 0;
		end
	else if (enable) begin
		data_1 <= data_in;  
		Y11_final_1 <= Y11_final[11] ? Y11_final[24:12] + 1 : Y11_final[24:12];
		Y11_final_2[31:13] <= Y11_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y11_final_2[12:0] <= Y11_final_1;
		// Need to sign extend Y11_final_1 and the other registers to store a negative 
		// number as a twos complement number.  If you don't sign extend, then a negative number
		// will be stored incorrectly as a positive number.  For example, -215 would be stored
		// as 1833 without sign extending
		Y11_final_3 <= Y11_final_2;
		Y11_final_4 <= Y11_final_3;
		Y21_final_1 <= Y21_final_diff[11] ? Y21_final_diff[24:12] + 1 : Y21_final_diff[24:12];
		Y21_final_2[31:13] <= Y21_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y21_final_2[12:0] <= Y21_final_1;
		Y31_final_1 <= Y31_final_diff[11] ? Y31_final_diff[24:12] + 1 : Y31_final_diff[24:12];
		Y31_final_2[31:13] <= Y31_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y31_final_2[12:0] <= Y31_final_1;
		Y41_final_1 <= Y41_final_diff[11] ? Y41_final_diff[24:12] + 1 : Y41_final_diff[24:12];
		Y41_final_2[31:13] <= Y41_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y41_final_2[12:0] <= Y41_final_1;
		Y51_final_1 <= Y51_final_diff[11] ? Y51_final_diff[24:12] + 1 : Y51_final_diff[24:12];
		Y51_final_2[31:13] <= Y51_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y51_final_2[12:0] <= Y51_final_1;
		Y61_final_1 <= Y61_final_diff[11] ? Y61_final_diff[24:12] + 1 : Y61_final_diff[24:12];
		Y61_final_2[31:13] <= Y61_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y61_final_2[12:0] <= Y61_final_1;
		Y71_final_1 <= Y71_final_diff[11] ? Y71_final_diff[24:12] + 1 : Y71_final_diff[24:12];
		Y71_final_2[31:13] <= Y71_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y71_final_2[12:0] <= Y71_final_1;
		Y81_final_1 <= Y81_final_diff[11] ? Y81_final_diff[24:12] + 1 : Y81_final_diff[24:12];
		Y81_final_2[31:13] <= Y81_final_1[12] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Y81_final_2[12:0] <= Y81_final_1;
		// The bit in place 11 is the fraction part, for rounding purposes
		// if it is 1, then you need to add 1 to the bits in 24-12, 
		// if bit 11 is 0, then the bits in 24-12 won't change
		end
end

always @(posedge clk)
begin
	if (rst) begin
 		enable_1 <= 0; 
		end
	else begin
		enable_1 <= enable;
		end
end

endmodule
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  JPEG Encoder Core - Verilog                                ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

/* This module is the Huffman encoder.  It takes in the quantized outputs
from the quantizer, and creates the Huffman codes from these value.  The 
output from this module is the jpeg code of the actual pixel data.  The jpeg
file headers will need to be generated separately.  The Huffman codes are constant, 
and they can be changed by changing the parameters in this module. */

`timescale 1ns / 100ps
		
module y_huff(clk, rst, enable,
Y11, Y12, Y13, Y14, Y15, Y16, Y17, Y18, Y21, Y22, Y23, Y24, Y25, Y26, Y27, Y28,
Y31, Y32, Y33, Y34, Y35, Y36, Y37, Y38, Y41, Y42, Y43, Y44, Y45, Y46, Y47, Y48,
Y51, Y52, Y53, Y54, Y55, Y56, Y57, Y58, Y61, Y62, Y63, Y64, Y65, Y66, Y67, Y68,
Y71, Y72, Y73, Y74, Y75, Y76, Y77, Y78, Y81, Y82, Y83, Y84, Y85, Y86, Y87, Y88,
JPEG_bitstream, data_ready, output_reg_count, end_of_block_output,
 end_of_block_empty);
input		clk;
input		rst;
input		enable;
input  [10:0]  Y11, Y12, Y13, Y14, Y15, Y16, Y17, Y18, Y21, Y22, Y23, Y24;
input  [10:0]  Y25, Y26, Y27, Y28, Y31, Y32, Y33, Y34, Y35, Y36, Y37, Y38;
input  [10:0]  Y41, Y42, Y43, Y44, Y45, Y46, Y47, Y48, Y51, Y52, Y53, Y54;
input  [10:0]  Y55, Y56, Y57, Y58, Y61, Y62, Y63, Y64, Y65, Y66, Y67, Y68;
input  [10:0]  Y71, Y72, Y73, Y74, Y75, Y76, Y77, Y78, Y81, Y82, Y83, Y84;
input  [10:0]  Y85, Y86, Y87, Y88;
output	[31:0]	JPEG_bitstream;
output	data_ready;
output	[4:0] output_reg_count;
output	end_of_block_output;
output		end_of_block_empty;

reg		[7:0] block_counter;
reg		[11:0]  Y11_amp, Y11_1_pos, Y11_1_neg, Y11_diff;
reg		[11:0]  Y11_previous, Y11_1;
reg		[10:0]  Y12_amp, Y12_pos, Y12_neg;
reg		[10:0]  Y21_pos, Y21_neg, Y31_pos, Y31_neg, Y22_pos, Y22_neg;
reg		[10:0]  Y13_pos, Y13_neg, Y14_pos, Y14_neg, Y15_pos, Y15_neg;
reg		[10:0]  Y16_pos, Y16_neg, Y17_pos, Y17_neg, Y18_pos, Y18_neg;
reg		[10:0]  Y23_pos, Y23_neg, Y24_pos, Y24_neg, Y25_pos, Y25_neg;
reg		[10:0]  Y26_pos, Y26_neg, Y27_pos, Y27_neg, Y28_pos, Y28_neg;
reg		[10:0]  Y32_pos, Y32_neg;
reg		[10:0]  Y33_pos, Y33_neg, Y34_pos, Y34_neg, Y35_pos, Y35_neg;
reg		[10:0]  Y36_pos, Y36_neg, Y37_pos, Y37_neg, Y38_pos, Y38_neg;
reg		[10:0]  Y41_pos, Y41_neg, Y42_pos, Y42_neg;
reg		[10:0]  Y43_pos, Y43_neg, Y44_pos, Y44_neg, Y45_pos, Y45_neg;
reg		[10:0]  Y46_pos, Y46_neg, Y47_pos, Y47_neg, Y48_pos, Y48_neg;
reg		[10:0]  Y51_pos, Y51_neg, Y52_pos, Y52_neg;
reg		[10:0]  Y53_pos, Y53_neg, Y54_pos, Y54_neg, Y55_pos, Y55_neg;
reg		[10:0]  Y56_pos, Y56_neg, Y57_pos, Y57_neg, Y58_pos, Y58_neg;
reg		[10:0]  Y61_pos, Y61_neg, Y62_pos, Y62_neg;
reg		[10:0]  Y63_pos, Y63_neg, Y64_pos, Y64_neg, Y65_pos, Y65_neg;
reg		[10:0]  Y66_pos, Y66_neg, Y67_pos, Y67_neg, Y68_pos, Y68_neg;
reg		[10:0]  Y71_pos, Y71_neg, Y72_pos, Y72_neg;
reg		[10:0]  Y73_pos, Y73_neg, Y74_pos, Y74_neg, Y75_pos, Y75_neg;
reg		[10:0]  Y76_pos, Y76_neg, Y77_pos, Y77_neg, Y78_pos, Y78_neg;
reg		[10:0]  Y81_pos, Y81_neg, Y82_pos, Y82_neg;
reg		[10:0]  Y83_pos, Y83_neg, Y84_pos, Y84_neg, Y85_pos, Y85_neg;
reg		[10:0]  Y86_pos, Y86_neg, Y87_pos, Y87_neg, Y88_pos, Y88_neg;
reg		[3:0]	Y11_bits_pos, Y11_bits_neg, Y11_bits, Y11_bits_1;
reg		[3:0]	Y12_bits_pos, Y12_bits_neg, Y12_bits, Y12_bits_1; 
reg		[3:0]	Y12_bits_2, Y12_bits_3;
reg		Y11_msb, Y12_msb, Y12_msb_1, data_ready;
reg		enable_1, enable_2, enable_3, enable_4, enable_5, enable_6;
reg		enable_7, enable_8, enable_9, enable_10, enable_11, enable_12;
reg		enable_13, enable_module, enable_latch_7, enable_latch_8;
reg		Y12_et_zero, rollover, rollover_1, rollover_2, rollover_3;
reg		rollover_4, rollover_5, rollover_6, rollover_7;
reg		Y21_et_zero, Y21_msb, Y31_et_zero, Y31_msb;
reg		Y22_et_zero, Y22_msb, Y13_et_zero, Y13_msb;
reg		Y14_et_zero, Y14_msb, Y15_et_zero, Y15_msb;
reg		Y16_et_zero, Y16_msb, Y17_et_zero, Y17_msb;
reg		Y18_et_zero, Y18_msb;
reg		Y23_et_zero, Y23_msb, Y24_et_zero, Y24_msb;
reg		Y25_et_zero, Y25_msb, Y26_et_zero, Y26_msb;
reg		Y27_et_zero, Y27_msb, Y28_et_zero, Y28_msb;
reg		Y32_et_zero, Y32_msb, Y33_et_zero, Y33_msb;
reg		Y34_et_zero, Y34_msb, Y35_et_zero, Y35_msb;
reg		Y36_et_zero, Y36_msb, Y37_et_zero, Y37_msb;
reg		Y38_et_zero, Y38_msb;
reg		Y41_et_zero, Y41_msb, Y42_et_zero, Y42_msb;
reg		Y43_et_zero, Y43_msb, Y44_et_zero, Y44_msb;
reg		Y45_et_zero, Y45_msb, Y46_et_zero, Y46_msb;
reg		Y47_et_zero, Y47_msb, Y48_et_zero, Y48_msb;
reg		Y51_et_zero, Y51_msb, Y52_et_zero, Y52_msb;
reg		Y53_et_zero, Y53_msb, Y54_et_zero, Y54_msb;
reg		Y55_et_zero, Y55_msb, Y56_et_zero, Y56_msb;
reg		Y57_et_zero, Y57_msb, Y58_et_zero, Y58_msb;
reg		Y61_et_zero, Y61_msb, Y62_et_zero, Y62_msb;
reg		Y63_et_zero, Y63_msb, Y64_et_zero, Y64_msb;
reg		Y65_et_zero, Y65_msb, Y66_et_zero, Y66_msb;
reg		Y67_et_zero, Y67_msb, Y68_et_zero, Y68_msb;
reg		Y71_et_zero, Y71_msb, Y72_et_zero, Y72_msb;
reg		Y73_et_zero, Y73_msb, Y74_et_zero, Y74_msb;
reg		Y75_et_zero, Y75_msb, Y76_et_zero, Y76_msb;
reg		Y77_et_zero, Y77_msb, Y78_et_zero, Y78_msb;
reg		Y81_et_zero, Y81_msb, Y82_et_zero, Y82_msb;
reg		Y83_et_zero, Y83_msb, Y84_et_zero, Y84_msb;
reg		Y85_et_zero, Y85_msb, Y86_et_zero, Y86_msb;
reg		Y87_et_zero, Y87_msb, Y88_et_zero, Y88_msb;
reg 	Y12_et_zero_1, Y12_et_zero_2, Y12_et_zero_3, Y12_et_zero_4, Y12_et_zero_5;
reg		[10:0] Y_DC [11:0];
reg 	[3:0] Y_DC_code_length [11:0];
reg		[15:0] Y_AC [161:0];
reg 	[4:0] Y_AC_code_length [161:0];
reg 	[7:0] Y_AC_run_code [250:0];
reg		[10:0] Y11_Huff, Y11_Huff_1, Y11_Huff_2;
reg		[15:0] Y12_Huff, Y12_Huff_1, Y12_Huff_2;
reg		[3:0] Y11_Huff_count, Y11_Huff_shift, Y11_Huff_shift_1, Y11_amp_shift, Y12_amp_shift;
reg		[3:0] Y12_Huff_shift, Y12_Huff_shift_1, zero_run_length, zrl_1, zrl_2, zrl_3;
reg		[4:0] Y12_Huff_count, Y12_Huff_count_1;
reg		[4:0] output_reg_count, Y11_output_count, old_orc_1, old_orc_2;
reg		[4:0] old_orc_3, old_orc_4, old_orc_5, old_orc_6, Y12_oc_1;
reg		[4:0] orc_3, orc_4, orc_5, orc_6, orc_7, orc_8;
reg		[4:0] Y12_output_count;
reg 	[4:0] Y12_edge, Y12_edge_1, Y12_edge_2, Y12_edge_3, Y12_edge_4;
reg		[31:0]	JPEG_bitstream, JPEG_bs, JPEG_bs_1, JPEG_bs_2, JPEG_bs_3, JPEG_bs_4, JPEG_bs_5;
reg		[31:0]	JPEG_Y12_bs, JPEG_Y12_bs_1, JPEG_Y12_bs_2, JPEG_Y12_bs_3, JPEG_Y12_bs_4;
reg		[31:0]	JPEG_ro_bs, JPEG_ro_bs_1, JPEG_ro_bs_2, JPEG_ro_bs_3, JPEG_ro_bs_4;
reg		[21:0]	Y11_JPEG_LSBs_3;
reg		[10:0]	Y11_JPEG_LSBs, Y11_JPEG_LSBs_1, Y11_JPEG_LSBs_2;
reg		[9:0]	Y12_JPEG_LSBs, Y12_JPEG_LSBs_1, Y12_JPEG_LSBs_2, Y12_JPEG_LSBs_3;
reg		[25:0]	Y11_JPEG_bits, Y11_JPEG_bits_1, Y12_JPEG_bits, Y12_JPEG_LSBs_4;	  
reg		[7:0]	Y12_code_entry;
reg		third_8_all_0s, fourth_8_all_0s, fifth_8_all_0s, sixth_8_all_0s, seventh_8_all_0s;
reg		eighth_8_all_0s, end_of_block, code_15_0, zrl_et_15, end_of_block_output;
reg		end_of_block_empty;

wire	[7:0]	code_index = { zrl_2, Y12_bits };



always @(posedge clk)
begin
	if (rst) begin
		third_8_all_0s <= 0; fourth_8_all_0s <= 0;
		fifth_8_all_0s <= 0; sixth_8_all_0s <= 0; seventh_8_all_0s <= 0;
		eighth_8_all_0s <= 0;
		end
	else if (enable_1) begin
		third_8_all_0s <= Y25_et_zero & Y34_et_zero & Y43_et_zero & Y52_et_zero
					  & Y61_et_zero & Y71_et_zero & Y62_et_zero & Y53_et_zero;
		fourth_8_all_0s <= Y44_et_zero & Y35_et_zero & Y26_et_zero & Y17_et_zero
					  & Y18_et_zero & Y27_et_zero & Y36_et_zero & Y45_et_zero;
		fifth_8_all_0s <= Y54_et_zero & Y63_et_zero & Y72_et_zero & Y81_et_zero
					  & Y82_et_zero & Y73_et_zero & Y64_et_zero & Y55_et_zero;
		sixth_8_all_0s <= Y46_et_zero & Y37_et_zero & Y28_et_zero & Y38_et_zero
					  & Y47_et_zero & Y56_et_zero & Y65_et_zero & Y74_et_zero;
		seventh_8_all_0s <= Y83_et_zero & Y84_et_zero & Y75_et_zero & Y66_et_zero
					  & Y57_et_zero & Y48_et_zero & Y58_et_zero & Y67_et_zero;
		eighth_8_all_0s <= Y76_et_zero & Y85_et_zero & Y86_et_zero & Y77_et_zero
					  & Y68_et_zero & Y78_et_zero & Y87_et_zero & Y88_et_zero;						  			  
		end
end	 


/* end_of_block checks to see if there are any nonzero elements left in the block
If there aren't any nonzero elements left, then the last bits in the JPEG stream
will be the end of block code.  The purpose of this register is to determine if the
zero run length code 15-0 should be used or not.  It should be used if there are 15 or more
zeros in a row, followed by a nonzero value.  If there are only zeros left in the block,
then end_of_block will be 1.  If there are any nonzero values left in the block, end_of_block 
will be 0. */

always @(posedge clk)
begin
	if (rst) 
		end_of_block <= 0;
	else if (enable)
		end_of_block <= 0;
	else if (enable_module & block_counter < 32)
		end_of_block <= third_8_all_0s & fourth_8_all_0s & fifth_8_all_0s
					& sixth_8_all_0s & seventh_8_all_0s & eighth_8_all_0s;
	else if (enable_module & block_counter < 48)
		end_of_block <= fifth_8_all_0s & sixth_8_all_0s & seventh_8_all_0s 
					& eighth_8_all_0s;
	else if (enable_module & block_counter <= 64)
		end_of_block <= seventh_8_all_0s & eighth_8_all_0s;
	else if (enable_module & block_counter > 64)
		end_of_block <= 1;
end	 

always @(posedge clk)
begin
	if (rst) begin
		block_counter <= 0;
		end
	else if (enable) begin
		block_counter <= 0;
		end	
	else if (enable_module) begin
		block_counter <= block_counter + 1;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin
		output_reg_count <= 0;
		end
	else if (end_of_block_output) begin
		output_reg_count <= 0;
		end
	else if (enable_6) begin
		output_reg_count <= output_reg_count + Y11_output_count;
		end	
	else if (enable_latch_7) begin
		output_reg_count <= output_reg_count + Y12_oc_1;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin
		old_orc_1 <= 0;
		end
	else if (end_of_block_output) begin
		old_orc_1 <= 0;
		end
	else if (enable_module) begin
		old_orc_1 <= output_reg_count;
		end
end

always @(posedge clk)
begin
	if (rst) begin
		rollover <= 0; rollover_1 <= 0; rollover_2 <= 0;
		rollover_3 <= 0; rollover_4 <= 0; rollover_5 <= 0;
		rollover_6 <= 0; rollover_7 <= 0;
		old_orc_2 <= 0; 
		orc_3 <= 0; orc_4 <= 0; orc_5 <= 0; orc_6 <= 0; 
		orc_7 <= 0; orc_8 <= 0; data_ready <= 0;
		end_of_block_output <= 0; end_of_block_empty <= 0;
		end
	else if (enable_module) begin
		rollover <= (old_orc_1 > output_reg_count); 
		rollover_1 <= rollover;
		rollover_2 <= rollover_1;
		rollover_3 <= rollover_2;
		rollover_4 <= rollover_3;
		rollover_5 <= rollover_4;
		rollover_6 <= rollover_5;
		rollover_7 <= rollover_6;
		old_orc_2 <= old_orc_1;
		orc_3 <= old_orc_2;
		orc_4 <= orc_3; orc_5 <= orc_4;
		orc_6 <= orc_5; orc_7 <= orc_6;
		orc_8 <= orc_7;
		data_ready <= rollover_6 | block_counter == 77;
		end_of_block_output <= block_counter == 77;
		end_of_block_empty <= rollover_7 & block_counter == 77 & output_reg_count == 0;
		end
end	 


	
always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs_5 <= 0; 
		end
	else if (enable_module) begin 
		JPEG_bs_5[31] <= (rollover_6 & orc_7 > 0) ? JPEG_ro_bs_4[31] : JPEG_bs_4[31];
		JPEG_bs_5[30] <= (rollover_6 & orc_7 > 1) ? JPEG_ro_bs_4[30] : JPEG_bs_4[30];
		JPEG_bs_5[29] <= (rollover_6 & orc_7 > 2) ? JPEG_ro_bs_4[29] : JPEG_bs_4[29];
		JPEG_bs_5[28] <= (rollover_6 & orc_7 > 3) ? JPEG_ro_bs_4[28] : JPEG_bs_4[28];
		JPEG_bs_5[27] <= (rollover_6 & orc_7 > 4) ? JPEG_ro_bs_4[27] : JPEG_bs_4[27];
		JPEG_bs_5[26] <= (rollover_6 & orc_7 > 5) ? JPEG_ro_bs_4[26] : JPEG_bs_4[26];
		JPEG_bs_5[25] <= (rollover_6 & orc_7 > 6) ? JPEG_ro_bs_4[25] : JPEG_bs_4[25];
		JPEG_bs_5[24] <= (rollover_6 & orc_7 > 7) ? JPEG_ro_bs_4[24] : JPEG_bs_4[24];
		JPEG_bs_5[23] <= (rollover_6 & orc_7 > 8) ? JPEG_ro_bs_4[23] : JPEG_bs_4[23];
		JPEG_bs_5[22] <= (rollover_6 & orc_7 > 9) ? JPEG_ro_bs_4[22] : JPEG_bs_4[22];
		JPEG_bs_5[21] <= (rollover_6 & orc_7 > 10) ? JPEG_ro_bs_4[21] : JPEG_bs_4[21];
		JPEG_bs_5[20] <= (rollover_6 & orc_7 > 11) ? JPEG_ro_bs_4[20] : JPEG_bs_4[20];
		JPEG_bs_5[19] <= (rollover_6 & orc_7 > 12) ? JPEG_ro_bs_4[19] : JPEG_bs_4[19];
		JPEG_bs_5[18] <= (rollover_6 & orc_7 > 13) ? JPEG_ro_bs_4[18] : JPEG_bs_4[18];
		JPEG_bs_5[17] <= (rollover_6 & orc_7 > 14) ? JPEG_ro_bs_4[17] : JPEG_bs_4[17];
		JPEG_bs_5[16] <= (rollover_6 & orc_7 > 15) ? JPEG_ro_bs_4[16] : JPEG_bs_4[16];
		JPEG_bs_5[15] <= (rollover_6 & orc_7 > 16) ? JPEG_ro_bs_4[15] : JPEG_bs_4[15];
		JPEG_bs_5[14] <= (rollover_6 & orc_7 > 17) ? JPEG_ro_bs_4[14] : JPEG_bs_4[14];
		JPEG_bs_5[13] <= (rollover_6 & orc_7 > 18) ? JPEG_ro_bs_4[13] : JPEG_bs_4[13];
		JPEG_bs_5[12] <= (rollover_6 & orc_7 > 19) ? JPEG_ro_bs_4[12] : JPEG_bs_4[12];
		JPEG_bs_5[11] <= (rollover_6 & orc_7 > 20) ? JPEG_ro_bs_4[11] : JPEG_bs_4[11];
		JPEG_bs_5[10] <= (rollover_6 & orc_7 > 21) ? JPEG_ro_bs_4[10] : JPEG_bs_4[10];
		JPEG_bs_5[9] <= (rollover_6 & orc_7 > 22) ? JPEG_ro_bs_4[9] : JPEG_bs_4[9];
		JPEG_bs_5[8] <= (rollover_6 & orc_7 > 23) ? JPEG_ro_bs_4[8] : JPEG_bs_4[8];
		JPEG_bs_5[7] <= (rollover_6 & orc_7 > 24) ? JPEG_ro_bs_4[7] : JPEG_bs_4[7];
		JPEG_bs_5[6] <= (rollover_6 & orc_7 > 25) ? JPEG_ro_bs_4[6] : JPEG_bs_4[6];
		JPEG_bs_5[5] <= (rollover_6 & orc_7 > 26) ? JPEG_ro_bs_4[5] : JPEG_bs_4[5];
		JPEG_bs_5[4] <= (rollover_6 & orc_7 > 27) ? JPEG_ro_bs_4[4] : JPEG_bs_4[4];
		JPEG_bs_5[3] <= (rollover_6 & orc_7 > 28) ? JPEG_ro_bs_4[3] : JPEG_bs_4[3];
		JPEG_bs_5[2] <= (rollover_6 & orc_7 > 29) ? JPEG_ro_bs_4[2] : JPEG_bs_4[2];
		JPEG_bs_5[1] <= (rollover_6 & orc_7 > 30) ? JPEG_ro_bs_4[1] : JPEG_bs_4[1];
		JPEG_bs_5[0] <= JPEG_bs_4[0];
		end
end	
	
always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs_4 <= 0; JPEG_ro_bs_4 <= 0;
		end
	else if (enable_module) begin 
		JPEG_bs_4 <= (old_orc_6 == 1) ? JPEG_bs_3 >> 1 : JPEG_bs_3;
		JPEG_ro_bs_4 <= (Y12_edge_4 <= 1) ? JPEG_ro_bs_3 << 1 : JPEG_ro_bs_3;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs_3 <= 0; old_orc_6 <= 0; JPEG_ro_bs_3 <= 0;
		Y12_edge_4 <= 0; 
		end
	else if (enable_module) begin 
		JPEG_bs_3 <= (old_orc_5 >= 2) ? JPEG_bs_2 >> 2 : JPEG_bs_2;
		old_orc_6 <= (old_orc_5 >= 2) ? old_orc_5 - 2 : old_orc_5;
		JPEG_ro_bs_3 <= (Y12_edge_3 <= 2) ? JPEG_ro_bs_2 << 2 : JPEG_ro_bs_2;
		Y12_edge_4 <= (Y12_edge_3 <= 2) ? Y12_edge_3 : Y12_edge_3 - 2;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs_2 <= 0; old_orc_5 <= 0; JPEG_ro_bs_2 <= 0;
		Y12_edge_3 <= 0; 
		end
	else if (enable_module) begin 
		JPEG_bs_2 <= (old_orc_4 >= 4) ? JPEG_bs_1 >> 4 : JPEG_bs_1;
		old_orc_5 <= (old_orc_4 >= 4) ? old_orc_4 - 4 : old_orc_4;
		JPEG_ro_bs_2 <= (Y12_edge_2 <= 4) ? JPEG_ro_bs_1 << 4 : JPEG_ro_bs_1;
		Y12_edge_3 <= (Y12_edge_2 <= 4) ? Y12_edge_2 : Y12_edge_2 - 4;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs_1 <= 0; old_orc_4 <= 0; JPEG_ro_bs_1 <= 0; 
		Y12_edge_2 <= 0; 
		end
	else if (enable_module) begin 
		JPEG_bs_1 <= (old_orc_3 >= 8) ? JPEG_bs >> 8 : JPEG_bs;
		old_orc_4 <= (old_orc_3 >= 8) ? old_orc_3 - 8 : old_orc_3;
		JPEG_ro_bs_1 <= (Y12_edge_1 <= 8) ? JPEG_ro_bs << 8 : JPEG_ro_bs;
		Y12_edge_2 <= (Y12_edge_1 <= 8) ? Y12_edge_1 : Y12_edge_1 - 8;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		JPEG_bs <= 0; old_orc_3 <= 0; JPEG_ro_bs <= 0;
		Y12_edge_1 <= 0; Y11_JPEG_bits_1 <= 0;
		end
	else if (enable_module) begin 
		JPEG_bs <= (old_orc_2 >= 16) ? Y11_JPEG_bits >> 10 : Y11_JPEG_bits << 6;
		old_orc_3 <= (old_orc_2 >= 16) ? old_orc_2 - 16 : old_orc_2;
		JPEG_ro_bs <= (Y12_edge <= 16) ? Y11_JPEG_bits_1 << 16 : Y11_JPEG_bits_1;
		Y12_edge_1 <= (Y12_edge <= 16) ? Y12_edge : Y12_edge - 16;
		Y11_JPEG_bits_1 <= Y11_JPEG_bits;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y12_JPEG_bits <= 0; Y12_edge <= 0;
		end
	else if (enable_module) begin 
		Y12_JPEG_bits[25] <= (Y12_Huff_shift_1 >= 16) ? Y12_JPEG_LSBs_4[25] : Y12_Huff_2[15];
		Y12_JPEG_bits[24] <= (Y12_Huff_shift_1 >= 15) ? Y12_JPEG_LSBs_4[24] : Y12_Huff_2[14];
		Y12_JPEG_bits[23] <= (Y12_Huff_shift_1 >= 14) ? Y12_JPEG_LSBs_4[23] : Y12_Huff_2[13];
		Y12_JPEG_bits[22] <= (Y12_Huff_shift_1 >= 13) ? Y12_JPEG_LSBs_4[22] : Y12_Huff_2[12];
		Y12_JPEG_bits[21] <= (Y12_Huff_shift_1 >= 12) ? Y12_JPEG_LSBs_4[21] : Y12_Huff_2[11];
		Y12_JPEG_bits[20] <= (Y12_Huff_shift_1 >= 11) ? Y12_JPEG_LSBs_4[20] : Y12_Huff_2[10];
		Y12_JPEG_bits[19] <= (Y12_Huff_shift_1 >= 10) ? Y12_JPEG_LSBs_4[19] : Y12_Huff_2[9];
		Y12_JPEG_bits[18] <= (Y12_Huff_shift_1 >= 9) ? Y12_JPEG_LSBs_4[18] : Y12_Huff_2[8];
		Y12_JPEG_bits[17] <= (Y12_Huff_shift_1 >= 8) ? Y12_JPEG_LSBs_4[17] : Y12_Huff_2[7];
		Y12_JPEG_bits[16] <= (Y12_Huff_shift_1 >= 7) ? Y12_JPEG_LSBs_4[16] : Y12_Huff_2[6];
		Y12_JPEG_bits[15] <= (Y12_Huff_shift_1 >= 6) ? Y12_JPEG_LSBs_4[15] : Y12_Huff_2[5];
		Y12_JPEG_bits[14] <= (Y12_Huff_shift_1 >= 5) ? Y12_JPEG_LSBs_4[14] : Y12_Huff_2[4];
		Y12_JPEG_bits[13] <= (Y12_Huff_shift_1 >= 4) ? Y12_JPEG_LSBs_4[13] : Y12_Huff_2[3];
		Y12_JPEG_bits[12] <= (Y12_Huff_shift_1 >= 3) ? Y12_JPEG_LSBs_4[12] : Y12_Huff_2[2];
		Y12_JPEG_bits[11] <= (Y12_Huff_shift_1 >= 2) ? Y12_JPEG_LSBs_4[11] : Y12_Huff_2[1];
		Y12_JPEG_bits[10] <= (Y12_Huff_shift_1 >= 1) ? Y12_JPEG_LSBs_4[10] : Y12_Huff_2[0];
		Y12_JPEG_bits[9:0] <= Y12_JPEG_LSBs_4[9:0];
		Y12_edge <= old_orc_2 + 26; // 26 is the size of Y11_JPEG_bits
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y11_JPEG_bits <= 0; 
		end
	else if (enable_7) begin 
		Y11_JPEG_bits[25] <= (Y11_Huff_shift_1 >= 11) ? Y11_JPEG_LSBs_3[21] : Y11_Huff_2[10];
		Y11_JPEG_bits[24] <= (Y11_Huff_shift_1 >= 10) ? Y11_JPEG_LSBs_3[20] : Y11_Huff_2[9];
		Y11_JPEG_bits[23] <= (Y11_Huff_shift_1 >= 9) ? Y11_JPEG_LSBs_3[19] : Y11_Huff_2[8];
		Y11_JPEG_bits[22] <= (Y11_Huff_shift_1 >= 8) ? Y11_JPEG_LSBs_3[18] : Y11_Huff_2[7];
		Y11_JPEG_bits[21] <= (Y11_Huff_shift_1 >= 7) ? Y11_JPEG_LSBs_3[17] : Y11_Huff_2[6];
		Y11_JPEG_bits[20] <= (Y11_Huff_shift_1 >= 6) ? Y11_JPEG_LSBs_3[16] : Y11_Huff_2[5];
		Y11_JPEG_bits[19] <= (Y11_Huff_shift_1 >= 5) ? Y11_JPEG_LSBs_3[15] : Y11_Huff_2[4];
		Y11_JPEG_bits[18] <= (Y11_Huff_shift_1 >= 4) ? Y11_JPEG_LSBs_3[14] : Y11_Huff_2[3];
		Y11_JPEG_bits[17] <= (Y11_Huff_shift_1 >= 3) ? Y11_JPEG_LSBs_3[13] : Y11_Huff_2[2];
		Y11_JPEG_bits[16] <= (Y11_Huff_shift_1 >= 2) ? Y11_JPEG_LSBs_3[12] : Y11_Huff_2[1];
		Y11_JPEG_bits[15] <= (Y11_Huff_shift_1 >= 1) ? Y11_JPEG_LSBs_3[11] : Y11_Huff_2[0];
		Y11_JPEG_bits[14:4] <= Y11_JPEG_LSBs_3[10:0];
		end
	else if (enable_latch_8) begin
		Y11_JPEG_bits <= Y12_JPEG_bits;
		end
end	


always @(posedge clk)
begin
	if (rst) begin
		Y12_oc_1 <= 0; Y12_JPEG_LSBs_4 <= 0;
		Y12_Huff_2 <= 0; Y12_Huff_shift_1 <= 0;
		end
	else if (enable_module) begin 
		Y12_oc_1 <= (Y12_et_zero_5 & !code_15_0 & block_counter != 67) ? 0 : 
			Y12_bits_3 + Y12_Huff_count_1;
		Y12_JPEG_LSBs_4 <= Y12_JPEG_LSBs_3 << Y12_Huff_shift;
		Y12_Huff_2 <= Y12_Huff_1;
		Y12_Huff_shift_1 <= Y12_Huff_shift;
		end
end

always @(posedge clk)
begin
	if (rst) begin
		Y11_JPEG_LSBs_3 <= 0; Y11_Huff_2 <= 0; 
		Y11_Huff_shift_1 <= 0; 
		end
	else if (enable_6) begin 
		Y11_JPEG_LSBs_3 <= Y11_JPEG_LSBs_2 << Y11_Huff_shift;
		Y11_Huff_2 <= Y11_Huff_1;
		Y11_Huff_shift_1 <= Y11_Huff_shift;
		end
end	


always @(posedge clk)
begin
	if (rst) begin
		Y12_Huff_shift <= 0;
		Y12_Huff_1 <= 0; Y12_JPEG_LSBs_3 <= 0; Y12_bits_3 <= 0;
		Y12_Huff_count_1 <= 0; Y12_et_zero_5 <= 0; code_15_0 <= 0;
		end
	else if (enable_module) begin 
		Y12_Huff_shift <= 16 - Y12_Huff_count;
		Y12_Huff_1 <= Y12_Huff;
		Y12_JPEG_LSBs_3 <= Y12_JPEG_LSBs_2;
		Y12_bits_3 <= Y12_bits_2;
		Y12_Huff_count_1 <= Y12_Huff_count;
		Y12_et_zero_5 <= Y12_et_zero_4;
		code_15_0 <= zrl_et_15 & !end_of_block;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y11_output_count <= 0; Y11_JPEG_LSBs_2 <= 0; Y11_Huff_shift <= 0;
		Y11_Huff_1 <= 0;
		end
	else if (enable_5) begin 
		Y11_output_count <= Y11_bits_1 + Y11_Huff_count;
		Y11_JPEG_LSBs_2 <= Y11_JPEG_LSBs_1 << Y11_amp_shift;
		Y11_Huff_shift <= 11 - Y11_Huff_count;
		Y11_Huff_1 <= Y11_Huff;
		end
end	


always @(posedge clk)
begin
	if (rst) begin
		Y12_JPEG_LSBs_2 <= 0;
		Y12_Huff <= 0; Y12_Huff_count <= 0; Y12_bits_2 <= 0;
		Y12_et_zero_4 <= 0; zrl_et_15 <= 0; zrl_3 <= 0;
		end
	else if (enable_module) begin
		Y12_JPEG_LSBs_2 <= Y12_JPEG_LSBs_1 << Y12_amp_shift;
		Y12_Huff <= Y_AC[Y12_code_entry];
		Y12_Huff_count <= Y_AC_code_length[Y12_code_entry];
		Y12_bits_2 <= Y12_bits_1;
		Y12_et_zero_4 <= Y12_et_zero_3;
		zrl_et_15 <= zrl_3 == 15;
		zrl_3 <= zrl_2;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y11_Huff <= 0; Y11_Huff_count <= 0; Y11_amp_shift <= 0;
		Y11_JPEG_LSBs_1 <= 0; Y11_bits_1 <= 0; 
		end
	else if (enable_4) begin
		Y11_Huff[10:0] <= Y_DC[Y11_bits];
		Y11_Huff_count <= Y_DC_code_length[Y11_bits];
		Y11_amp_shift <= 11 - Y11_bits;
		Y11_JPEG_LSBs_1 <= Y11_JPEG_LSBs;
		Y11_bits_1 <= Y11_bits;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y12_code_entry <= 0; Y12_JPEG_LSBs_1 <= 0; Y12_amp_shift <= 0; 
		Y12_bits_1 <= 0; Y12_et_zero_3 <= 0; zrl_2 <= 0;
		end
	else if (enable_module) begin
		Y12_code_entry <= Y_AC_run_code[code_index];
		Y12_JPEG_LSBs_1 <= Y12_JPEG_LSBs;
		Y12_amp_shift <= 10 - Y12_bits;
		Y12_bits_1 <= Y12_bits;
		Y12_et_zero_3 <= Y12_et_zero_2;
		zrl_2 <= zrl_1;
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y11_bits <= 0; Y11_JPEG_LSBs <= 0; 
		end
	else if (enable_3) begin
		Y11_bits <= Y11_msb ? Y11_bits_neg : Y11_bits_pos;
		Y11_JPEG_LSBs <= Y11_amp[10:0]; // The top bit of Y11_amp is the sign bit
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		Y12_bits <= 0; Y12_JPEG_LSBs <= 0; zrl_1 <= 0;
		Y12_et_zero_2 <= 0;
		end
	else if (enable_module) begin 
		Y12_bits <= Y12_msb_1 ? Y12_bits_neg : Y12_bits_pos;
		Y12_JPEG_LSBs <= Y12_amp[9:0]; // The top bit of Y12_amp is the sign bit
		zrl_1 <= block_counter == 62 & Y12_et_zero ? 0 : zero_run_length;
		Y12_et_zero_2 <= Y12_et_zero_1;
		end
end	

// Y11_amp is the amplitude that will be represented in bits in the 
// JPEG code, following the run length code
always @(posedge clk)
begin
	if (rst) begin
		Y11_amp <= 0;
		end
	else if (enable_2) begin 
		Y11_amp <= Y11_msb ? Y11_1_neg : Y11_1_pos;
		end
end	


always @(posedge clk)
begin
	if (rst) 
		zero_run_length <= 0; 
	else if (enable)
		zero_run_length <= 0; 
	else if (enable_module) 
		zero_run_length <= Y12_et_zero ? zero_run_length + 1: 0;
end	 

always @(posedge clk)
begin
	if (rst) begin
		Y12_amp <= 0;  
		Y12_et_zero_1 <= 0; Y12_msb_1 <= 0;
		end
	else if (enable_module) begin
		Y12_amp <= Y12_msb ? Y12_neg : Y12_pos;
		Y12_et_zero_1 <= Y12_et_zero;
		Y12_msb_1 <= Y12_msb;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin
		Y11_1_pos <= 0; Y11_1_neg <= 0; Y11_msb <= 0;
		Y11_previous <= 0; 
		end
	else if (enable_1) begin
		Y11_1_pos <= Y11_diff;
		Y11_1_neg <= Y11_diff - 1;
		Y11_msb <= Y11_diff[11];
		Y11_previous <= Y11_1;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin 
		Y12_pos <= 0; Y12_neg <= 0; Y12_msb <= 0; Y12_et_zero <= 0; 
		Y13_pos <= 0; Y13_neg <= 0; Y13_msb <= 0; Y13_et_zero <= 0;
		Y14_pos <= 0; Y14_neg <= 0; Y14_msb <= 0; Y14_et_zero <= 0; 
		Y15_pos <= 0; Y15_neg <= 0; Y15_msb <= 0; Y15_et_zero <= 0;
		Y16_pos <= 0; Y16_neg <= 0; Y16_msb <= 0; Y16_et_zero <= 0; 
		Y17_pos <= 0; Y17_neg <= 0; Y17_msb <= 0; Y17_et_zero <= 0;
		Y18_pos <= 0; Y18_neg <= 0; Y18_msb <= 0; Y18_et_zero <= 0; 
		Y21_pos <= 0; Y21_neg <= 0; Y21_msb <= 0; Y21_et_zero <= 0;
		Y22_pos <= 0; Y22_neg <= 0; Y22_msb <= 0; Y22_et_zero <= 0; 
		Y23_pos <= 0; Y23_neg <= 0; Y23_msb <= 0; Y23_et_zero <= 0;
		Y24_pos <= 0; Y24_neg <= 0; Y24_msb <= 0; Y24_et_zero <= 0; 
		Y25_pos <= 0; Y25_neg <= 0; Y25_msb <= 0; Y25_et_zero <= 0;
		Y26_pos <= 0; Y26_neg <= 0; Y26_msb <= 0; Y26_et_zero <= 0; 
		Y27_pos <= 0; Y27_neg <= 0; Y27_msb <= 0; Y27_et_zero <= 0;
		Y28_pos <= 0; Y28_neg <= 0; Y28_msb <= 0; Y28_et_zero <= 0; 
		Y31_pos <= 0; Y31_neg <= 0; Y31_msb <= 0; Y31_et_zero <= 0;  
		Y32_pos <= 0; Y32_neg <= 0; Y32_msb <= 0; Y32_et_zero <= 0; 
		Y33_pos <= 0; Y33_neg <= 0; Y33_msb <= 0; Y33_et_zero <= 0;
		Y34_pos <= 0; Y34_neg <= 0; Y34_msb <= 0; Y34_et_zero <= 0; 
		Y35_pos <= 0; Y35_neg <= 0; Y35_msb <= 0; Y35_et_zero <= 0;
		Y36_pos <= 0; Y36_neg <= 0; Y36_msb <= 0; Y36_et_zero <= 0; 
		Y37_pos <= 0; Y37_neg <= 0; Y37_msb <= 0; Y37_et_zero <= 0;
		Y38_pos <= 0; Y38_neg <= 0; Y38_msb <= 0; Y38_et_zero <= 0;
		Y41_pos <= 0; Y41_neg <= 0; Y41_msb <= 0; Y41_et_zero <= 0;  
		Y42_pos <= 0; Y42_neg <= 0; Y42_msb <= 0; Y42_et_zero <= 0; 
		Y43_pos <= 0; Y43_neg <= 0; Y43_msb <= 0; Y43_et_zero <= 0;
		Y44_pos <= 0; Y44_neg <= 0; Y44_msb <= 0; Y44_et_zero <= 0; 
		Y45_pos <= 0; Y45_neg <= 0; Y45_msb <= 0; Y45_et_zero <= 0;
		Y46_pos <= 0; Y46_neg <= 0; Y46_msb <= 0; Y46_et_zero <= 0; 
		Y47_pos <= 0; Y47_neg <= 0; Y47_msb <= 0; Y47_et_zero <= 0;
		Y48_pos <= 0; Y48_neg <= 0; Y48_msb <= 0; Y48_et_zero <= 0;
		Y51_pos <= 0; Y51_neg <= 0; Y51_msb <= 0; Y51_et_zero <= 0;  
		Y52_pos <= 0; Y52_neg <= 0; Y52_msb <= 0; Y52_et_zero <= 0; 
		Y53_pos <= 0; Y53_neg <= 0; Y53_msb <= 0; Y53_et_zero <= 0;
		Y54_pos <= 0; Y54_neg <= 0; Y54_msb <= 0; Y54_et_zero <= 0; 
		Y55_pos <= 0; Y55_neg <= 0; Y55_msb <= 0; Y55_et_zero <= 0;
		Y56_pos <= 0; Y56_neg <= 0; Y56_msb <= 0; Y56_et_zero <= 0; 
		Y57_pos <= 0; Y57_neg <= 0; Y57_msb <= 0; Y57_et_zero <= 0;
		Y58_pos <= 0; Y58_neg <= 0; Y58_msb <= 0; Y58_et_zero <= 0;
		Y61_pos <= 0; Y61_neg <= 0; Y61_msb <= 0; Y61_et_zero <= 0;  
		Y62_pos <= 0; Y62_neg <= 0; Y62_msb <= 0; Y62_et_zero <= 0; 
		Y63_pos <= 0; Y63_neg <= 0; Y63_msb <= 0; Y63_et_zero <= 0;
		Y64_pos <= 0; Y64_neg <= 0; Y64_msb <= 0; Y64_et_zero <= 0; 
		Y65_pos <= 0; Y65_neg <= 0; Y65_msb <= 0; Y65_et_zero <= 0;
		Y66_pos <= 0; Y66_neg <= 0; Y66_msb <= 0; Y66_et_zero <= 0; 
		Y67_pos <= 0; Y67_neg <= 0; Y67_msb <= 0; Y67_et_zero <= 0;
		Y68_pos <= 0; Y68_neg <= 0; Y68_msb <= 0; Y68_et_zero <= 0;
		Y71_pos <= 0; Y71_neg <= 0; Y71_msb <= 0; Y71_et_zero <= 0;  
		Y72_pos <= 0; Y72_neg <= 0; Y72_msb <= 0; Y72_et_zero <= 0; 
		Y73_pos <= 0; Y73_neg <= 0; Y73_msb <= 0; Y73_et_zero <= 0;
		Y74_pos <= 0; Y74_neg <= 0; Y74_msb <= 0; Y74_et_zero <= 0; 
		Y75_pos <= 0; Y75_neg <= 0; Y75_msb <= 0; Y75_et_zero <= 0;
		Y76_pos <= 0; Y76_neg <= 0; Y76_msb <= 0; Y76_et_zero <= 0; 
		Y77_pos <= 0; Y77_neg <= 0; Y77_msb <= 0; Y77_et_zero <= 0;
		Y78_pos <= 0; Y78_neg <= 0; Y78_msb <= 0; Y78_et_zero <= 0;
		Y81_pos <= 0; Y81_neg <= 0; Y81_msb <= 0; Y81_et_zero <= 0;  
		Y82_pos <= 0; Y82_neg <= 0; Y82_msb <= 0; Y82_et_zero <= 0; 
		Y83_pos <= 0; Y83_neg <= 0; Y83_msb <= 0; Y83_et_zero <= 0;
		Y84_pos <= 0; Y84_neg <= 0; Y84_msb <= 0; Y84_et_zero <= 0; 
		Y85_pos <= 0; Y85_neg <= 0; Y85_msb <= 0; Y85_et_zero <= 0;
		Y86_pos <= 0; Y86_neg <= 0; Y86_msb <= 0; Y86_et_zero <= 0; 
		Y87_pos <= 0; Y87_neg <= 0; Y87_msb <= 0; Y87_et_zero <= 0;
		Y88_pos <= 0; Y88_neg <= 0; Y88_msb <= 0; Y88_et_zero <= 0; 
		end
	else if (enable) begin 
		Y12_pos <= Y12;	   
		Y12_neg <= Y12 - 1;
		Y12_msb <= Y12[10];
		Y12_et_zero <= !(|Y12);
		Y13_pos <= Y13;	   
		Y13_neg <= Y13 - 1;
		Y13_msb <= Y13[10];
		Y13_et_zero <= !(|Y13);
		Y14_pos <= Y14;	   
		Y14_neg <= Y14 - 1;
		Y14_msb <= Y14[10];
		Y14_et_zero <= !(|Y14);
		Y15_pos <= Y15;	   
		Y15_neg <= Y15 - 1;
		Y15_msb <= Y15[10];
		Y15_et_zero <= !(|Y15);
		Y16_pos <= Y16;	   
		Y16_neg <= Y16 - 1;
		Y16_msb <= Y16[10];
		Y16_et_zero <= !(|Y16);
		Y17_pos <= Y17;	   
		Y17_neg <= Y17 - 1;
		Y17_msb <= Y17[10];
		Y17_et_zero <= !(|Y17);
		Y18_pos <= Y18;	   
		Y18_neg <= Y18 - 1;
		Y18_msb <= Y18[10];
		Y18_et_zero <= !(|Y18);
		Y21_pos <= Y21;	   
		Y21_neg <= Y21 - 1;
		Y21_msb <= Y21[10];
		Y21_et_zero <= !(|Y21);
		Y22_pos <= Y22;	   
		Y22_neg <= Y22 - 1;
		Y22_msb <= Y22[10];
		Y22_et_zero <= !(|Y22);
		Y23_pos <= Y23;	   
		Y23_neg <= Y23 - 1;
		Y23_msb <= Y23[10];
		Y23_et_zero <= !(|Y23);
		Y24_pos <= Y24;	   
		Y24_neg <= Y24 - 1;
		Y24_msb <= Y24[10];
		Y24_et_zero <= !(|Y24);
		Y25_pos <= Y25;	   
		Y25_neg <= Y25 - 1;
		Y25_msb <= Y25[10];
		Y25_et_zero <= !(|Y25);
		Y26_pos <= Y26;	   
		Y26_neg <= Y26 - 1;
		Y26_msb <= Y26[10];
		Y26_et_zero <= !(|Y26);
		Y27_pos <= Y27;	   
		Y27_neg <= Y27 - 1;
		Y27_msb <= Y27[10];
		Y27_et_zero <= !(|Y27);
		Y28_pos <= Y28;	   
		Y28_neg <= Y28 - 1;
		Y28_msb <= Y28[10];
		Y28_et_zero <= !(|Y28);
		Y31_pos <= Y31;	   
		Y31_neg <= Y31 - 1;
		Y31_msb <= Y31[10];
		Y31_et_zero <= !(|Y31);
		Y32_pos <= Y32;	   
		Y32_neg <= Y32 - 1;
		Y32_msb <= Y32[10];
		Y32_et_zero <= !(|Y32);
		Y33_pos <= Y33;	   
		Y33_neg <= Y33 - 1;
		Y33_msb <= Y33[10];
		Y33_et_zero <= !(|Y33);
		Y34_pos <= Y34;	   
		Y34_neg <= Y34 - 1;
		Y34_msb <= Y34[10];
		Y34_et_zero <= !(|Y34);
		Y35_pos <= Y35;	   
		Y35_neg <= Y35 - 1;
		Y35_msb <= Y35[10];
		Y35_et_zero <= !(|Y35);
		Y36_pos <= Y36;	   
		Y36_neg <= Y36 - 1;
		Y36_msb <= Y36[10];
		Y36_et_zero <= !(|Y36);
		Y37_pos <= Y37;	   
		Y37_neg <= Y37 - 1;
		Y37_msb <= Y37[10];
		Y37_et_zero <= !(|Y37);
		Y38_pos <= Y38;	   
		Y38_neg <= Y38 - 1;
		Y38_msb <= Y38[10];
		Y38_et_zero <= !(|Y38);
		Y41_pos <= Y41;	   
		Y41_neg <= Y41 - 1;
		Y41_msb <= Y41[10];
		Y41_et_zero <= !(|Y41);
		Y42_pos <= Y42;	   
		Y42_neg <= Y42 - 1;
		Y42_msb <= Y42[10];
		Y42_et_zero <= !(|Y42);
		Y43_pos <= Y43;	   
		Y43_neg <= Y43 - 1;
		Y43_msb <= Y43[10];
		Y43_et_zero <= !(|Y43);
		Y44_pos <= Y44;	   
		Y44_neg <= Y44 - 1;
		Y44_msb <= Y44[10];
		Y44_et_zero <= !(|Y44);
		Y45_pos <= Y45;	   
		Y45_neg <= Y45 - 1;
		Y45_msb <= Y45[10];
		Y45_et_zero <= !(|Y45);
		Y46_pos <= Y46;	   
		Y46_neg <= Y46 - 1;
		Y46_msb <= Y46[10];
		Y46_et_zero <= !(|Y46);
		Y47_pos <= Y47;	   
		Y47_neg <= Y47 - 1;
		Y47_msb <= Y47[10];
		Y47_et_zero <= !(|Y47);
		Y48_pos <= Y48;	   
		Y48_neg <= Y48 - 1;
		Y48_msb <= Y48[10];
		Y48_et_zero <= !(|Y48);
		Y51_pos <= Y51;	   
		Y51_neg <= Y51 - 1;
		Y51_msb <= Y51[10];
		Y51_et_zero <= !(|Y51);
		Y52_pos <= Y52;	   
		Y52_neg <= Y52 - 1;
		Y52_msb <= Y52[10];
		Y52_et_zero <= !(|Y52);
		Y53_pos <= Y53;	   
		Y53_neg <= Y53 - 1;
		Y53_msb <= Y53[10];
		Y53_et_zero <= !(|Y53);
		Y54_pos <= Y54;	   
		Y54_neg <= Y54 - 1;
		Y54_msb <= Y54[10];
		Y54_et_zero <= !(|Y54);
		Y55_pos <= Y55;	   
		Y55_neg <= Y55 - 1;
		Y55_msb <= Y55[10];
		Y55_et_zero <= !(|Y55);
		Y56_pos <= Y56;	   
		Y56_neg <= Y56 - 1;
		Y56_msb <= Y56[10];
		Y56_et_zero <= !(|Y56);
		Y57_pos <= Y57;	   
		Y57_neg <= Y57 - 1;
		Y57_msb <= Y57[10];
		Y57_et_zero <= !(|Y57);
		Y58_pos <= Y58;	   
		Y58_neg <= Y58 - 1;
		Y58_msb <= Y58[10];
		Y58_et_zero <= !(|Y58);
		Y61_pos <= Y61;	   
		Y61_neg <= Y61 - 1;
		Y61_msb <= Y61[10];
		Y61_et_zero <= !(|Y61);
		Y62_pos <= Y62;	   
		Y62_neg <= Y62 - 1;
		Y62_msb <= Y62[10];
		Y62_et_zero <= !(|Y62);
		Y63_pos <= Y63;	   
		Y63_neg <= Y63 - 1;
		Y63_msb <= Y63[10];
		Y63_et_zero <= !(|Y63);
		Y64_pos <= Y64;	   
		Y64_neg <= Y64 - 1;
		Y64_msb <= Y64[10];
		Y64_et_zero <= !(|Y64);
		Y65_pos <= Y65;	   
		Y65_neg <= Y65 - 1;
		Y65_msb <= Y65[10];
		Y65_et_zero <= !(|Y65);
		Y66_pos <= Y66;	   
		Y66_neg <= Y66 - 1;
		Y66_msb <= Y66[10];
		Y66_et_zero <= !(|Y66);
		Y67_pos <= Y67;	   
		Y67_neg <= Y67 - 1;
		Y67_msb <= Y67[10];
		Y67_et_zero <= !(|Y67);
		Y68_pos <= Y68;	   
		Y68_neg <= Y68 - 1;
		Y68_msb <= Y68[10];
		Y68_et_zero <= !(|Y68);
		Y71_pos <= Y71;	   
		Y71_neg <= Y71 - 1;
		Y71_msb <= Y71[10];
		Y71_et_zero <= !(|Y71);
		Y72_pos <= Y72;	   
		Y72_neg <= Y72 - 1;
		Y72_msb <= Y72[10];
		Y72_et_zero <= !(|Y72);
		Y73_pos <= Y73;	   
		Y73_neg <= Y73 - 1;
		Y73_msb <= Y73[10];
		Y73_et_zero <= !(|Y73);
		Y74_pos <= Y74;	   
		Y74_neg <= Y74 - 1;
		Y74_msb <= Y74[10];
		Y74_et_zero <= !(|Y74);
		Y75_pos <= Y75;	   
		Y75_neg <= Y75 - 1;
		Y75_msb <= Y75[10];
		Y75_et_zero <= !(|Y75);
		Y76_pos <= Y76;	   
		Y76_neg <= Y76 - 1;
		Y76_msb <= Y76[10];
		Y76_et_zero <= !(|Y76);
		Y77_pos <= Y77;	   
		Y77_neg <= Y77 - 1;
		Y77_msb <= Y77[10];
		Y77_et_zero <= !(|Y77);
		Y78_pos <= Y78;	   
		Y78_neg <= Y78 - 1;
		Y78_msb <= Y78[10];
		Y78_et_zero <= !(|Y78);
		Y81_pos <= Y81;	   
		Y81_neg <= Y81 - 1;
		Y81_msb <= Y81[10];
		Y81_et_zero <= !(|Y81);
		Y82_pos <= Y82;	   
		Y82_neg <= Y82 - 1;
		Y82_msb <= Y82[10];
		Y82_et_zero <= !(|Y82);
		Y83_pos <= Y83;	   
		Y83_neg <= Y83 - 1;
		Y83_msb <= Y83[10];
		Y83_et_zero <= !(|Y83);
		Y84_pos <= Y84;	   
		Y84_neg <= Y84 - 1;
		Y84_msb <= Y84[10];
		Y84_et_zero <= !(|Y84);
		Y85_pos <= Y85;	   
		Y85_neg <= Y85 - 1;
		Y85_msb <= Y85[10];
		Y85_et_zero <= !(|Y85);
		Y86_pos <= Y86;	   
		Y86_neg <= Y86 - 1;
		Y86_msb <= Y86[10];
		Y86_et_zero <= !(|Y86);
		Y87_pos <= Y87;	   
		Y87_neg <= Y87 - 1;
		Y87_msb <= Y87[10];
		Y87_et_zero <= !(|Y87);
		Y88_pos <= Y88;	   
		Y88_neg <= Y88 - 1;
		Y88_msb <= Y88[10];
		Y88_et_zero <= !(|Y88);
		end
	else if (enable_module) begin 
		Y12_pos <= Y21_pos;	   
		Y12_neg <= Y21_neg;
		Y12_msb <= Y21_msb;
		Y12_et_zero <= Y21_et_zero;
		Y21_pos <= Y31_pos;	   
		Y21_neg <= Y31_neg;
		Y21_msb <= Y31_msb;
		Y21_et_zero <= Y31_et_zero;
		Y31_pos <= Y22_pos;	   
		Y31_neg <= Y22_neg;
		Y31_msb <= Y22_msb;
		Y31_et_zero <= Y22_et_zero;
		Y22_pos <= Y13_pos;	   
		Y22_neg <= Y13_neg;
		Y22_msb <= Y13_msb;
		Y22_et_zero <= Y13_et_zero;
		Y13_pos <= Y14_pos;	   
		Y13_neg <= Y14_neg;
		Y13_msb <= Y14_msb;
		Y13_et_zero <= Y14_et_zero;
		Y14_pos <= Y23_pos;	   
		Y14_neg <= Y23_neg;
		Y14_msb <= Y23_msb;
		Y14_et_zero <= Y23_et_zero;
		Y23_pos <= Y32_pos;	   
		Y23_neg <= Y32_neg;
		Y23_msb <= Y32_msb;
		Y23_et_zero <= Y32_et_zero;
		Y32_pos <= Y41_pos;	   
		Y32_neg <= Y41_neg;
		Y32_msb <= Y41_msb;
		Y32_et_zero <= Y41_et_zero;
		Y41_pos <= Y51_pos;	   
		Y41_neg <= Y51_neg;
		Y41_msb <= Y51_msb;
		Y41_et_zero <= Y51_et_zero;
		Y51_pos <= Y42_pos;	   
		Y51_neg <= Y42_neg;
		Y51_msb <= Y42_msb;
		Y51_et_zero <= Y42_et_zero;
		Y42_pos <= Y33_pos;	   
		Y42_neg <= Y33_neg;
		Y42_msb <= Y33_msb;
		Y42_et_zero <= Y33_et_zero;
		Y33_pos <= Y24_pos;	   
		Y33_neg <= Y24_neg;
		Y33_msb <= Y24_msb;
		Y33_et_zero <= Y24_et_zero;
		Y24_pos <= Y15_pos;	   
		Y24_neg <= Y15_neg;
		Y24_msb <= Y15_msb;
		Y24_et_zero <= Y15_et_zero;
		Y15_pos <= Y16_pos;	   
		Y15_neg <= Y16_neg;
		Y15_msb <= Y16_msb;
		Y15_et_zero <= Y16_et_zero;
		Y16_pos <= Y25_pos;	   
		Y16_neg <= Y25_neg;
		Y16_msb <= Y25_msb;
		Y16_et_zero <= Y25_et_zero;
		Y25_pos <= Y34_pos;	   
		Y25_neg <= Y34_neg;
		Y25_msb <= Y34_msb;
		Y25_et_zero <= Y34_et_zero;
		Y34_pos <= Y43_pos;	   
		Y34_neg <= Y43_neg;
		Y34_msb <= Y43_msb;
		Y34_et_zero <= Y43_et_zero;
		Y43_pos <= Y52_pos;	   
		Y43_neg <= Y52_neg;
		Y43_msb <= Y52_msb;
		Y43_et_zero <= Y52_et_zero;
		Y52_pos <= Y61_pos;	   
		Y52_neg <= Y61_neg;
		Y52_msb <= Y61_msb;
		Y52_et_zero <= Y61_et_zero;
		Y61_pos <= Y71_pos;	   
		Y61_neg <= Y71_neg;
		Y61_msb <= Y71_msb;
		Y61_et_zero <= Y71_et_zero;
		Y71_pos <= Y62_pos;	   
		Y71_neg <= Y62_neg;
		Y71_msb <= Y62_msb;
		Y71_et_zero <= Y62_et_zero;
		Y62_pos <= Y53_pos;	   
		Y62_neg <= Y53_neg;
		Y62_msb <= Y53_msb;
		Y62_et_zero <= Y53_et_zero;
		Y53_pos <= Y44_pos;	   
		Y53_neg <= Y44_neg;
		Y53_msb <= Y44_msb;
		Y53_et_zero <= Y44_et_zero;
		Y44_pos <= Y35_pos;	   
		Y44_neg <= Y35_neg;
		Y44_msb <= Y35_msb;
		Y44_et_zero <= Y35_et_zero;
		Y35_pos <= Y26_pos;	   
		Y35_neg <= Y26_neg;
		Y35_msb <= Y26_msb;
		Y35_et_zero <= Y26_et_zero;
		Y26_pos <= Y17_pos;	   
		Y26_neg <= Y17_neg;
		Y26_msb <= Y17_msb;
		Y26_et_zero <= Y17_et_zero;
		Y17_pos <= Y18_pos;	   
		Y17_neg <= Y18_neg;
		Y17_msb <= Y18_msb;
		Y17_et_zero <= Y18_et_zero;
		Y18_pos <= Y27_pos;	   
		Y18_neg <= Y27_neg;
		Y18_msb <= Y27_msb;
		Y18_et_zero <= Y27_et_zero;
		Y27_pos <= Y36_pos;	   
		Y27_neg <= Y36_neg;
		Y27_msb <= Y36_msb;
		Y27_et_zero <= Y36_et_zero;
		Y36_pos <= Y45_pos;	   
		Y36_neg <= Y45_neg;
		Y36_msb <= Y45_msb;
		Y36_et_zero <= Y45_et_zero;
		Y45_pos <= Y54_pos;	   
		Y45_neg <= Y54_neg;
		Y45_msb <= Y54_msb;
		Y45_et_zero <= Y54_et_zero;
		Y54_pos <= Y63_pos;	   
		Y54_neg <= Y63_neg;
		Y54_msb <= Y63_msb;
		Y54_et_zero <= Y63_et_zero;
		Y63_pos <= Y72_pos;	   
		Y63_neg <= Y72_neg;
		Y63_msb <= Y72_msb;
		Y63_et_zero <= Y72_et_zero;
		Y72_pos <= Y81_pos;	   
		Y72_neg <= Y81_neg;
		Y72_msb <= Y81_msb;
		Y72_et_zero <= Y81_et_zero;
		Y81_pos <= Y82_pos;	   
		Y81_neg <= Y82_neg;
		Y81_msb <= Y82_msb;
		Y81_et_zero <= Y82_et_zero;
		Y82_pos <= Y73_pos;	   
		Y82_neg <= Y73_neg;
		Y82_msb <= Y73_msb;
		Y82_et_zero <= Y73_et_zero;
		Y73_pos <= Y64_pos;	   
		Y73_neg <= Y64_neg;
		Y73_msb <= Y64_msb;
		Y73_et_zero <= Y64_et_zero;
		Y64_pos <= Y55_pos;	   
		Y64_neg <= Y55_neg;
		Y64_msb <= Y55_msb;
		Y64_et_zero <= Y55_et_zero;
		Y55_pos <= Y46_pos;	   
		Y55_neg <= Y46_neg;
		Y55_msb <= Y46_msb;
		Y55_et_zero <= Y46_et_zero;
		Y46_pos <= Y37_pos;	   
		Y46_neg <= Y37_neg;
		Y46_msb <= Y37_msb;
		Y46_et_zero <= Y37_et_zero;
		Y37_pos <= Y28_pos;	   
		Y37_neg <= Y28_neg;
		Y37_msb <= Y28_msb;
		Y37_et_zero <= Y28_et_zero;
		Y28_pos <= Y38_pos;	   
		Y28_neg <= Y38_neg;
		Y28_msb <= Y38_msb;
		Y28_et_zero <= Y38_et_zero;
		Y38_pos <= Y47_pos;	   
		Y38_neg <= Y47_neg;
		Y38_msb <= Y47_msb;
		Y38_et_zero <= Y47_et_zero;
		Y47_pos <= Y56_pos;	   
		Y47_neg <= Y56_neg;
		Y47_msb <= Y56_msb;
		Y47_et_zero <= Y56_et_zero;
		Y56_pos <= Y65_pos;	   
		Y56_neg <= Y65_neg;
		Y56_msb <= Y65_msb;
		Y56_et_zero <= Y65_et_zero;
		Y65_pos <= Y74_pos;	   
		Y65_neg <= Y74_neg;
		Y65_msb <= Y74_msb;
		Y65_et_zero <= Y74_et_zero;
		Y74_pos <= Y83_pos;	   
		Y74_neg <= Y83_neg;
		Y74_msb <= Y83_msb;
		Y74_et_zero <= Y83_et_zero;
		Y83_pos <= Y84_pos;	   
		Y83_neg <= Y84_neg;
		Y83_msb <= Y84_msb;
		Y83_et_zero <= Y84_et_zero;
		Y84_pos <= Y75_pos;	   
		Y84_neg <= Y75_neg;
		Y84_msb <= Y75_msb;
		Y84_et_zero <= Y75_et_zero;
		Y75_pos <= Y66_pos;	   
		Y75_neg <= Y66_neg;
		Y75_msb <= Y66_msb;
		Y75_et_zero <= Y66_et_zero;
		Y66_pos <= Y57_pos;	   
		Y66_neg <= Y57_neg;
		Y66_msb <= Y57_msb;
		Y66_et_zero <= Y57_et_zero;
		Y57_pos <= Y48_pos;	   
		Y57_neg <= Y48_neg;
		Y57_msb <= Y48_msb;
		Y57_et_zero <= Y48_et_zero;
		Y48_pos <= Y58_pos;	   
		Y48_neg <= Y58_neg;
		Y48_msb <= Y58_msb;
		Y48_et_zero <= Y58_et_zero;
		Y58_pos <= Y67_pos;	   
		Y58_neg <= Y67_neg;
		Y58_msb <= Y67_msb;
		Y58_et_zero <= Y67_et_zero;
		Y67_pos <= Y76_pos;	   
		Y67_neg <= Y76_neg;
		Y67_msb <= Y76_msb;
		Y67_et_zero <= Y76_et_zero;
		Y76_pos <= Y85_pos;	   
		Y76_neg <= Y85_neg;
		Y76_msb <= Y85_msb;
		Y76_et_zero <= Y85_et_zero;
		Y85_pos <= Y86_pos;	   
		Y85_neg <= Y86_neg;
		Y85_msb <= Y86_msb;
		Y85_et_zero <= Y86_et_zero;
		Y86_pos <= Y77_pos;	   
		Y86_neg <= Y77_neg;
		Y86_msb <= Y77_msb;
		Y86_et_zero <= Y77_et_zero;
		Y77_pos <= Y68_pos;	   
		Y77_neg <= Y68_neg;
		Y77_msb <= Y68_msb;
		Y77_et_zero <= Y68_et_zero;
		Y68_pos <= Y78_pos;	   
		Y68_neg <= Y78_neg;
		Y68_msb <= Y78_msb;
		Y68_et_zero <= Y78_et_zero;
		Y78_pos <= Y87_pos;	   
		Y78_neg <= Y87_neg;
		Y78_msb <= Y87_msb;
		Y78_et_zero <= Y87_et_zero;
		Y87_pos <= Y88_pos;	   
		Y87_neg <= Y88_neg;
		Y87_msb <= Y88_msb;
		Y87_et_zero <= Y88_et_zero;
		Y88_pos <= 0;	   
		Y88_neg <= 0;
		Y88_msb <= 0;
		Y88_et_zero <= 1;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin 
		Y11_diff <= 0; Y11_1 <= 0; 
		end
	else if (enable) begin // Need to sign extend Y11 to 12 bits
		Y11_diff <= {Y11[10], Y11} - Y11_previous;
		Y11_1 <= Y11[10] ? { 1'b1, Y11 } : { 1'b0, Y11 };
		end
end	 

always @(posedge clk)
begin
	if (rst) 
		Y11_bits_pos <= 0;
	else if (Y11_1_pos[10] == 1) 
		Y11_bits_pos <= 11;	
	else if (Y11_1_pos[9] == 1) 
		Y11_bits_pos <= 10;
	else if (Y11_1_pos[8] == 1) 
		Y11_bits_pos <= 9;
	else if (Y11_1_pos[7] == 1) 
		Y11_bits_pos <= 8;
	else if (Y11_1_pos[6] == 1) 
		Y11_bits_pos <= 7;
	else if (Y11_1_pos[5] == 1) 
		Y11_bits_pos <= 6;
	else if (Y11_1_pos[4] == 1) 
		Y11_bits_pos <= 5;
	else if (Y11_1_pos[3] == 1) 
		Y11_bits_pos <= 4;
	else if (Y11_1_pos[2] == 1) 
		Y11_bits_pos <= 3;
	else if (Y11_1_pos[1] == 1) 
		Y11_bits_pos <= 2;
	else if (Y11_1_pos[0] == 1) 
		Y11_bits_pos <= 1;
	else 
	 	Y11_bits_pos <= 0;
end

always @(posedge clk)
begin
	if (rst) 
		Y11_bits_neg <= 0;
	else if (Y11_1_neg[10] == 0) 
		Y11_bits_neg <= 11;	
	else if (Y11_1_neg[9] == 0) 
		Y11_bits_neg <= 10;  
	else if (Y11_1_neg[8] == 0) 
		Y11_bits_neg <= 9;   
	else if (Y11_1_neg[7] == 0) 
		Y11_bits_neg <= 8;   
	else if (Y11_1_neg[6] == 0) 
		Y11_bits_neg <= 7;   
	else if (Y11_1_neg[5] == 0) 
		Y11_bits_neg <= 6;   
	else if (Y11_1_neg[4] == 0) 
		Y11_bits_neg <= 5;   
	else if (Y11_1_neg[3] == 0) 
		Y11_bits_neg <= 4;   
	else if (Y11_1_neg[2] == 0) 
		Y11_bits_neg <= 3;   
	else if (Y11_1_neg[1] == 0) 
		Y11_bits_neg <= 2;   
	else if (Y11_1_neg[0] == 0) 
		Y11_bits_neg <= 1;
	else 
	 	Y11_bits_neg <= 0;
end


always @(posedge clk)
begin
	if (rst) 
		Y12_bits_pos <= 0;
	else if (Y12_pos[9] == 1) 
		Y12_bits_pos <= 10;
	else if (Y12_pos[8] == 1) 
		Y12_bits_pos <= 9;
	else if (Y12_pos[7] == 1) 
		Y12_bits_pos <= 8;
	else if (Y12_pos[6] == 1) 
		Y12_bits_pos <= 7;
	else if (Y12_pos[5] == 1) 
		Y12_bits_pos <= 6;
	else if (Y12_pos[4] == 1) 
		Y12_bits_pos <= 5;
	else if (Y12_pos[3] == 1) 
		Y12_bits_pos <= 4;
	else if (Y12_pos[2] == 1) 
		Y12_bits_pos <= 3;
	else if (Y12_pos[1] == 1) 
		Y12_bits_pos <= 2;
	else if (Y12_pos[0] == 1) 
		Y12_bits_pos <= 1;
	else 
	 	Y12_bits_pos <= 0;
end

always @(posedge clk)
begin
	if (rst) 
		Y12_bits_neg <= 0;
	else if (Y12_neg[9] == 0) 
		Y12_bits_neg <= 10;  
	else if (Y12_neg[8] == 0) 
		Y12_bits_neg <= 9;   
	else if (Y12_neg[7] == 0) 
		Y12_bits_neg <= 8;   
	else if (Y12_neg[6] == 0) 
		Y12_bits_neg <= 7;   
	else if (Y12_neg[5] == 0) 
		Y12_bits_neg <= 6;   
	else if (Y12_neg[4] == 0) 
		Y12_bits_neg <= 5;   
	else if (Y12_neg[3] == 0) 
		Y12_bits_neg <= 4;   
	else if (Y12_neg[2] == 0) 
		Y12_bits_neg <= 3;   
	else if (Y12_neg[1] == 0) 
		Y12_bits_neg <= 2;   
	else if (Y12_neg[0] == 0) 
		Y12_bits_neg <= 1;
	else 
	 	Y12_bits_neg <= 0;
end

always @(posedge clk)
begin
	if (rst) begin
		enable_module <= 0; 
		end
	else if (enable) begin
		enable_module <= 1; 
		end
end	 

always @(posedge clk)
begin
	if (rst) begin
		enable_latch_7 <= 0; 
		end
	else if (block_counter == 68)  begin
		enable_latch_7 <= 0; 
		end
	else if (enable_6) begin
		enable_latch_7 <= 1; 
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		enable_latch_8 <= 0; 
		end
	else if (enable_7) begin
		enable_latch_8 <= 1; 
		end
end	

always @(posedge clk)
begin
	if (rst) begin
		enable_1 <= 0; enable_2 <= 0; enable_3 <= 0;
		enable_4 <= 0; enable_5 <= 0; enable_6 <= 0;
		enable_7 <= 0; enable_8 <= 0; enable_9 <= 0;
		enable_10 <= 0; enable_11 <= 0; enable_12 <= 0;
		enable_13 <= 0;
		end
	else begin
		enable_1 <= enable; enable_2 <= enable_1; enable_3 <= enable_2;
		enable_4 <= enable_3; enable_5 <= enable_4; enable_6 <= enable_5;
		enable_7 <= enable_6; enable_8 <= enable_7; enable_9 <= enable_8;
		enable_10 <= enable_9; enable_11 <= enable_10; enable_12 <= enable_11;
		enable_13 <= enable_12;
		end
end	 

/* These Y DC and AC code lengths, run lengths, and bit codes
were created from the Huffman table entries in the JPEG file header.
For different Huffman tables for different images, these values
below will need to be changed.  I created a matlab file to automatically
create these entries from the already encoded JPEG image. This matlab program
won't be any help if you're starting from scratch with a .tif or other
raw image file format.  The values below come from a Huffman table, they
do not actually create the Huffman table based on the probabilities of
each code created from the image data.  You will need another program to
create the optimal Huffman table, or you can go with a generic Huffman table,
which will have slightly less than the best compression.*/


always @(posedge clk)
begin
	Y_DC_code_length[0] <= 2;
Y_DC_code_length[1] <= 2;
Y_DC_code_length[2] <= 2;
Y_DC_code_length[3] <= 3;
Y_DC_code_length[4] <= 4;
Y_DC_code_length[5] <= 5;
Y_DC_code_length[6] <= 6;
Y_DC_code_length[7] <= 7;
Y_DC_code_length[8] <= 8;
Y_DC_code_length[9] <= 9;
Y_DC_code_length[10] <= 10;
Y_DC_code_length[11] <= 11;
Y_DC[0] <= 11'b00000000000;
Y_DC[1] <= 11'b01000000000;
Y_DC[2] <= 11'b10000000000;
Y_DC[3] <= 11'b11000000000;
Y_DC[4] <= 11'b11100000000;
Y_DC[5] <= 11'b11110000000;
Y_DC[6] <= 11'b11111000000;
Y_DC[7] <= 11'b11111100000;
Y_DC[8] <= 11'b11111110000;
Y_DC[9] <= 11'b11111111000;
Y_DC[10] <= 11'b11111111100;
Y_DC[11] <= 11'b11111111110;
Y_AC_code_length[0] <= 2;
Y_AC_code_length[1] <= 2;
Y_AC_code_length[2] <= 3;
Y_AC_code_length[3] <= 4;
Y_AC_code_length[4] <= 4;
Y_AC_code_length[5] <= 4;
Y_AC_code_length[6] <= 5;
Y_AC_code_length[7] <= 5;
Y_AC_code_length[8] <= 5;
Y_AC_code_length[9] <= 6;
Y_AC_code_length[10] <= 6;
Y_AC_code_length[11] <= 7;
Y_AC_code_length[12] <= 7;
Y_AC_code_length[13] <= 7;
Y_AC_code_length[14] <= 7;
Y_AC_code_length[15] <= 8;
Y_AC_code_length[16] <= 8;
Y_AC_code_length[17] <= 8;
Y_AC_code_length[18] <= 9;
Y_AC_code_length[19] <= 9;
Y_AC_code_length[20] <= 9;
Y_AC_code_length[21] <= 9;
Y_AC_code_length[22] <= 9;
Y_AC_code_length[23] <= 10;
Y_AC_code_length[24] <= 10;
Y_AC_code_length[25] <= 10;
Y_AC_code_length[26] <= 10;
Y_AC_code_length[27] <= 10;
Y_AC_code_length[28] <= 11;
Y_AC_code_length[29] <= 11;
Y_AC_code_length[30] <= 11;
Y_AC_code_length[31] <= 11;
Y_AC_code_length[32] <= 12;
Y_AC_code_length[33] <= 12;
Y_AC_code_length[34] <= 12;
Y_AC_code_length[35] <= 12;
Y_AC_code_length[36] <= 15;
Y_AC_code_length[37] <= 16;
Y_AC_code_length[38] <= 16;
Y_AC_code_length[39] <= 16;
Y_AC_code_length[40] <= 16;
Y_AC_code_length[41] <= 16;
Y_AC_code_length[42] <= 16;
Y_AC_code_length[43] <= 16;
Y_AC_code_length[44] <= 16;
Y_AC_code_length[45] <= 16;
Y_AC_code_length[46] <= 16;
Y_AC_code_length[47] <= 16;
Y_AC_code_length[48] <= 16;
Y_AC_code_length[49] <= 16;
Y_AC_code_length[50] <= 16;
Y_AC_code_length[51] <= 16;
Y_AC_code_length[52] <= 16;
Y_AC_code_length[53] <= 16;
Y_AC_code_length[54] <= 16;
Y_AC_code_length[55] <= 16;
Y_AC_code_length[56] <= 16;
Y_AC_code_length[57] <= 16;
Y_AC_code_length[58] <= 16;
Y_AC_code_length[59] <= 16;
Y_AC_code_length[60] <= 16;
Y_AC_code_length[61] <= 16;
Y_AC_code_length[62] <= 16;
Y_AC_code_length[63] <= 16;
Y_AC_code_length[64] <= 16;
Y_AC_code_length[65] <= 16;
Y_AC_code_length[66] <= 16;
Y_AC_code_length[67] <= 16;
Y_AC_code_length[68] <= 16;
Y_AC_code_length[69] <= 16;
Y_AC_code_length[70] <= 16;
Y_AC_code_length[71] <= 16;
Y_AC_code_length[72] <= 16;
Y_AC_code_length[73] <= 16;
Y_AC_code_length[74] <= 16;
Y_AC_code_length[75] <= 16;
Y_AC_code_length[76] <= 16;
Y_AC_code_length[77] <= 16;
Y_AC_code_length[78] <= 16;
Y_AC_code_length[79] <= 16;
Y_AC_code_length[80] <= 16;
Y_AC_code_length[81] <= 16;
Y_AC_code_length[82] <= 16;
Y_AC_code_length[83] <= 16;
Y_AC_code_length[84] <= 16;
Y_AC_code_length[85] <= 16;
Y_AC_code_length[86] <= 16;
Y_AC_code_length[87] <= 16;
Y_AC_code_length[88] <= 16;
Y_AC_code_length[89] <= 16;
Y_AC_code_length[90] <= 16;
Y_AC_code_length[91] <= 16;
Y_AC_code_length[92] <= 16;
Y_AC_code_length[93] <= 16;
Y_AC_code_length[94] <= 16;
Y_AC_code_length[95] <= 16;
Y_AC_code_length[96] <= 16;
Y_AC_code_length[97] <= 16;
Y_AC_code_length[98] <= 16;
Y_AC_code_length[99] <= 16;
Y_AC_code_length[100] <= 16;
Y_AC_code_length[101] <= 16;
Y_AC_code_length[102] <= 16;
Y_AC_code_length[103] <= 16;
Y_AC_code_length[104] <= 16;
Y_AC_code_length[105] <= 16;
Y_AC_code_length[106] <= 16;
Y_AC_code_length[107] <= 16;
Y_AC_code_length[108] <= 16;
Y_AC_code_length[109] <= 16;
Y_AC_code_length[110] <= 16;
Y_AC_code_length[111] <= 16;
Y_AC_code_length[112] <= 16;
Y_AC_code_length[113] <= 16;
Y_AC_code_length[114] <= 16;
Y_AC_code_length[115] <= 16;
Y_AC_code_length[116] <= 16;
Y_AC_code_length[117] <= 16;
Y_AC_code_length[118] <= 16;
Y_AC_code_length[119] <= 16;
Y_AC_code_length[120] <= 16;
Y_AC_code_length[121] <= 16;
Y_AC_code_length[122] <= 16;
Y_AC_code_length[123] <= 16;
Y_AC_code_length[124] <= 16;
Y_AC_code_length[125] <= 16;
Y_AC_code_length[126] <= 16;
Y_AC_code_length[127] <= 16;
Y_AC_code_length[128] <= 16;
Y_AC_code_length[129] <= 16;
Y_AC_code_length[130] <= 16;
Y_AC_code_length[131] <= 16;
Y_AC_code_length[132] <= 16;
Y_AC_code_length[133] <= 16;
Y_AC_code_length[134] <= 16;
Y_AC_code_length[135] <= 16;
Y_AC_code_length[136] <= 16;
Y_AC_code_length[137] <= 16;
Y_AC_code_length[138] <= 16;
Y_AC_code_length[139] <= 16;
Y_AC_code_length[140] <= 16;
Y_AC_code_length[141] <= 16;
Y_AC_code_length[142] <= 16;
Y_AC_code_length[143] <= 16;
Y_AC_code_length[144] <= 16;
Y_AC_code_length[145] <= 16;
Y_AC_code_length[146] <= 16;
Y_AC_code_length[147] <= 16;
Y_AC_code_length[148] <= 16;
Y_AC_code_length[149] <= 16;
Y_AC_code_length[150] <= 16;
Y_AC_code_length[151] <= 16;
Y_AC_code_length[152] <= 16;
Y_AC_code_length[153] <= 16;
Y_AC_code_length[154] <= 16;
Y_AC_code_length[155] <= 16;
Y_AC_code_length[156] <= 16;
Y_AC_code_length[157] <= 16;
Y_AC_code_length[158] <= 16;
Y_AC_code_length[159] <= 16;
Y_AC_code_length[160] <= 16;
Y_AC_code_length[161] <= 16;
Y_AC[0] <= 16'b0000000000000000;
Y_AC[1] <= 16'b0100000000000000;
Y_AC[2] <= 16'b1000000000000000;
Y_AC[3] <= 16'b1010000000000000;
Y_AC[4] <= 16'b1011000000000000;
Y_AC[5] <= 16'b1100000000000000;
Y_AC[6] <= 16'b1101000000000000;
Y_AC[7] <= 16'b1101100000000000;
Y_AC[8] <= 16'b1110000000000000;
Y_AC[9] <= 16'b1110100000000000;
Y_AC[10] <= 16'b1110110000000000;
Y_AC[11] <= 16'b1111000000000000;
Y_AC[12] <= 16'b1111001000000000;
Y_AC[13] <= 16'b1111010000000000;
Y_AC[14] <= 16'b1111011000000000;
Y_AC[15] <= 16'b1111100000000000;
Y_AC[16] <= 16'b1111100100000000;
Y_AC[17] <= 16'b1111101000000000;
Y_AC[18] <= 16'b1111101100000000;
Y_AC[19] <= 16'b1111101110000000;
Y_AC[20] <= 16'b1111110000000000;
Y_AC[21] <= 16'b1111110010000000;
Y_AC[22] <= 16'b1111110100000000;
Y_AC[23] <= 16'b1111110110000000;
Y_AC[24] <= 16'b1111110111000000;
Y_AC[25] <= 16'b1111111000000000;
Y_AC[26] <= 16'b1111111001000000;
Y_AC[27] <= 16'b1111111010000000;
Y_AC[28] <= 16'b1111111011000000;
Y_AC[29] <= 16'b1111111011100000;
Y_AC[30] <= 16'b1111111100000000;
Y_AC[31] <= 16'b1111111100100000;
Y_AC[32] <= 16'b1111111101000000;
Y_AC[33] <= 16'b1111111101010000;
Y_AC[34] <= 16'b1111111101100000;
Y_AC[35] <= 16'b1111111101110000;
Y_AC[36] <= 16'b1111111110000000;
Y_AC[37] <= 16'b1111111110000010;
Y_AC[38] <= 16'b1111111110000011;
Y_AC[39] <= 16'b1111111110000100;
Y_AC[40] <= 16'b1111111110000101;
Y_AC[41] <= 16'b1111111110000110;
Y_AC[42] <= 16'b1111111110000111;
Y_AC[43] <= 16'b1111111110001000;
Y_AC[44] <= 16'b1111111110001001;
Y_AC[45] <= 16'b1111111110001010;
Y_AC[46] <= 16'b1111111110001011;
Y_AC[47] <= 16'b1111111110001100;
Y_AC[48] <= 16'b1111111110001101;
Y_AC[49] <= 16'b1111111110001110;
Y_AC[50] <= 16'b1111111110001111;
Y_AC[51] <= 16'b1111111110010000;
Y_AC[52] <= 16'b1111111110010001;
Y_AC[53] <= 16'b1111111110010010;
Y_AC[54] <= 16'b1111111110010011;
Y_AC[55] <= 16'b1111111110010100;
Y_AC[56] <= 16'b1111111110010101;
Y_AC[57] <= 16'b1111111110010110;
Y_AC[58] <= 16'b1111111110010111;
Y_AC[59] <= 16'b1111111110011000;
Y_AC[60] <= 16'b1111111110011001;
Y_AC[61] <= 16'b1111111110011010;
Y_AC[62] <= 16'b1111111110011011;
Y_AC[63] <= 16'b1111111110011100;
Y_AC[64] <= 16'b1111111110011101;
Y_AC[65] <= 16'b1111111110011110;
Y_AC[66] <= 16'b1111111110011111;
Y_AC[67] <= 16'b1111111110100000;
Y_AC[68] <= 16'b1111111110100001;
Y_AC[69] <= 16'b1111111110100010;
Y_AC[70] <= 16'b1111111110100011;
Y_AC[71] <= 16'b1111111110100100;
Y_AC[72] <= 16'b1111111110100101;
Y_AC[73] <= 16'b1111111110100110;
Y_AC[74] <= 16'b1111111110100111;
Y_AC[75] <= 16'b1111111110101000;
Y_AC[76] <= 16'b1111111110101001;
Y_AC[77] <= 16'b1111111110101010;
Y_AC[78] <= 16'b1111111110101011;
Y_AC[79] <= 16'b1111111110101100;
Y_AC[80] <= 16'b1111111110101101;
Y_AC[81] <= 16'b1111111110101110;
Y_AC[82] <= 16'b1111111110101111;
Y_AC[83] <= 16'b1111111110110000;
Y_AC[84] <= 16'b1111111110110001;
Y_AC[85] <= 16'b1111111110110010;
Y_AC[86] <= 16'b1111111110110011;
Y_AC[87] <= 16'b1111111110110100;
Y_AC[88] <= 16'b1111111110110101;
Y_AC[89] <= 16'b1111111110110110;
Y_AC[90] <= 16'b1111111110110111;
Y_AC[91] <= 16'b1111111110111000;
Y_AC[92] <= 16'b1111111110111001;
Y_AC[93] <= 16'b1111111110111010;
Y_AC[94] <= 16'b1111111110111011;
Y_AC[95] <= 16'b1111111110111100;
Y_AC[96] <= 16'b1111111110111101;
Y_AC[97] <= 16'b1111111110111110;
Y_AC[98] <= 16'b1111111110111111;
Y_AC[99] <= 16'b1111111111000000;
Y_AC[100] <= 16'b1111111111000001;
Y_AC[101] <= 16'b1111111111000010;
Y_AC[102] <= 16'b1111111111000011;
Y_AC[103] <= 16'b1111111111000100;
Y_AC[104] <= 16'b1111111111000101;
Y_AC[105] <= 16'b1111111111000110;
Y_AC[106] <= 16'b1111111111000111;
Y_AC[107] <= 16'b1111111111001000;
Y_AC[108] <= 16'b1111111111001001;
Y_AC[109] <= 16'b1111111111001010;
Y_AC[110] <= 16'b1111111111001011;
Y_AC[111] <= 16'b1111111111001100;
Y_AC[112] <= 16'b1111111111001101;
Y_AC[113] <= 16'b1111111111001110;
Y_AC[114] <= 16'b1111111111001111;
Y_AC[115] <= 16'b1111111111010000;
Y_AC[116] <= 16'b1111111111010001;
Y_AC[117] <= 16'b1111111111010010;
Y_AC[118] <= 16'b1111111111010011;
Y_AC[119] <= 16'b1111111111010100;
Y_AC[120] <= 16'b1111111111010101;
Y_AC[121] <= 16'b1111111111010110;
Y_AC[122] <= 16'b1111111111010111;
Y_AC[123] <= 16'b1111111111011000;
Y_AC[124] <= 16'b1111111111011001;
Y_AC[125] <= 16'b1111111111011010;
Y_AC[126] <= 16'b1111111111011011;
Y_AC[127] <= 16'b1111111111011100;
Y_AC[128] <= 16'b1111111111011101;
Y_AC[129] <= 16'b1111111111011110;
Y_AC[130] <= 16'b1111111111011111;
Y_AC[131] <= 16'b1111111111100000;
Y_AC[132] <= 16'b1111111111100001;
Y_AC[133] <= 16'b1111111111100010;
Y_AC[134] <= 16'b1111111111100011;
Y_AC[135] <= 16'b1111111111100100;
Y_AC[136] <= 16'b1111111111100101;
Y_AC[137] <= 16'b1111111111100110;
Y_AC[138] <= 16'b1111111111100111;
Y_AC[139] <= 16'b1111111111101000;
Y_AC[140] <= 16'b1111111111101001;
Y_AC[141] <= 16'b1111111111101010;
Y_AC[142] <= 16'b1111111111101011;
Y_AC[143] <= 16'b1111111111101100;
Y_AC[144] <= 16'b1111111111101101;
Y_AC[145] <= 16'b1111111111101110;
Y_AC[146] <= 16'b1111111111101111;
Y_AC[147] <= 16'b1111111111110000;
Y_AC[148] <= 16'b1111111111110001;
Y_AC[149] <= 16'b1111111111110010;
Y_AC[150] <= 16'b1111111111110011;
Y_AC[151] <= 16'b1111111111110100;
Y_AC[152] <= 16'b1111111111110101;
Y_AC[153] <= 16'b1111111111110110;
Y_AC[154] <= 16'b1111111111110111;
Y_AC[155] <= 16'b1111111111111000;
Y_AC[156] <= 16'b1111111111111001;
Y_AC[157] <= 16'b1111111111111010;
Y_AC[158] <= 16'b1111111111111011;
Y_AC[159] <= 16'b1111111111111100;
Y_AC[160] <= 16'b1111111111111101;
Y_AC[161] <= 16'b1111111111111110;
Y_AC_run_code[1] <= 0;
Y_AC_run_code[2] <= 1;
Y_AC_run_code[3] <= 2;
Y_AC_run_code[0] <= 3;
Y_AC_run_code[4] <= 4;
Y_AC_run_code[17] <= 5;
Y_AC_run_code[5] <= 6;
Y_AC_run_code[18] <= 7;
Y_AC_run_code[33] <= 8;
Y_AC_run_code[49] <= 9;
Y_AC_run_code[65] <= 10;
Y_AC_run_code[6] <= 11;
Y_AC_run_code[19] <= 12;
Y_AC_run_code[81] <= 13;
Y_AC_run_code[97] <= 14;
Y_AC_run_code[7] <= 15;
Y_AC_run_code[34] <= 16;
Y_AC_run_code[113] <= 17;
Y_AC_run_code[20] <= 18;
Y_AC_run_code[50] <= 19;
Y_AC_run_code[129] <= 20;
Y_AC_run_code[145] <= 21;
Y_AC_run_code[161] <= 22;
Y_AC_run_code[8] <= 23;
Y_AC_run_code[35] <= 24;
Y_AC_run_code[66] <= 25;
Y_AC_run_code[177] <= 26;
Y_AC_run_code[193] <= 27;
Y_AC_run_code[21] <= 28;
Y_AC_run_code[82] <= 29;
Y_AC_run_code[209] <= 30;
Y_AC_run_code[240] <= 31;
Y_AC_run_code[36] <= 32;
Y_AC_run_code[51] <= 33;
Y_AC_run_code[98] <= 34;
Y_AC_run_code[114] <= 35;
Y_AC_run_code[130] <= 36;
Y_AC_run_code[9] <= 37;
Y_AC_run_code[10] <= 38;
Y_AC_run_code[22] <= 39;
Y_AC_run_code[23] <= 40;
Y_AC_run_code[24] <= 41;
Y_AC_run_code[25] <= 42;
Y_AC_run_code[26] <= 43;
Y_AC_run_code[37] <= 44;
Y_AC_run_code[38] <= 45;
Y_AC_run_code[39] <= 46;
Y_AC_run_code[40] <= 47;
Y_AC_run_code[41] <= 48;
Y_AC_run_code[42] <= 49;
Y_AC_run_code[52] <= 50;
Y_AC_run_code[53] <= 51;
Y_AC_run_code[54] <= 52;
Y_AC_run_code[55] <= 53;
Y_AC_run_code[56] <= 54;
Y_AC_run_code[57] <= 55;
Y_AC_run_code[58] <= 56;
Y_AC_run_code[67] <= 57;
Y_AC_run_code[68] <= 58;
Y_AC_run_code[69] <= 59;
Y_AC_run_code[70] <= 60;
Y_AC_run_code[71] <= 61;
Y_AC_run_code[72] <= 62;
Y_AC_run_code[73] <= 63;
Y_AC_run_code[74] <= 64;
Y_AC_run_code[83] <= 65;
Y_AC_run_code[84] <= 66;
Y_AC_run_code[85] <= 67;
Y_AC_run_code[86] <= 68;
Y_AC_run_code[87] <= 69;
Y_AC_run_code[88] <= 70;
Y_AC_run_code[89] <= 71;
Y_AC_run_code[90] <= 72;
Y_AC_run_code[99] <= 73;
Y_AC_run_code[100] <= 74;
Y_AC_run_code[101] <= 75;
Y_AC_run_code[102] <= 76;
Y_AC_run_code[103] <= 77;
Y_AC_run_code[104] <= 78;
Y_AC_run_code[105] <= 79;
Y_AC_run_code[106] <= 80;
Y_AC_run_code[115] <= 81;
Y_AC_run_code[116] <= 82;
Y_AC_run_code[117] <= 83;
Y_AC_run_code[118] <= 84;
Y_AC_run_code[119] <= 85;
Y_AC_run_code[120] <= 86;
Y_AC_run_code[121] <= 87;
Y_AC_run_code[122] <= 88;
Y_AC_run_code[131] <= 89;
Y_AC_run_code[132] <= 90;
Y_AC_run_code[133] <= 91;
Y_AC_run_code[134] <= 92;
Y_AC_run_code[135] <= 93;
Y_AC_run_code[136] <= 94;
Y_AC_run_code[137] <= 95;
Y_AC_run_code[138] <= 96;
Y_AC_run_code[146] <= 97;
Y_AC_run_code[147] <= 98;
Y_AC_run_code[148] <= 99;
Y_AC_run_code[149] <= 100;
Y_AC_run_code[150] <= 101;
Y_AC_run_code[151] <= 102;
Y_AC_run_code[152] <= 103;
Y_AC_run_code[153] <= 104;
Y_AC_run_code[154] <= 105;
Y_AC_run_code[162] <= 106;
Y_AC_run_code[163] <= 107;
Y_AC_run_code[164] <= 108;
Y_AC_run_code[165] <= 109;
Y_AC_run_code[166] <= 110;
Y_AC_run_code[167] <= 111;
Y_AC_run_code[168] <= 112;
Y_AC_run_code[169] <= 113;
Y_AC_run_code[170] <= 114;
Y_AC_run_code[178] <= 115;
Y_AC_run_code[179] <= 116;
Y_AC_run_code[180] <= 117;
Y_AC_run_code[181] <= 118;
Y_AC_run_code[182] <= 119;
Y_AC_run_code[183] <= 120;
Y_AC_run_code[184] <= 121;
Y_AC_run_code[185] <= 122;
Y_AC_run_code[186] <= 123;
Y_AC_run_code[194] <= 124;
Y_AC_run_code[195] <= 125;
Y_AC_run_code[196] <= 126;
Y_AC_run_code[197] <= 127;
Y_AC_run_code[198] <= 128;
Y_AC_run_code[199] <= 129;
Y_AC_run_code[200] <= 130;
Y_AC_run_code[201] <= 131;
Y_AC_run_code[202] <= 132;
Y_AC_run_code[210] <= 133;
Y_AC_run_code[211] <= 134;
Y_AC_run_code[212] <= 135;
Y_AC_run_code[213] <= 136;
Y_AC_run_code[214] <= 137;
Y_AC_run_code[215] <= 138;
Y_AC_run_code[216] <= 139;
Y_AC_run_code[217] <= 140;
Y_AC_run_code[218] <= 141;
Y_AC_run_code[225] <= 142;
Y_AC_run_code[226] <= 143;
Y_AC_run_code[227] <= 144;
Y_AC_run_code[228] <= 145;
Y_AC_run_code[229] <= 146;
Y_AC_run_code[230] <= 147;
Y_AC_run_code[231] <= 148;
Y_AC_run_code[232] <= 149;
Y_AC_run_code[233] <= 150;
Y_AC_run_code[234] <= 151;
Y_AC_run_code[241] <= 152;
Y_AC_run_code[242] <= 153;
Y_AC_run_code[243] <= 154;
Y_AC_run_code[244] <= 155;
Y_AC_run_code[245] <= 156;
Y_AC_run_code[246] <= 157;
Y_AC_run_code[247] <= 158;
Y_AC_run_code[248] <= 159;
Y_AC_run_code[249] <= 160;
Y_AC_run_code[250] <= 161;
	Y_AC_run_code[16] <= 0;
	Y_AC_run_code[32] <= 0;
	Y_AC_run_code[48] <= 0;
	Y_AC_run_code[64] <= 0;
	Y_AC_run_code[80] <= 0;
	Y_AC_run_code[96] <= 0;
	Y_AC_run_code[112] <= 0;
	Y_AC_run_code[128] <= 0;
	Y_AC_run_code[144] <= 0;
	Y_AC_run_code[160] <= 0;
	Y_AC_run_code[176] <= 0;
	Y_AC_run_code[192] <= 0;
	Y_AC_run_code[208] <= 0;
	Y_AC_run_code[224] <= 0;
end	


always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[31] <= 0;
	else if (enable_module && rollover_7) 
		JPEG_bitstream[31] <= JPEG_bs_5[31];
	else if (enable_module && orc_8 == 0) 
		JPEG_bitstream[31] <= JPEG_bs_5[31];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[30] <= 0;
	else if (enable_module && rollover_7) 
		JPEG_bitstream[30] <= JPEG_bs_5[30];
	else if (enable_module && orc_8 <= 1) 
		JPEG_bitstream[30] <= JPEG_bs_5[30];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[29] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[29] <= JPEG_bs_5[29];
	else if (enable_module && orc_8 <= 2) 
		JPEG_bitstream[29] <= JPEG_bs_5[29];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[28] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[28] <= JPEG_bs_5[28];
	else if (enable_module && orc_8 <= 3) 
		JPEG_bitstream[28] <= JPEG_bs_5[28];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[27] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[27] <= JPEG_bs_5[27];
	else if (enable_module && orc_8 <= 4) 
		JPEG_bitstream[27] <= JPEG_bs_5[27];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[26] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[26] <= JPEG_bs_5[26];
	else if (enable_module && orc_8 <= 5) 
		JPEG_bitstream[26] <= JPEG_bs_5[26];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[25] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[25] <= JPEG_bs_5[25];
	else if (enable_module && orc_8 <= 6) 
		JPEG_bitstream[25] <= JPEG_bs_5[25];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[24] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[24] <= JPEG_bs_5[24];
	else if (enable_module && orc_8 <= 7) 
		JPEG_bitstream[24] <= JPEG_bs_5[24];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[23] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[23] <= JPEG_bs_5[23];
	else if (enable_module && orc_8 <= 8) 
		JPEG_bitstream[23] <= JPEG_bs_5[23];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[22] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[22] <= JPEG_bs_5[22];
	else if (enable_module && orc_8 <= 9) 
		JPEG_bitstream[22] <= JPEG_bs_5[22];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[21] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[21] <= JPEG_bs_5[21];
	else if (enable_module && orc_8 <= 10) 
		JPEG_bitstream[21] <= JPEG_bs_5[21];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[20] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[20] <= JPEG_bs_5[20];
	else if (enable_module && orc_8 <= 11) 
		JPEG_bitstream[20] <= JPEG_bs_5[20];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[19] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[19] <= JPEG_bs_5[19];
	else if (enable_module && orc_8 <= 12) 
		JPEG_bitstream[19] <= JPEG_bs_5[19];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[18] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[18] <= JPEG_bs_5[18];
	else if (enable_module && orc_8 <= 13) 
		JPEG_bitstream[18] <= JPEG_bs_5[18];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[17] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[17] <= JPEG_bs_5[17];
	else if (enable_module && orc_8 <= 14) 
		JPEG_bitstream[17] <= JPEG_bs_5[17];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[16] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[16] <= JPEG_bs_5[16];
	else if (enable_module && orc_8 <= 15) 
		JPEG_bitstream[16] <= JPEG_bs_5[16];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[15] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[15] <= JPEG_bs_5[15];
	else if (enable_module && orc_8 <= 16) 
		JPEG_bitstream[15] <= JPEG_bs_5[15];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[14] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[14] <= JPEG_bs_5[14];
	else if (enable_module && orc_8 <= 17) 
		JPEG_bitstream[14] <= JPEG_bs_5[14];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[13] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[13] <= JPEG_bs_5[13];
	else if (enable_module && orc_8 <= 18) 
		JPEG_bitstream[13] <= JPEG_bs_5[13];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[12] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[12] <= JPEG_bs_5[12];
	else if (enable_module && orc_8 <= 19) 
		JPEG_bitstream[12] <= JPEG_bs_5[12];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[11] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[11] <= JPEG_bs_5[11];
	else if (enable_module && orc_8 <= 20) 
		JPEG_bitstream[11] <= JPEG_bs_5[11];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[10] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[10] <= JPEG_bs_5[10];
	else if (enable_module && orc_8 <= 21) 
		JPEG_bitstream[10] <= JPEG_bs_5[10];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[9] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[9] <= JPEG_bs_5[9];
	else if (enable_module && orc_8 <= 22) 
		JPEG_bitstream[9] <= JPEG_bs_5[9];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[8] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[8] <= JPEG_bs_5[8];
	else if (enable_module && orc_8 <= 23) 
		JPEG_bitstream[8] <= JPEG_bs_5[8];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[7] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[7] <= JPEG_bs_5[7];
	else if (enable_module && orc_8 <= 24) 
		JPEG_bitstream[7] <= JPEG_bs_5[7];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[6] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[6] <= JPEG_bs_5[6];
	else if (enable_module && orc_8 <= 25) 
		JPEG_bitstream[6] <= JPEG_bs_5[6];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[5] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[5] <= JPEG_bs_5[5];
	else if (enable_module && orc_8 <= 26) 
		JPEG_bitstream[5] <= JPEG_bs_5[5];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[4] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[4] <= JPEG_bs_5[4];
	else if (enable_module && orc_8 <= 27) 
		JPEG_bitstream[4] <= JPEG_bs_5[4];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[3] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[3] <= JPEG_bs_5[3];
	else if (enable_module && orc_8 <= 28) 
		JPEG_bitstream[3] <= JPEG_bs_5[3];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[2] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[2] <= JPEG_bs_5[2];
	else if (enable_module && orc_8 <= 29) 
		JPEG_bitstream[2] <= JPEG_bs_5[2];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[1] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[1] <= JPEG_bs_5[1];
	else if (enable_module && orc_8 <= 30) 
		JPEG_bitstream[1] <= JPEG_bs_5[1];
end

always @(posedge clk)
begin
	if (rst) 
		JPEG_bitstream[0] <= 0;
	else if (enable_module && rollover_7)
		JPEG_bitstream[0] <= JPEG_bs_5[0];
	else if (enable_module && orc_8 <= 31) 
		JPEG_bitstream[0] <= JPEG_bs_5[0];
end
endmodule
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  JPEG Encoder Core - Verilog                                ////
////                                                             ////
////  Author: David Lundgren                                     ////
////          davidklun@gmail.com                                ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2009 David Lundgren                           ////
////                  davidklun@gmail.com                        ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

/* This module comes after the dct module.  The 64 matrix entries calculated after
performing the 2D DCT are inputs to this quantization module.  This module quantizes
the entire 8x8 block of Y values.  The outputs from this module
are the quantized Y values for one 8x8 block. */

`timescale 1ns / 100ps

module y_quantizer(clk, rst, enable,
Z11, Z12, Z13, Z14, Z15, Z16, Z17, Z18, Z21, Z22, Z23, Z24, Z25, Z26, Z27, Z28,
Z31, Z32, Z33, Z34, Z35, Z36, Z37, Z38, Z41, Z42, Z43, Z44, Z45, Z46, Z47, Z48,
Z51, Z52, Z53, Z54, Z55, Z56, Z57, Z58, Z61, Z62, Z63, Z64, Z65, Z66, Z67, Z68,
Z71, Z72, Z73, Z74, Z75, Z76, Z77, Z78, Z81, Z82, Z83, Z84, Z85, Z86, Z87, Z88,
Q11, Q12, Q13, Q14, Q15, Q16, Q17, Q18, Q21, Q22, Q23, Q24, Q25, Q26, Q27, Q28,
Q31, Q32, Q33, Q34, Q35, Q36, Q37, Q38, Q41, Q42, Q43, Q44, Q45, Q46, Q47, Q48,
Q51, Q52, Q53, Q54, Q55, Q56, Q57, Q58, Q61, Q62, Q63, Q64, Q65, Q66, Q67, Q68,
Q71, Q72, Q73, Q74, Q75, Q76, Q77, Q78, Q81, Q82, Q83, Q84, Q85, Q86, Q87, Q88,
out_enable);
input		clk;
input		rst;
input		enable;
input  [10:0]  Z11, Z12, Z13, Z14, Z15, Z16, Z17, Z18, Z21, Z22, Z23, Z24;
input  [10:0]  Z25, Z26, Z27, Z28, Z31, Z32, Z33, Z34, Z35, Z36, Z37, Z38;
input  [10:0]  Z41, Z42, Z43, Z44, Z45, Z46, Z47, Z48, Z51, Z52, Z53, Z54;
input  [10:0]  Z55, Z56, Z57, Z58, Z61, Z62, Z63, Z64, Z65, Z66, Z67, Z68;
input  [10:0]  Z71, Z72, Z73, Z74, Z75, Z76, Z77, Z78, Z81, Z82, Z83, Z84;
input  [10:0]  Z85, Z86, Z87, Z88;
output  [10:0]  Q11, Q12, Q13, Q14, Q15, Q16, Q17, Q18, Q21, Q22, Q23, Q24;
output  [10:0]  Q25, Q26, Q27, Q28, Q31, Q32, Q33, Q34, Q35, Q36, Q37, Q38;
output  [10:0]  Q41, Q42, Q43, Q44, Q45, Q46, Q47, Q48, Q51, Q52, Q53, Q54;
output  [10:0]  Q55, Q56, Q57, Q58, Q61, Q62, Q63, Q64, Q65, Q66, Q67, Q68;
output  [10:0]  Q71, Q72, Q73, Q74, Q75, Q76, Q77, Q78, Q81, Q82, Q83, Q84;
output  [10:0]  Q85, Q86, Q87, Q88;
output		out_enable;

/* Below are the quantization values, these can be changed for different 
quantization levels. */

parameter Q1_1	= 1;
parameter Q1_2	= 1;
parameter Q1_3	= 1;
parameter Q1_4	= 1;
parameter Q1_5	= 1;
parameter Q1_6	= 1;
parameter Q1_7	= 1;
parameter Q1_8	= 1;
parameter Q2_1	= 1;
parameter Q2_2	= 1;
parameter Q2_3	= 1;
parameter Q2_4	= 1;
parameter Q2_5	= 1;
parameter Q2_6	= 1;
parameter Q2_7	= 1;
parameter Q2_8	= 1;
parameter Q3_1	= 1;
parameter Q3_2	= 1;
parameter Q3_3	= 1;
parameter Q3_4	= 1;
parameter Q3_5	= 1;
parameter Q3_6	= 1;
parameter Q3_7	= 1;
parameter Q3_8	= 1;
parameter Q4_1	= 1;
parameter Q4_2	= 1;
parameter Q4_3	= 1;
parameter Q4_4	= 1;
parameter Q4_5	= 1;
parameter Q4_6	= 1;
parameter Q4_7	= 1;
parameter Q4_8	= 1;
parameter Q5_1	= 1;
parameter Q5_2	= 1;
parameter Q5_3	= 1;
parameter Q5_4	= 1;
parameter Q5_5	= 1;
parameter Q5_6	= 1;
parameter Q5_7	= 1;
parameter Q5_8	= 1;
parameter Q6_1	= 1;
parameter Q6_2	= 1;
parameter Q6_3	= 1;
parameter Q6_4	= 1;
parameter Q6_5	= 1;
parameter Q6_6	= 1;
parameter Q6_7	= 1;
parameter Q6_8	= 1;
parameter Q7_1	= 1;
parameter Q7_2	= 1;
parameter Q7_3	= 1;
parameter Q7_4	= 1;
parameter Q7_5	= 1;
parameter Q7_6	= 1;
parameter Q7_7	= 1;
parameter Q7_8	= 1;
parameter Q8_1	= 1;
parameter Q8_2	= 1;
parameter Q8_3	= 1;
parameter Q8_4	= 1;
parameter Q8_5	= 1;
parameter Q8_6	= 1;
parameter Q8_7	= 1;
parameter Q8_8	= 1;
// End of Quantization Values

/* The following parameters hold the values of 4096 divided by the corresponding 
individual quantization values.  These values are needed to get around
actually dividing the Y, Cb, and Cr values by the quantization values.
Instead, you can multiply by the values below, and then divide by 4096
to get the same result.  And 4096 = 2^12, so instead of dividing, you can
just shift the bottom 12 bits out.  This is a lossy process, as 4096/Q divided
by 4096 doesn't always equal the same value as if you were just dividing by Q.  But
the quantization process is also lossy, so the additional loss of precision is
negligible.  To decrease the loss, you could use a larger number than 4096 to 
get around the actual use of division.  Like take 8192/Q and then divide by 8192.*/

parameter QQ1_1	= 4096/Q1_1;
parameter QQ1_2	= 4096/Q1_2;
parameter QQ1_3	= 4096/Q1_3;
parameter QQ1_4	= 4096/Q1_4;
parameter QQ1_5	= 4096/Q1_5;
parameter QQ1_6	= 4096/Q1_6;
parameter QQ1_7	= 4096/Q1_7;
parameter QQ1_8	= 4096/Q1_8;
parameter QQ2_1	= 4096/Q2_1;
parameter QQ2_2	= 4096/Q2_2;
parameter QQ2_3	= 4096/Q2_3;
parameter QQ2_4	= 4096/Q2_4;
parameter QQ2_5	= 4096/Q2_5;
parameter QQ2_6	= 4096/Q2_6;
parameter QQ2_7	= 4096/Q2_7;
parameter QQ2_8	= 4096/Q2_8;
parameter QQ3_1	= 4096/Q3_1;
parameter QQ3_2	= 4096/Q3_2;
parameter QQ3_3	= 4096/Q3_3;
parameter QQ3_4	= 4096/Q3_4;
parameter QQ3_5	= 4096/Q3_5;
parameter QQ3_6	= 4096/Q3_6;
parameter QQ3_7	= 4096/Q3_7;
parameter QQ3_8	= 4096/Q3_8;
parameter QQ4_1	= 4096/Q4_1;
parameter QQ4_2	= 4096/Q4_2;
parameter QQ4_3	= 4096/Q4_3;
parameter QQ4_4	= 4096/Q4_4;
parameter QQ4_5	= 4096/Q4_5;
parameter QQ4_6	= 4096/Q4_6;
parameter QQ4_7	= 4096/Q4_7;
parameter QQ4_8	= 4096/Q4_8;
parameter QQ5_1	= 4096/Q5_1;
parameter QQ5_2	= 4096/Q5_2;
parameter QQ5_3	= 4096/Q5_3;
parameter QQ5_4	= 4096/Q5_4;
parameter QQ5_5	= 4096/Q5_5;
parameter QQ5_6	= 4096/Q5_6;
parameter QQ5_7	= 4096/Q5_7;
parameter QQ5_8	= 4096/Q5_8;
parameter QQ6_1	= 4096/Q6_1;
parameter QQ6_2	= 4096/Q6_2;
parameter QQ6_3	= 4096/Q6_3;
parameter QQ6_4	= 4096/Q6_4;
parameter QQ6_5	= 4096/Q6_5;
parameter QQ6_6	= 4096/Q6_6;
parameter QQ6_7	= 4096/Q6_7;
parameter QQ6_8	= 4096/Q6_8;
parameter QQ7_1	= 4096/Q7_1;
parameter QQ7_2	= 4096/Q7_2;
parameter QQ7_3	= 4096/Q7_3;
parameter QQ7_4	= 4096/Q7_4;
parameter QQ7_5	= 4096/Q7_5;
parameter QQ7_6	= 4096/Q7_6;
parameter QQ7_7	= 4096/Q7_7;
parameter QQ7_8	= 4096/Q7_8;
parameter QQ8_1	= 4096/Q8_1;
parameter QQ8_2	= 4096/Q8_2;
parameter QQ8_3	= 4096/Q8_3;
parameter QQ8_4	= 4096/Q8_4;
parameter QQ8_5	= 4096/Q8_5;
parameter QQ8_6	= 4096/Q8_6;
parameter QQ8_7	= 4096/Q8_7;
parameter QQ8_8	= 4096/Q8_8;

wire [12:0] QM1_1 = QQ1_1;
wire [12:0] QM1_2 = QQ1_2;
wire [12:0] QM1_3 = QQ1_3;
wire [12:0] QM1_4 = QQ1_4;
wire [12:0] QM1_5 = QQ1_5;
wire [12:0] QM1_6 = QQ1_6;
wire [12:0] QM1_7 = QQ1_7;
wire [12:0] QM1_8 = QQ1_8;
wire [12:0] QM2_1 = QQ2_1;
wire [12:0] QM2_2 = QQ2_2;
wire [12:0] QM2_3 = QQ2_3;
wire [12:0] QM2_4 = QQ2_4;
wire [12:0] QM2_5 = QQ2_5;
wire [12:0] QM2_6 = QQ2_6;
wire [12:0] QM2_7 = QQ2_7;
wire [12:0] QM2_8 = QQ2_8;
wire [12:0] QM3_1 = QQ3_1;
wire [12:0] QM3_2 = QQ3_2;
wire [12:0] QM3_3 = QQ3_3;
wire [12:0] QM3_4 = QQ3_4;
wire [12:0] QM3_5 = QQ3_5;
wire [12:0] QM3_6 = QQ3_6;
wire [12:0] QM3_7 = QQ3_7;
wire [12:0] QM3_8 = QQ3_8;
wire [12:0] QM4_1 = QQ4_1;
wire [12:0] QM4_2 = QQ4_2;
wire [12:0] QM4_3 = QQ4_3;
wire [12:0] QM4_4 = QQ4_4;
wire [12:0] QM4_5 = QQ4_5;
wire [12:0] QM4_6 = QQ4_6;
wire [12:0] QM4_7 = QQ4_7;
wire [12:0] QM4_8 = QQ4_8;
wire [12:0] QM5_1 = QQ5_1;
wire [12:0] QM5_2 = QQ5_2;
wire [12:0] QM5_3 = QQ5_3;
wire [12:0] QM5_4 = QQ5_4;
wire [12:0] QM5_5 = QQ5_5;
wire [12:0] QM5_6 = QQ5_6;
wire [12:0] QM5_7 = QQ5_7;
wire [12:0] QM5_8 = QQ5_8;
wire [12:0] QM6_1 = QQ6_1;
wire [12:0] QM6_2 = QQ6_2;
wire [12:0] QM6_3 = QQ6_3;
wire [12:0] QM6_4 = QQ6_4;
wire [12:0] QM6_5 = QQ6_5;
wire [12:0] QM6_6 = QQ6_6;
wire [12:0] QM6_7 = QQ6_7;
wire [12:0] QM6_8 = QQ6_8;
wire [12:0] QM7_1 = QQ7_1;
wire [12:0] QM7_2 = QQ7_2;
wire [12:0] QM7_3 = QQ7_3;
wire [12:0] QM7_4 = QQ7_4;
wire [12:0] QM7_5 = QQ7_5;
wire [12:0] QM7_6 = QQ7_6;
wire [12:0] QM7_7 = QQ7_7;
wire [12:0] QM7_8 = QQ7_8;
wire [12:0] QM8_1 = QQ8_1;
wire [12:0] QM8_2 = QQ8_2;
wire [12:0] QM8_3 = QQ8_3;
wire [12:0] QM8_4 = QQ8_4;
wire [12:0] QM8_5 = QQ8_5;
wire [12:0] QM8_6 = QQ8_6;
wire [12:0] QM8_7 = QQ8_7;
wire [12:0] QM8_8 = QQ8_8;
reg [22:0] Z11_temp, Z12_temp, Z13_temp, Z14_temp, Z15_temp, Z16_temp, Z17_temp, Z18_temp;
reg [22:0] Z21_temp, Z22_temp, Z23_temp, Z24_temp, Z25_temp, Z26_temp, Z27_temp, Z28_temp;
reg [22:0] Z31_temp, Z32_temp, Z33_temp, Z34_temp, Z35_temp, Z36_temp, Z37_temp, Z38_temp;
reg [22:0] Z41_temp, Z42_temp, Z43_temp, Z44_temp, Z45_temp, Z46_temp, Z47_temp, Z48_temp;
reg [22:0] Z51_temp, Z52_temp, Z53_temp, Z54_temp, Z55_temp, Z56_temp, Z57_temp, Z58_temp;
reg [22:0] Z61_temp, Z62_temp, Z63_temp, Z64_temp, Z65_temp, Z66_temp, Z67_temp, Z68_temp;
reg [22:0] Z71_temp, Z72_temp, Z73_temp, Z74_temp, Z75_temp, Z76_temp, Z77_temp, Z78_temp;
reg [22:0] Z81_temp, Z82_temp, Z83_temp, Z84_temp, Z85_temp, Z86_temp, Z87_temp, Z88_temp;
reg [22:0] Z11_temp_1, Z12_temp_1, Z13_temp_1, Z14_temp_1, Z15_temp_1, Z16_temp_1, Z17_temp_1, Z18_temp_1;
reg [22:0] Z21_temp_1, Z22_temp_1, Z23_temp_1, Z24_temp_1, Z25_temp_1, Z26_temp_1, Z27_temp_1, Z28_temp_1;
reg [22:0] Z31_temp_1, Z32_temp_1, Z33_temp_1, Z34_temp_1, Z35_temp_1, Z36_temp_1, Z37_temp_1, Z38_temp_1;
reg [22:0] Z41_temp_1, Z42_temp_1, Z43_temp_1, Z44_temp_1, Z45_temp_1, Z46_temp_1, Z47_temp_1, Z48_temp_1;
reg [22:0] Z51_temp_1, Z52_temp_1, Z53_temp_1, Z54_temp_1, Z55_temp_1, Z56_temp_1, Z57_temp_1, Z58_temp_1;
reg [22:0] Z61_temp_1, Z62_temp_1, Z63_temp_1, Z64_temp_1, Z65_temp_1, Z66_temp_1, Z67_temp_1, Z68_temp_1;
reg [22:0] Z71_temp_1, Z72_temp_1, Z73_temp_1, Z74_temp_1, Z75_temp_1, Z76_temp_1, Z77_temp_1, Z78_temp_1;
reg [22:0] Z81_temp_1, Z82_temp_1, Z83_temp_1, Z84_temp_1, Z85_temp_1, Z86_temp_1, Z87_temp_1, Z88_temp_1;
reg [10:0] Q11, Q12, Q13, Q14, Q15, Q16, Q17, Q18; 	
reg [10:0] Q21, Q22, Q23, Q24, Q25, Q26, Q27, Q28; 
reg [10:0] Q31, Q32, Q33, Q34, Q35, Q36, Q37, Q38; 
reg [10:0] Q41, Q42, Q43, Q44, Q45, Q46, Q47, Q48; 
reg [10:0] Q51, Q52, Q53, Q54, Q55, Q56, Q57, Q58; 
reg [10:0] Q61, Q62, Q63, Q64, Q65, Q66, Q67, Q68; 
reg [10:0] Q71, Q72, Q73, Q74, Q75, Q76, Q77, Q78; 
reg [10:0] Q81, Q82, Q83, Q84, Q85, Q86, Q87, Q88; 
reg out_enable, enable_1, enable_2, enable_3;
integer Z11_int, Z12_int, Z13_int, Z14_int, Z15_int, Z16_int, Z17_int, Z18_int;
integer Z21_int, Z22_int, Z23_int, Z24_int, Z25_int, Z26_int, Z27_int, Z28_int;
integer Z31_int, Z32_int, Z33_int, Z34_int, Z35_int, Z36_int, Z37_int, Z38_int;
integer Z41_int, Z42_int, Z43_int, Z44_int, Z45_int, Z46_int, Z47_int, Z48_int;
integer Z51_int, Z52_int, Z53_int, Z54_int, Z55_int, Z56_int, Z57_int, Z58_int;
integer Z61_int, Z62_int, Z63_int, Z64_int, Z65_int, Z66_int, Z67_int, Z68_int;
integer Z71_int, Z72_int, Z73_int, Z74_int, Z75_int, Z76_int, Z77_int, Z78_int;
integer Z81_int, Z82_int, Z83_int, Z84_int, Z85_int, Z86_int, Z87_int, Z88_int;

always @(posedge clk)
begin
	if (rst) begin
		Z11_int <= 0; Z12_int <= 0; Z13_int <= 0; Z14_int <= 0;
		Z15_int <= 0; Z16_int <= 0; Z17_int <= 0; Z18_int <= 0; 
		Z21_int <= 0; Z22_int <= 0; Z23_int <= 0; Z24_int <= 0;
		Z25_int <= 0; Z26_int <= 0; Z27_int <= 0; Z28_int <= 0;
		Z31_int <= 0; Z32_int <= 0; Z33_int <= 0; Z34_int <= 0;
		Z35_int <= 0; Z36_int <= 0; Z37_int <= 0; Z38_int <= 0;
		Z41_int <= 0; Z42_int <= 0; Z43_int <= 0; Z44_int <= 0;
		Z45_int <= 0; Z46_int <= 0; Z47_int <= 0; Z48_int <= 0;
		Z51_int <= 0; Z52_int <= 0; Z53_int <= 0; Z54_int <= 0;
		Z55_int <= 0; Z56_int <= 0; Z57_int <= 0; Z58_int <= 0;
		Z61_int <= 0; Z62_int <= 0; Z63_int <= 0; Z64_int <= 0;
		Z65_int <= 0; Z66_int <= 0; Z67_int <= 0; Z68_int <= 0;
		Z71_int <= 0; Z72_int <= 0; Z73_int <= 0; Z74_int <= 0;
		Z75_int <= 0; Z76_int <= 0; Z77_int <= 0; Z78_int <= 0;
		Z81_int <= 0; Z82_int <= 0; Z83_int <= 0; Z84_int <= 0;
		Z85_int <= 0; Z86_int <= 0; Z87_int <= 0; Z88_int <= 0;
		end
	else if (enable) begin
		Z11_int[10:0] <= Z11; Z12_int[10:0] <= Z12; Z13_int[10:0] <= Z13; Z14_int[10:0] <= Z14;
		Z15_int[10:0] <= Z15; Z16_int[10:0] <= Z16; Z17_int[10:0] <= Z17; Z18_int[10:0] <= Z18;
		Z21_int[10:0] <= Z21; Z22_int[10:0] <= Z22; Z23_int[10:0] <= Z23; Z24_int[10:0] <= Z24;
		Z25_int[10:0] <= Z25; Z26_int[10:0] <= Z26; Z27_int[10:0] <= Z27; Z28_int[10:0] <= Z28;
		Z31_int[10:0] <= Z31; Z32_int[10:0] <= Z32; Z33_int[10:0] <= Z33; Z34_int[10:0] <= Z34;
		Z35_int[10:0] <= Z35; Z36_int[10:0] <= Z36; Z37_int[10:0] <= Z37; Z38_int[10:0] <= Z38;
		Z41_int[10:0] <= Z41; Z42_int[10:0] <= Z42; Z43_int[10:0] <= Z43; Z44_int[10:0] <= Z44;
		Z45_int[10:0] <= Z45; Z46_int[10:0] <= Z46; Z47_int[10:0] <= Z47; Z48_int[10:0] <= Z48;
		Z51_int[10:0] <= Z51; Z52_int[10:0] <= Z52; Z53_int[10:0] <= Z53; Z54_int[10:0] <= Z54;
		Z55_int[10:0] <= Z55; Z56_int[10:0] <= Z56; Z57_int[10:0] <= Z57; Z58_int[10:0] <= Z58;
		Z61_int[10:0] <= Z61; Z62_int[10:0] <= Z62; Z63_int[10:0] <= Z63; Z64_int[10:0] <= Z64;
		Z65_int[10:0] <= Z65; Z66_int[10:0] <= Z66; Z67_int[10:0] <= Z67; Z68_int[10:0] <= Z68;
		Z71_int[10:0] <= Z71; Z72_int[10:0] <= Z72; Z73_int[10:0] <= Z73; Z74_int[10:0] <= Z74;
		Z75_int[10:0] <= Z75; Z76_int[10:0] <= Z76; Z77_int[10:0] <= Z77; Z78_int[10:0] <= Z78;
		Z81_int[10:0] <= Z81; Z82_int[10:0] <= Z82; Z83_int[10:0] <= Z83; Z84_int[10:0] <= Z84;
		Z85_int[10:0] <= Z85; Z86_int[10:0] <= Z86; Z87_int[10:0] <= Z87; Z88_int[10:0] <= Z88;
		// sign extend to make Z11_int a twos complement representation of Z11
		Z11_int[31:11] <= Z11[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z12_int[31:11] <= Z12[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z13_int[31:11] <= Z13[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z14_int[31:11] <= Z14[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z15_int[31:11] <= Z15[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z16_int[31:11] <= Z16[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z17_int[31:11] <= Z17[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z18_int[31:11] <= Z18[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z21_int[31:11] <= Z21[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z22_int[31:11] <= Z22[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z23_int[31:11] <= Z23[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z24_int[31:11] <= Z24[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z25_int[31:11] <= Z25[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z26_int[31:11] <= Z26[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z27_int[31:11] <= Z27[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z28_int[31:11] <= Z28[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z31_int[31:11] <= Z31[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z32_int[31:11] <= Z32[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z33_int[31:11] <= Z33[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z34_int[31:11] <= Z34[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z35_int[31:11] <= Z35[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z36_int[31:11] <= Z36[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z37_int[31:11] <= Z37[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z38_int[31:11] <= Z38[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z41_int[31:11] <= Z41[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z42_int[31:11] <= Z42[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z43_int[31:11] <= Z43[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z44_int[31:11] <= Z44[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z45_int[31:11] <= Z45[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z46_int[31:11] <= Z46[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z47_int[31:11] <= Z47[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z48_int[31:11] <= Z48[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z51_int[31:11] <= Z51[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z52_int[31:11] <= Z52[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z53_int[31:11] <= Z53[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z54_int[31:11] <= Z54[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z55_int[31:11] <= Z55[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z56_int[31:11] <= Z56[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z57_int[31:11] <= Z57[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z58_int[31:11] <= Z58[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z61_int[31:11] <= Z61[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z62_int[31:11] <= Z62[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z63_int[31:11] <= Z63[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z64_int[31:11] <= Z64[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z65_int[31:11] <= Z65[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z66_int[31:11] <= Z66[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z67_int[31:11] <= Z67[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z68_int[31:11] <= Z68[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z71_int[31:11] <= Z71[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z72_int[31:11] <= Z72[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z73_int[31:11] <= Z73[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z74_int[31:11] <= Z74[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z75_int[31:11] <= Z75[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z76_int[31:11] <= Z76[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z77_int[31:11] <= Z77[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z78_int[31:11] <= Z78[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z81_int[31:11] <= Z81[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z82_int[31:11] <= Z82[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z83_int[31:11] <= Z83[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z84_int[31:11] <= Z84[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z85_int[31:11] <= Z85[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z86_int[31:11] <= Z86[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z87_int[31:11] <= Z87[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;
		Z88_int[31:11] <= Z88[10] ? 21'b111111111111111111111 : 21'b000000000000000000000;	 
		end
end	   

always @(posedge clk)
begin
	if (rst) begin
		Z11_temp <= 0; Z12_temp <= 0; Z13_temp <= 0; Z14_temp <= 0;
		Z12_temp <= 0; Z16_temp <= 0; Z17_temp <= 0; Z18_temp <= 0;
		Z21_temp <= 0; Z22_temp <= 0; Z23_temp <= 0; Z24_temp <= 0;
		Z22_temp <= 0; Z26_temp <= 0; Z27_temp <= 0; Z28_temp <= 0;
		Z31_temp <= 0; Z32_temp <= 0; Z33_temp <= 0; Z34_temp <= 0;
		Z32_temp <= 0; Z36_temp <= 0; Z37_temp <= 0; Z38_temp <= 0;
		Z41_temp <= 0; Z42_temp <= 0; Z43_temp <= 0; Z44_temp <= 0;
		Z42_temp <= 0; Z46_temp <= 0; Z47_temp <= 0; Z48_temp <= 0;
		Z51_temp <= 0; Z52_temp <= 0; Z53_temp <= 0; Z54_temp <= 0;
		Z52_temp <= 0; Z56_temp <= 0; Z57_temp <= 0; Z58_temp <= 0;
		Z61_temp <= 0; Z62_temp <= 0; Z63_temp <= 0; Z64_temp <= 0;
		Z62_temp <= 0; Z66_temp <= 0; Z67_temp <= 0; Z68_temp <= 0;
		Z71_temp <= 0; Z72_temp <= 0; Z73_temp <= 0; Z74_temp <= 0;
		Z72_temp <= 0; Z76_temp <= 0; Z77_temp <= 0; Z78_temp <= 0;
		Z81_temp <= 0; Z82_temp <= 0; Z83_temp <= 0; Z84_temp <= 0;
		Z82_temp <= 0; Z86_temp <= 0; Z87_temp <= 0; Z88_temp <= 0;
		end
	else if (enable_1) begin
		Z11_temp <= Z11_int * QM1_1; Z12_temp <= Z12_int * QM1_2;
		Z13_temp <= Z13_int * QM1_3; Z14_temp <= Z14_int * QM1_4;
		Z15_temp <= Z15_int * QM1_5; Z16_temp <= Z16_int * QM1_6;
		Z17_temp <= Z17_int * QM1_7; Z18_temp <= Z18_int * QM1_8;
		Z21_temp <= Z21_int * QM2_1; Z22_temp <= Z22_int * QM2_2;
		Z23_temp <= Z23_int * QM2_3; Z24_temp <= Z24_int * QM2_4;
		Z25_temp <= Z25_int * QM2_5; Z26_temp <= Z26_int * QM2_6;
		Z27_temp <= Z27_int * QM2_7; Z28_temp <= Z28_int * QM2_8;
		Z31_temp <= Z31_int * QM3_1; Z32_temp <= Z32_int * QM3_2;
		Z33_temp <= Z33_int * QM3_3; Z34_temp <= Z34_int * QM3_4;
		Z35_temp <= Z35_int * QM3_5; Z36_temp <= Z36_int * QM3_6;
		Z37_temp <= Z37_int * QM3_7; Z38_temp <= Z38_int * QM3_8;
		Z41_temp <= Z41_int * QM4_1; Z42_temp <= Z42_int * QM4_2;
		Z43_temp <= Z43_int * QM4_3; Z44_temp <= Z44_int * QM4_4;
		Z45_temp <= Z45_int * QM4_5; Z46_temp <= Z46_int * QM4_6;
		Z47_temp <= Z47_int * QM4_7; Z48_temp <= Z48_int * QM4_8;
		Z51_temp <= Z51_int * QM5_1; Z52_temp <= Z52_int * QM5_2;
		Z53_temp <= Z53_int * QM5_3; Z54_temp <= Z54_int * QM5_4;
		Z55_temp <= Z55_int * QM5_5; Z56_temp <= Z56_int * QM5_6;
		Z57_temp <= Z57_int * QM5_7; Z58_temp <= Z58_int * QM5_8;
		Z61_temp <= Z61_int * QM6_1; Z62_temp <= Z62_int * QM6_2;
		Z63_temp <= Z63_int * QM6_3; Z64_temp <= Z64_int * QM6_4;
		Z65_temp <= Z65_int * QM6_5; Z66_temp <= Z66_int * QM6_6;
		Z67_temp <= Z67_int * QM6_7; Z68_temp <= Z68_int * QM6_8;
		Z71_temp <= Z71_int * QM7_1; Z72_temp <= Z72_int * QM7_2;
		Z73_temp <= Z73_int * QM7_3; Z74_temp <= Z74_int * QM7_4;
		Z75_temp <= Z75_int * QM7_5; Z76_temp <= Z76_int * QM7_6;
		Z77_temp <= Z77_int * QM7_7; Z78_temp <= Z78_int * QM7_8;
		Z81_temp <= Z81_int * QM8_1; Z82_temp <= Z82_int * QM8_2;
		Z83_temp <= Z83_int * QM8_3; Z84_temp <= Z84_int * QM8_4;
		Z85_temp <= Z85_int * QM8_5; Z86_temp <= Z86_int * QM8_6;
		Z87_temp <= Z87_int * QM8_7; Z88_temp <= Z88_int * QM8_8;
		end
end	 


always @(posedge clk)
begin
	if (rst) begin
		Z11_temp_1 <= 0; Z12_temp_1 <= 0; Z13_temp_1 <= 0; Z14_temp_1 <= 0;
		Z12_temp_1 <= 0; Z16_temp_1 <= 0; Z17_temp_1 <= 0; Z18_temp_1 <= 0;
		Z21_temp_1 <= 0; Z22_temp_1 <= 0; Z23_temp_1 <= 0; Z24_temp_1 <= 0;
		Z22_temp_1 <= 0; Z26_temp_1 <= 0; Z27_temp_1 <= 0; Z28_temp_1 <= 0;
		Z31_temp_1 <= 0; Z32_temp_1 <= 0; Z33_temp_1 <= 0; Z34_temp_1 <= 0;
		Z32_temp_1 <= 0; Z36_temp_1 <= 0; Z37_temp_1 <= 0; Z38_temp_1 <= 0;
		Z41_temp_1 <= 0; Z42_temp_1 <= 0; Z43_temp_1 <= 0; Z44_temp_1 <= 0;
		Z42_temp_1 <= 0; Z46_temp_1 <= 0; Z47_temp_1 <= 0; Z48_temp_1 <= 0;
		Z51_temp_1 <= 0; Z52_temp_1 <= 0; Z53_temp_1 <= 0; Z54_temp_1 <= 0;
		Z52_temp_1 <= 0; Z56_temp_1 <= 0; Z57_temp_1 <= 0; Z58_temp_1 <= 0;
		Z61_temp_1 <= 0; Z62_temp_1 <= 0; Z63_temp_1 <= 0; Z64_temp_1 <= 0;
		Z62_temp_1 <= 0; Z66_temp_1 <= 0; Z67_temp_1 <= 0; Z68_temp_1 <= 0;
		Z71_temp_1 <= 0; Z72_temp_1 <= 0; Z73_temp_1 <= 0; Z74_temp_1 <= 0;
		Z72_temp_1 <= 0; Z76_temp_1 <= 0; Z77_temp_1 <= 0; Z78_temp_1 <= 0;
		Z81_temp_1 <= 0; Z82_temp_1 <= 0; Z83_temp_1 <= 0; Z84_temp_1 <= 0;
		Z82_temp_1 <= 0; Z86_temp_1 <= 0; Z87_temp_1 <= 0; Z88_temp_1 <= 0;
		end
	else if (enable_2) begin
		Z11_temp_1 <= Z11_temp; Z12_temp_1 <= Z12_temp;
		Z13_temp_1 <= Z13_temp; Z14_temp_1 <= Z14_temp;
		Z15_temp_1 <= Z15_temp; Z16_temp_1 <= Z16_temp;
		Z17_temp_1 <= Z17_temp; Z18_temp_1 <= Z18_temp;
		Z21_temp_1 <= Z21_temp; Z22_temp_1 <= Z22_temp;
		Z23_temp_1 <= Z23_temp; Z24_temp_1 <= Z24_temp;
		Z25_temp_1 <= Z25_temp; Z26_temp_1 <= Z26_temp;
		Z27_temp_1 <= Z27_temp; Z28_temp_1 <= Z28_temp;
		Z31_temp_1 <= Z31_temp; Z32_temp_1 <= Z32_temp;
		Z33_temp_1 <= Z33_temp; Z34_temp_1 <= Z34_temp;
		Z35_temp_1 <= Z35_temp; Z36_temp_1 <= Z36_temp;
		Z37_temp_1 <= Z37_temp; Z38_temp_1 <= Z38_temp;
		Z41_temp_1 <= Z41_temp; Z42_temp_1 <= Z42_temp;
		Z43_temp_1 <= Z43_temp; Z44_temp_1 <= Z44_temp;
		Z45_temp_1 <= Z45_temp; Z46_temp_1 <= Z46_temp;
		Z47_temp_1 <= Z47_temp; Z48_temp_1 <= Z48_temp;
		Z51_temp_1 <= Z51_temp; Z52_temp_1 <= Z52_temp;
		Z53_temp_1 <= Z53_temp; Z54_temp_1 <= Z54_temp;
		Z55_temp_1 <= Z55_temp; Z56_temp_1 <= Z56_temp;
		Z57_temp_1 <= Z57_temp; Z58_temp_1 <= Z58_temp;
		Z61_temp_1 <= Z61_temp; Z62_temp_1 <= Z62_temp;
		Z63_temp_1 <= Z63_temp; Z64_temp_1 <= Z64_temp;
		Z65_temp_1 <= Z65_temp; Z66_temp_1 <= Z66_temp;
		Z67_temp_1 <= Z67_temp; Z68_temp_1 <= Z68_temp;
		Z71_temp_1 <= Z71_temp; Z72_temp_1 <= Z72_temp;
		Z73_temp_1 <= Z73_temp; Z74_temp_1 <= Z74_temp;
		Z75_temp_1 <= Z75_temp; Z76_temp_1 <= Z76_temp;
		Z77_temp_1 <= Z77_temp; Z78_temp_1 <= Z78_temp;
		Z81_temp_1 <= Z81_temp; Z82_temp_1 <= Z82_temp;
		Z83_temp_1 <= Z83_temp; Z84_temp_1 <= Z84_temp;
		Z85_temp_1 <= Z85_temp; Z86_temp_1 <= Z86_temp;
		Z87_temp_1 <= Z87_temp; Z88_temp_1 <= Z88_temp;
		end
end	 

always @(posedge clk)
begin
	if (rst) begin
		Q11 <= 0; Q12 <= 0; Q13 <= 0; Q14 <= 0; Q15 <= 0; Q16 <= 0; Q17 <= 0; Q18 <= 0;
		Q21 <= 0; Q22 <= 0; Q23 <= 0; Q24 <= 0; Q25 <= 0; Q26 <= 0; Q27 <= 0; Q28 <= 0;
		Q31 <= 0; Q32 <= 0; Q33 <= 0; Q34 <= 0; Q35 <= 0; Q36 <= 0; Q37 <= 0; Q38 <= 0;
		Q41 <= 0; Q42 <= 0; Q43 <= 0; Q44 <= 0; Q45 <= 0; Q46 <= 0; Q47 <= 0; Q48 <= 0;
		Q51 <= 0; Q52 <= 0; Q53 <= 0; Q54 <= 0; Q55 <= 0; Q56 <= 0; Q57 <= 0; Q58 <= 0;
		Q61 <= 0; Q62 <= 0; Q63 <= 0; Q64 <= 0; Q65 <= 0; Q66 <= 0; Q67 <= 0; Q68 <= 0;
		Q71 <= 0; Q72 <= 0; Q73 <= 0; Q74 <= 0; Q75 <= 0; Q76 <= 0; Q77 <= 0; Q78 <= 0;
		Q81 <= 0; Q82 <= 0; Q83 <= 0; Q84 <= 0; Q85 <= 0; Q86 <= 0; Q87 <= 0; Q88 <= 0;
		end
	else if (enable_3) begin
		// rounding Q11 based on the bit in the 11th place of Z11_temp	
		Q11 <= Z11_temp_1[11] ? Z11_temp_1[22:12] + 1 : Z11_temp_1[22:12]; 
		Q12 <= Z12_temp_1[11] ? Z12_temp_1[22:12] + 1 : Z12_temp_1[22:12];
		Q13 <= Z13_temp_1[11] ? Z13_temp_1[22:12] + 1 : Z13_temp_1[22:12];
		Q14 <= Z14_temp_1[11] ? Z14_temp_1[22:12] + 1 : Z14_temp_1[22:12];
		Q15 <= Z15_temp_1[11] ? Z15_temp_1[22:12] + 1 : Z15_temp_1[22:12];
		Q16 <= Z16_temp_1[11] ? Z16_temp_1[22:12] + 1 : Z16_temp_1[22:12];
		Q17 <= Z17_temp_1[11] ? Z17_temp_1[22:12] + 1 : Z17_temp_1[22:12];
		Q18 <= Z18_temp_1[11] ? Z18_temp_1[22:12] + 1 : Z18_temp_1[22:12]; 
		Q21 <= Z21_temp_1[11] ? Z21_temp_1[22:12] + 1 : Z21_temp_1[22:12];
		Q22 <= Z22_temp_1[11] ? Z22_temp_1[22:12] + 1 : Z22_temp_1[22:12];
		Q23 <= Z23_temp_1[11] ? Z23_temp_1[22:12] + 1 : Z23_temp_1[22:12];
		Q24 <= Z24_temp_1[11] ? Z24_temp_1[22:12] + 1 : Z24_temp_1[22:12];
		Q25 <= Z25_temp_1[11] ? Z25_temp_1[22:12] + 1 : Z25_temp_1[22:12];
		Q26 <= Z26_temp_1[11] ? Z26_temp_1[22:12] + 1 : Z26_temp_1[22:12];
		Q27 <= Z27_temp_1[11] ? Z27_temp_1[22:12] + 1 : Z27_temp_1[22:12];
		Q28 <= Z28_temp_1[11] ? Z28_temp_1[22:12] + 1 : Z28_temp_1[22:12];
		Q31 <= Z31_temp_1[11] ? Z31_temp_1[22:12] + 1 : Z31_temp_1[22:12];
		Q32 <= Z32_temp_1[11] ? Z32_temp_1[22:12] + 1 : Z32_temp_1[22:12];
		Q33 <= Z33_temp_1[11] ? Z33_temp_1[22:12] + 1 : Z33_temp_1[22:12];
		Q34 <= Z34_temp_1[11] ? Z34_temp_1[22:12] + 1 : Z34_temp_1[22:12];
		Q35 <= Z35_temp_1[11] ? Z35_temp_1[22:12] + 1 : Z35_temp_1[22:12];
		Q36 <= Z36_temp_1[11] ? Z36_temp_1[22:12] + 1 : Z36_temp_1[22:12];
		Q37 <= Z37_temp_1[11] ? Z37_temp_1[22:12] + 1 : Z37_temp_1[22:12];
		Q38 <= Z38_temp_1[11] ? Z38_temp_1[22:12] + 1 : Z38_temp_1[22:12];
		Q41 <= Z41_temp_1[11] ? Z41_temp_1[22:12] + 1 : Z41_temp_1[22:12];
		Q42 <= Z42_temp_1[11] ? Z42_temp_1[22:12] + 1 : Z42_temp_1[22:12];
		Q43 <= Z43_temp_1[11] ? Z43_temp_1[22:12] + 1 : Z43_temp_1[22:12];
		Q44 <= Z44_temp_1[11] ? Z44_temp_1[22:12] + 1 : Z44_temp_1[22:12];
		Q45 <= Z45_temp_1[11] ? Z45_temp_1[22:12] + 1 : Z45_temp_1[22:12];
		Q46 <= Z46_temp_1[11] ? Z46_temp_1[22:12] + 1 : Z46_temp_1[22:12];
		Q47 <= Z47_temp_1[11] ? Z47_temp_1[22:12] + 1 : Z47_temp_1[22:12];
		Q48 <= Z48_temp_1[11] ? Z48_temp_1[22:12] + 1 : Z48_temp_1[22:12];
		Q51 <= Z51_temp_1[11] ? Z51_temp_1[22:12] + 1 : Z51_temp_1[22:12];
		Q52 <= Z52_temp_1[11] ? Z52_temp_1[22:12] + 1 : Z52_temp_1[22:12];
		Q53 <= Z53_temp_1[11] ? Z53_temp_1[22:12] + 1 : Z53_temp_1[22:12];
		Q54 <= Z54_temp_1[11] ? Z54_temp_1[22:12] + 1 : Z54_temp_1[22:12];
		Q55 <= Z55_temp_1[11] ? Z55_temp_1[22:12] + 1 : Z55_temp_1[22:12];
		Q56 <= Z56_temp_1[11] ? Z56_temp_1[22:12] + 1 : Z56_temp_1[22:12];
		Q57 <= Z57_temp_1[11] ? Z57_temp_1[22:12] + 1 : Z57_temp_1[22:12];
		Q58 <= Z58_temp_1[11] ? Z58_temp_1[22:12] + 1 : Z58_temp_1[22:12];
		Q61 <= Z61_temp_1[11] ? Z61_temp_1[22:12] + 1 : Z61_temp_1[22:12];
		Q62 <= Z62_temp_1[11] ? Z62_temp_1[22:12] + 1 : Z62_temp_1[22:12];
		Q63 <= Z63_temp_1[11] ? Z63_temp_1[22:12] + 1 : Z63_temp_1[22:12];
		Q64 <= Z64_temp_1[11] ? Z64_temp_1[22:12] + 1 : Z64_temp_1[22:12];
		Q65 <= Z65_temp_1[11] ? Z65_temp_1[22:12] + 1 : Z65_temp_1[22:12];
		Q66 <= Z66_temp_1[11] ? Z66_temp_1[22:12] + 1 : Z66_temp_1[22:12];
		Q67 <= Z67_temp_1[11] ? Z67_temp_1[22:12] + 1 : Z67_temp_1[22:12];
		Q68 <= Z68_temp_1[11] ? Z68_temp_1[22:12] + 1 : Z68_temp_1[22:12];
		Q71 <= Z71_temp_1[11] ? Z71_temp_1[22:12] + 1 : Z71_temp_1[22:12];
		Q72 <= Z72_temp_1[11] ? Z72_temp_1[22:12] + 1 : Z72_temp_1[22:12];
		Q73 <= Z73_temp_1[11] ? Z73_temp_1[22:12] + 1 : Z73_temp_1[22:12];
		Q74 <= Z74_temp_1[11] ? Z74_temp_1[22:12] + 1 : Z74_temp_1[22:12];
		Q75 <= Z75_temp_1[11] ? Z75_temp_1[22:12] + 1 : Z75_temp_1[22:12];
		Q76 <= Z76_temp_1[11] ? Z76_temp_1[22:12] + 1 : Z76_temp_1[22:12];
		Q77 <= Z77_temp_1[11] ? Z77_temp_1[22:12] + 1 : Z77_temp_1[22:12];
		Q78 <= Z78_temp_1[11] ? Z78_temp_1[22:12] + 1 : Z78_temp_1[22:12];
		Q81 <= Z81_temp_1[11] ? Z81_temp_1[22:12] + 1 : Z81_temp_1[22:12];
		Q82 <= Z82_temp_1[11] ? Z82_temp_1[22:12] + 1 : Z82_temp_1[22:12];
		Q83 <= Z83_temp_1[11] ? Z83_temp_1[22:12] + 1 : Z83_temp_1[22:12];
		Q84 <= Z84_temp_1[11] ? Z84_temp_1[22:12] + 1 : Z84_temp_1[22:12];
		Q85 <= Z85_temp_1[11] ? Z85_temp_1[22:12] + 1 : Z85_temp_1[22:12];
		Q86 <= Z86_temp_1[11] ? Z86_temp_1[22:12] + 1 : Z86_temp_1[22:12];
		Q87 <= Z87_temp_1[11] ? Z87_temp_1[22:12] + 1 : Z87_temp_1[22:12];
		Q88 <= Z88_temp_1[11] ? Z88_temp_1[22:12] + 1 : Z88_temp_1[22:12];
		end
end	 


/* enable_1 is delayed one clock cycle from enable, and it's used to 
enable the logic that needs to execute on the clock cycle after enable goes high 
enable_2 is delayed two clock cycles, and out_enable signals the next module
that its input data is ready*/

always @(posedge clk)
begin
	if (rst) begin
		enable_1 <= 0; enable_2 <= 0; enable_3 <= 0;
		out_enable <= 0;
		end
	else begin
		enable_1 <= enable; enable_2 <= enable_1;
		enable_3 <= enable_2;
		out_enable <= enable_3;
		end
end	 

endmodule


