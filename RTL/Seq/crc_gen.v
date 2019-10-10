//////////////////////////////////////////////////////////////////////
////                                                              ////
////  CRC_gen.v                                                   ////
////                                                              ////
////  This file is part of the Ethernet IP core project           ////
////  http://www.opencores.org/projects.cgi/web/ethernet_tri_mode/////
////                                                              ////
////  Author(s):                                                  ////
////      - Jon Gao (gaojon@yahoo.com)                            ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2001 Authors                                   ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.2  2005/12/16 06:44:17  Administrator
// replaced tab with space.
// passed 9.6k length frame test.
//
// Revision 1.1.1.1  2005/12/13 01:51:45  Administrator
// no message
//

module crc_gen (
	input          Reset,
	input          Clk,
	input          Init,
	input  [7:0]   Frame_data,
	input          Data_en,
	input          CRC_rd,
	output [31:0]  CRC_out,
	output reg     CRC_end
);
reg [31:0] CRC_reg;
reg [3:0]  Counter;

function[31:0]  NextCRC;
input[7:0]  D;
input[31:0] C;
reg[31:0]   NewCRC;
begin
	NewCRC[0]=C[24]^C[30]^D[1]^D[7];
	NewCRC[1]=C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
	NewCRC[2]=C[26]^D[5]^C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
	NewCRC[3]=C[27]^D[4]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
	NewCRC[4]=C[28]^D[3]^C[27]^D[4]^C[26]^D[5]^C[24]^C[30]^D[1]^D[7];
	NewCRC[5]=C[29]^D[2]^C[28]^D[3]^C[27]^D[4]^C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
	NewCRC[6]=C[30]^D[1]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
	NewCRC[7]=C[31]^D[0]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[24]^D[7];
	NewCRC[8]=C[0]^C[28]^D[3]^C[27]^D[4]^C[25]^D[6]^C[24]^D[7];
	NewCRC[9]=C[1]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^D[6];
	NewCRC[10]=C[2]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[24]^D[7];
	NewCRC[11]=C[3]^C[28]^D[3]^C[27]^D[4]^C[25]^D[6]^C[24]^D[7];
	NewCRC[12]=C[4]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^D[6]^C[24]^C[30]^D[1]^D[7];
	NewCRC[13]=C[5]^C[30]^D[1]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
	NewCRC[14]=C[6]^C[31]^D[0]^C[30]^D[1]^C[28]^D[3]^C[27]^D[4]^C[26]^D[5];
	NewCRC[15]=C[7]^C[31]^D[0]^C[29]^D[2]^C[28]^D[3]^C[27]^D[4];
	NewCRC[16]=C[8]^C[29]^D[2]^C[28]^D[3]^C[24]^D[7];
	NewCRC[17]=C[9]^C[30]^D[1]^C[29]^D[2]^C[25]^D[6];
	NewCRC[18]=C[10]^C[31]^D[0]^C[30]^D[1]^C[26]^D[5];
	NewCRC[19]=C[11]^C[31]^D[0]^C[27]^D[4];
	NewCRC[20]=C[12]^C[28]^D[3];
	NewCRC[21]=C[13]^C[29]^D[2];
	NewCRC[22]=C[14]^C[24]^D[7];
	NewCRC[23]=C[15]^C[25]^D[6]^C[24]^C[30]^D[1]^D[7];
	NewCRC[24]=C[16]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
	NewCRC[25]=C[17]^C[27]^D[4]^C[26]^D[5];
	NewCRC[26]=C[18]^C[28]^D[3]^C[27]^D[4]^C[24]^C[30]^D[1]^D[7];
	NewCRC[27]=C[19]^C[29]^D[2]^C[28]^D[3]^C[25]^C[31]^D[0]^D[6];
	NewCRC[28]=C[20]^C[30]^D[1]^C[29]^D[2]^C[26]^D[5];
	NewCRC[29]=C[21]^C[31]^D[0]^C[30]^D[1]^C[27]^D[4];
	NewCRC[30]=C[22]^C[31]^D[0]^C[28]^D[3];
	NewCRC[31]=C[23]^C[29]^D[2];
	NextCRC=NewCRC;
end
endfunction

always @ ( negedge Clk )
	if (Reset)
		CRC_reg <= 32'hffffffff;
	else
		CRC_reg <= Init ? 32'hffffffff : Data_en ? NextCRC(Frame_data, CRC_reg ) : CRC_reg;
assign CRC_out = ~{ CRC_reg[24],CRC_reg[25],CRC_reg[26],CRC_reg[27],CRC_reg[28],CRC_reg[29],CRC_reg[30],CRC_reg[31], CRC_reg[16],CRC_reg[17],CRC_reg[18],CRC_reg[19],CRC_reg[20],CRC_reg[21],CRC_reg[22],CRC_reg[23], CRC_reg[ 8],CRC_reg[ 9],CRC_reg[10],CRC_reg[11],CRC_reg[12],CRC_reg[13],CRC_reg[14],CRC_reg[15], CRC_reg[ 0],CRC_reg[ 1],CRC_reg[ 2],CRC_reg[ 3],CRC_reg[ 4],CRC_reg[ 5],CRC_reg[ 6],CRC_reg[ 7] };
endmodule
