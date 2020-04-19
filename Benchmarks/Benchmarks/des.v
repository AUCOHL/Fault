
// ======================================================================
// CBC-DES encryption/decryption
// algorithm according to FIPS 46-3 specification
// Copyright (C) 2013 Torsten Meissner
//-----------------------------------------------------------------------
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write:the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
// ======================================================================



module des
  (
    input             reset_i,  // async reset
    input             clk_i,    // clock
    input             mode_i,   // des-mode: 0 = encrypt, 1 = decrypt
    input      [0:63] key_i,    // key input
    input      [0:63] data_i,   // data input
    input             valid_i,  // input key/data valid flag
    output reg [0:63] data_o,   // data output
    output            valid_o   // output data valid flag
  );


function [0:31] ip0 (input [0:63] data);
begin
  ip0 = {data[57], data[49], data[41], data[33], data[25], data[17], data[ 9], data[1],
        data[59], data[51], data[43], data[35], data[27], data[19], data[11], data[3],
        data[61], data[53], data[45], data[37], data[29], data[21], data[13], data[5],
        data[63], data[55], data[47], data[39], data[31], data[23], data[15], data[7]};
end
endfunction


function [0:31] ip1 (input [0:63] data);
begin
  ip1 = {data[56], data[48], data[40], data[32], data[24], data[16], data[ 8], data[0],
        data[58], data[50], data[42], data[34], data[26], data[18], data[10], data[2],
        data[60], data[52], data[44], data[36], data[28], data[20], data[12], data[4],
        data[62], data[54], data[46], data[38], data[30], data[22], data[14], data[6]};
end
endfunction


function [0:63] ipn (input [0:63] data);
begin
  ipn = {data[39],  data[7], data[47], data[15], data[55], data[23], data[63], data[31],
         data[38],  data[6], data[46], data[14], data[54], data[22], data[62], data[30],
         data[37],  data[5], data[45], data[13], data[53], data[21], data[61], data[29],
         data[36],  data[4], data[44], data[12], data[52], data[20], data[60], data[28],
         data[35],  data[3], data[43], data[11], data[51], data[19], data[59], data[27],
         data[34],  data[2], data[42], data[10], data[50], data[18], data[58], data[26],
         data[33],  data[1], data[41], data[ 9], data[49], data[17], data[57], data[25],
         data[32],  data[0], data[40], data[ 8], data[48], data[16], data[56], data[24]};
end
endfunction


function [0:47] e (input [0:31] data);
begin
  e = {data[31], data[ 0], data[ 1], data[ 2], data[ 3], data[ 4],
       data[ 3], data[ 4], data[ 5], data[ 6], data[ 7], data[ 8],
       data[ 7], data[ 8], data[ 9], data[10], data[11], data[12],
       data[11], data[12], data[13], data[14], data[15], data[16],
       data[15], data[16], data[17], data[18], data[19], data[20],
       data[19], data[20], data[21], data[22], data[23], data[24],
       data[23], data[24], data[25], data[26], data[27], data[28],
       data[27], data[28], data[29], data[30], data[31], data[ 0]};
end
endfunction


function [0:3] s1 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'hE4D12FB83A6C5907_0F74E2D1A6CB9538_41E8D62BFC973A50_FC8249175B3EA06D;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s1[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s2 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'hF18E6B34972DC05A_3D47F28EC01A69B5_0E7BA4D158C6932F_D8A13F42B67C05E9;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s2[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s3 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'hA09E63F51DC7B428_D709346A285ECBF1_D6498F30B12C5AE7_1AD069874FE3B52C;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s3[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s4 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'h7DE3069A1285BC4F_D8B56F03472C1AE9_A690CB7DF13E5284_3F06A1D8945BC72E;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s4[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s5 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'h2C417AB6853FD0E9_EB2C47D150FA3986_421BAD78F9C5630E_B8C71E2D6F09A453;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s5[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s6 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'hC1AF92680D34E75B_AF427C9561DE0B38_9EF528C3704A1DB6_432C95FABE17608D;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s6[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s7 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'h4B2EF08D3C975A61_D0B7491AE35C2F86_14BDC37EAF680592_6BD814A7950FE23C;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s7[index] = matrix[pos + index];
  end
end
endfunction


function [0:3] s8 (input [0:5] data);
  reg [0:255] matrix;
  integer pos;
  integer index;
begin
  matrix = 256'hD2846FB1A93E50C7_1FD8A374C56B0E92_7B419CE206ADF358_21E74A8DFC90356B;
  pos = {data[0], data[5]} * 64 + data[1:4] * 4;
  for(index = 0 ; index <= 3; index = index + 1)
  begin
    s8[index] = matrix[pos + index];
  end
end
endfunction


function [0:31] p (input [0:31] data);
begin
  p = {data[15], data[ 6], data[19], data[20],
       data[28], data[11], data[27], data[16],
       data[ 0], data[14], data[22], data[25],
       data[ 4], data[17], data[30], data[ 9],
       data[ 1], data[ 7], data[23], data[13],
       data[31], data[26], data[ 2], data[ 8],
       data[18], data[12], data[29], data[ 5],
       data[21], data[10], data[ 3], data[24]};
end
endfunction


function [0:31] f (input [0:31] data, input [0:47] key);
  reg [0:47] intern;
begin
  intern = e(data) ^ key;
  f      = p({s1(intern[0:5]), s2(intern[6:11]), s3(intern[12:17]), s4(intern[18:23]),
              s5(intern[24:29]), s6(intern[30:35]), s7(intern[36:41]), s8(intern[42:47])});
end
endfunction


function [0:27] pc1_c (input [0:63] data);
begin
  pc1_c = {data[56], data[48], data[40], data[32], data[24], data[16], data[ 8],
           data[ 0], data[57], data[49], data[41], data[33], data[25], data[17],
           data[ 9], data[ 1], data[58], data[50], data[42], data[34], data[26],
           data[18], data[10], data[ 2], data[59], data[51], data[43], data[35]};
end
endfunction


function [0:27] pc1_d (input [0:63] data);
begin
  pc1_d = {data[62], data[54], data[46], data[38], data[30], data[22], data[14],
           data[ 6], data[61], data[53], data[45], data[37], data[29], data[21],
           data[13], data[ 5], data[60], data[52], data[44], data[36], data[28],
           data[20], data[12], data[ 4], data[27], data[19], data[11], data[ 3]};
end
endfunction


function [0:47] pc2 (input [0:55] data);
begin
  pc2 = {data[13], data[16], data[10], data[23], data[ 0], data[ 4],
         data[ 2], data[27], data[14], data[ 5], data[20], data[ 9],
         data[22], data[18], data[11], data[ 3], data[25], data[ 7],
         data[15], data[ 6], data[26], data[19], data[12], data[ 1],
         data[40], data[51], data[30], data[36], data[46], data[54],
         data[29], data[39], data[50], data[44], data[32], data[47],
         data[43], data[48], data[38], data[55], data[33], data[52],
         data[45], data[41], data[49], data[35], data[28], data[31]};
end
endfunction
  // valid, mode register
  reg [0:18] valid;
  reg [0:17] mode;

  // algorithm pipeline register
  // key calculation register
  reg [0:27] c0;
  reg [0:27] c1;
  reg [0:27] c2;
  reg [0:27] c3;
  reg [0:27] c4;
  reg [0:27] c5;
  reg [0:27] c6;
  reg [0:27] c7;
  reg [0:27] c8;
  reg [0:27] c9;
  reg [0:27] c10;
  reg [0:27] c11;
  reg [0:27] c12;
  reg [0:27] c13;
  reg [0:27] c14;
  reg [0:27] c15;
  reg [0:27] c16;
  reg [0:27] d0;
  reg [0:27] d1;
  reg [0:27] d2;
  reg [0:27] d3;
  reg [0:27] d4;
  reg [0:27] d5;
  reg [0:27] d6;
  reg [0:27] d7;
  reg [0:27] d8;
  reg [0:27] d9;
  reg [0:27] d10;
  reg [0:27] d11;
  reg [0:27] d12;
  reg [0:27] d13;
  reg [0:27] d14;
  reg [0:27] d15;
  reg [0:27] d16;
  // key register
  wire [0:47] key1;
  wire [0:47] key2;
  wire [0:47] key3;
  wire [0:47] key4;
  wire [0:47] key5;
  wire [0:47] key6;
  wire [0:47] key7;
  wire [0:47] key8;
  wire [0:47] key9;
  wire [0:47] key10;
  wire [0:47] key11;
  wire [0:47] key12;
  wire [0:47] key13;
  wire [0:47] key14;
  wire [0:47] key15;
  wire [0:47] key16;
  // register for left, right data blocks
  reg [0:31] l;
  reg [0:31] l0;
  reg [0:31] l1;
  reg [0:31] l2;
  reg [0:31] l3;
  reg [0:31] l4;
  reg [0:31] l5;
  reg [0:31] l6;
  reg [0:31] l7;
  reg [0:31] l8;
  reg [0:31] l9;
  reg [0:31] l10;
  reg [0:31] l11;
  reg [0:31] l12;
  reg [0:31] l13;
  reg [0:31] l14;
  reg [0:31] l15;
  reg [0:31] l16;
  reg [0:31] r;
  reg [0:31] r0;
  reg [0:31] r1;
  reg [0:31] r2;
  reg [0:31] r3;
  reg [0:31] r4;
  reg [0:31] r5;
  reg [0:31] r6;
  reg [0:31] r7;
  reg [0:31] r8;
  reg [0:31] r9;
  reg [0:31] r10;
  reg [0:31] r11;
  reg [0:31] r12;
  reg [0:31] r13;
  reg [0:31] r14;
  reg [0:31] r15;
  reg [0:31] r16;

  wire valid_o = valid[18];

  // valid, mode register
  always @(posedge clk_i, negedge reset_i) begin
    if(~reset_i) begin
      valid <= 0;
      mode  <= 0;
    end
    else begin
      // shift registers
      valid[1:18] <= valid[0:17];
      valid[0]    <= valid_i;
      mode[1:17]  <= mode[0:16];
      mode[0]     <= mode_i;
    end
  end

  // des algorithm pipeline
  always @(posedge clk_i, negedge reset_i) begin
    if(~reset_i) begin
      l      <= 0;
      r      <= 0;
      l0     <= 0;
      l1     <= 0;
      l2     <= 0;
      l3     <= 0;
      l4     <= 0;
      l5     <= 0;
      l6     <= 0;
      l7     <= 0;
      l8     <= 0;
      l9     <= 0;
      l10    <= 0;
      l11    <= 0;
      l12    <= 0;
      l13    <= 0;
      l14    <= 0;
      l15    <= 0;
      l16    <= 0;
      r0     <= 0;
      r1     <= 0;
      r2     <= 0;
      r3     <= 0;
      r4     <= 0;
      r5     <= 0;
      r6     <= 0;
      r7     <= 0;
      r8     <= 0;
      r9     <= 0;
      r10    <= 0;
      r11    <= 0;
      r12    <= 0;
      r13    <= 0;
      r14    <= 0;
      r15    <= 0;
      r16    <= 0;
      data_o <= 0;
    end
    else begin
      // output stage
      data_o <= ipn({r16, l16});
      // 16. stage
      l16   <= r15;
      r16   <= l15 ^ (f(r15, key16));
      // 15. stage
      l15   <= r14;
      r15   <= l14 ^ (f(r14, key15));
      // 14. stage
      l14   <= r13;
      r14   <= l13 ^ (f(r13, key14));
      // 13. stage
      l13   <= r12;
      r13   <= l12 ^ (f(r12, key13));
      // 12. stage
      l12   <= r11;
      r12   <= l11 ^ (f(r11, key12));
      // 11. stage
      l11   <= r10;
      r11   <= l10 ^ (f(r10, key11));
      // 10. stage
      l10   <= r9;
      r10   <= l9 ^ (f(r9, key10));
      // 9. stage
      l9   <= r8;
      r9   <= l8 ^ (f(r8, key9));
      // 8. stage
      l8   <= r7;
      r8   <= l7 ^ (f(r7, key8));
      // 7. stage
      l7   <= r6;
      r7   <= l6 ^ (f(r6, key7));
      // 6. stage
      l6   <= r5;
      r6   <= l5 ^ (f(r5, key6));
      // 5. stage
      l5   <= r4;
      r5   <= l4 ^ (f(r4, key5));
      // 4. stage
      l4   <= r3;
      r4   <= l3 ^ (f(r3, key4));
      // 3. stage
      l3   <= r2;
      r3   <= l2 ^ (f(r2, key3));
      // 2. stage
      l2   <= r1;
      r2   <= l1 ^ (f(r1, key2));
      // 1. stage
      l1   <= r0;
      r1   <= l0 ^ (f(r0, key1));
      // 1. state
      l0   <= l;
      r0   <= r;
      // input stage
      l   <= ip0(data_i);
      r   <= ip1(data_i);
    end
  end

  // des key pipeline
  always @(posedge clk_i, negedge reset_i) begin
    if(~reset_i) begin
      c0     <= 0;
      c1     <= 0;
      c2     <= 0;
      c3     <= 0;
      c4     <= 0;
      c5     <= 0;
      c6     <= 0;
      c7     <= 0;
      c8     <= 0;
      c9     <= 0;
      c10    <= 0;
      c11    <= 0;
      c12    <= 0;
      c13    <= 0;
      c14    <= 0;
      c15    <= 0;
      c16    <= 0;
      d0     <= 0;
      d1     <= 0;
      d2     <= 0;
      d3     <= 0;
      d4     <= 0;
      d5     <= 0;
      d6     <= 0;
      d7     <= 0;
      d8     <= 0;
      d9     <= 0;
      d10    <= 0;
      d11    <= 0;
      d12    <= 0;
      d13    <= 0;
      d14    <= 0;
      d15    <= 0;
      d16    <= 0;
    end
    else begin
      // input stage
      c0 <= pc1_c(key_i);
      d0 <= pc1_d(key_i);
      // 1st stage
      if (~mode[0]) begin
        c1 <= {c0[1:27], c0[0]};
        d1 <= {d0[1:27], d0[0]};
      end
      else begin
        c1 <= c0;
        d1 <= d0;
      end
      // 2nd stage
      if (~mode[1]) begin
        c2 <= {c1[1:27], c1[0]};
        d2 <= {d1[1:27], d1[0]};
      end
      else begin
        c2 <= {c1[27], c1[0:26]};
        d2 <= {d1[27], d1[0:26]};
      end
      // 3rd stage
      if (~mode[2]) begin
        c3 <= {c2[2:27], c2[0:1]};
        d3 <= {d2[2:27], d2[0:1]};
      end
      else begin
        c3 <= {c2[26:27], c2[0:25]};
        d3 <= {d2[26:27], d2[0:25]};
      end
      // 4th stage
      if (~mode[3]) begin
        c4 <= {c3[2:27], c3[0:1]};
        d4 <= {d3[2:27], d3[0:1]};
      end
      else begin
        c4 <= {c3[26:27], c3[0:25]};
        d4 <= {d3[26:27], d3[0:25]};
      end
      // 5th stage
      if (~mode[4]) begin
        c5 <= {c4[2:27], c4[0:1]};
        d5 <= {d4[2:27], d4[0:1]};
      end
      else begin
        c5 <= {c4[26:27], c4[0:25]};
        d5 <= {d4[26:27], d4[0:25]};
      end
      // 6. stage
      if (~mode[5]) begin
        c6 <= {c5[2:27], c5[0:1]};
        d6 <= {d5[2:27], d5[0:1]};
      end
      else begin
        c6 <= {c5[26:27], c5[0:25]};
        d6 <= {d5[26:27], d5[0:25]};
      end
      // 7. stage
      if (~mode[6]) begin
        c7 <= {c6[2:27], c6[0:1]};
        d7 <= {d6[2:27], d6[0:1]};
      end
      else begin
        c7 <= {c6[26:27], c6[0:25]};
        d7 <= {d6[26:27], d6[0:25]};
      end
      // 8. stage
      if (~mode[7]) begin
        c8 <= {c7[2:27], c7[0:1]};
        d8 <= {d7[2:27], d7[0:1]};
      end
      else begin
        c8 <= {c7[26:27], c7[0:25]};
        d8 <= {d7[26:27], d7[0:25]};
      end
      // 9. stage
      if (~mode[8]) begin
        c9 <= {c8[1:27], c8[0]};
        d9 <= {d8[1:27], d8[0]};
      end
      else begin
        c9 <= {c8[27], c8[0:26]};
        d9 <= {d8[27], d8[0:26]};
      end
      // 10. stage
      if (~mode[9]) begin
        c10 <= {c9[2:27], c9[0:1]};
        d10 <= {d9[2:27], d9[0:1]};
      end
      else begin
        c10 <= {c9[26:27], c9[0:25]};
        d10 <= {d9[26:27], d9[0:25]};
      end
      // 6. stage
      if (~mode[10]) begin
        c11 <= {c10[2:27], c10[0:1]};
        d11 <= {d10[2:27], d10[0:1]};
      end
      else begin
        c11 <= {c10[26:27], c10[0:25]};
        d11 <= {d10[26:27], d10[0:25]};
      end
      // 6. stage
      if (~mode[11]) begin
        c12 <= {c11[2:27], c11[0:1]};
        d12 <= {d11[2:27], d11[0:1]};
      end
      else begin
        c12 <= {c11[26:27], c11[0:25]};
        d12 <= {d11[26:27], d11[0:25]};
      end
      // 6. stage
      if (~mode[12]) begin
        c13 <= {c12[2:27], c12[0:1]};
        d13 <= {d12[2:27], d12[0:1]};
      end
      else begin
        c13 <= {c12[26:27], c12[0:25]};
        d13 <= {d12[26:27], d12[0:25]};
      end
      // 6. stage
      if (~mode[13]) begin
        c14 <= {c13[2:27], c13[0:1]};
        d14 <= {d13[2:27], d13[0:1]};
      end
      else begin
        c14 <= {c13[26:27], c13[0:25]};
        d14 <= {d13[26:27], d13[0:25]};
      end
      // 6. stage
      if (~mode[14]) begin
        c15 <= {c14[2:27], c14[0:1]};
        d15 <= {d14[2:27], d14[0:1]};
      end
      else begin
        c15 <= {c14[26:27], c14[0:25]};
        d15 <= {d14[26:27], d14[0:25]};
      end
      // 6. stage
      if (~mode[15]) begin
        c16 <= {c15[1:27], c15[0]};
        d16 <= {d15[1:27], d15[0]};
      end
      else begin
        c16 <= {c15[27], c15[0:26]};
        d16 <= {d15[27], d15[0:26]};
      end
    end
  end

  // key assignments
  assign key1  = pc2({c1, d1});
  assign key2  = pc2({c2, d2});
  assign key3  = pc2({c3, d3});
  assign key4  = pc2({c4, d4});
  assign key5  = pc2({c5, d5});
  assign key6  = pc2({c6, d6});
  assign key7  = pc2({c7, d7});
  assign key8  = pc2({c8, d8});
  assign key9  = pc2({c9, d9});
  assign key10 = pc2({c10, d10});
  assign key11 = pc2({c11, d11});
  assign key12 = pc2({c12, d12});
  assign key13 = pc2({c13, d13});
  assign key14 = pc2({c14, d14});
  assign key15 = pc2({c15, d15});
  assign key16 = pc2({c16, d16});


endmodule

module cbcdes
  (
    input             reset_i,  // async reset
    input             clk_i,    // clock
    input             start_i,  // start cbc
    input             mode_i,   // des-mode: 0 = encrypt, 1 = decrypt
    input  [0:63]     key_i,    // key input
    input  [0:63]     iv_i,     // iv input
    input  [0:63]     data_i,   // data input
    input             valid_i,  // input key/data valid flag
    output reg        ready_o,  // ready to encrypt/decrypt
    output reg [0:63] data_o,   // data output
    output            valid_o   // output data valid flag
  );


  reg         mode;
  wire        des_mode;
  reg         start;
  reg  [0:63] key;
  wire [0:63] des_key;
  reg  [0:63] iv;
  reg  [0:63] datain;
  reg  [0:63] datain_d;
  reg  [0:63] des_datain;
  wire        validin;
  wire [0:63] des_dataout;
  reg         reset;
  reg  [0:63] dataout;



  assign des_key  = (start_i) ? key_i  : key;
  assign des_mode = (start_i) ? mode_i : mode;

  assign validin = valid_i & ready_o;


  always @(*) begin
    if (~mode_i && start_i) begin
      des_datain = iv_i ^ data_i;
    end
    else if (~mode && ~start_i) begin
      des_datain = dataout ^ data_i;
    end
    else begin
      des_datain = data_i;
    end
  end


  always @(*) begin
    if (mode && start) begin
      data_o = iv ^ des_dataout;
    end
    else if (mode && ~start) begin
      data_o = datain_d ^ des_dataout;
    end
    else begin
      data_o = des_dataout;
    end
  end


  // input register
  always @(posedge clk_i, negedge reset_i) begin
    if (~reset_i) begin
      reset    <= 0;
      mode     <= 0;
      start    <= 0;
      key      <= 0;
      iv       <= 0;
      datain   <= 0;
      datain_d <= 0;
    end
    else begin
      reset <= reset_i;
      if (valid_i && ready_o) begin
        start    <= start_i;
        datain   <= data_i;
        datain_d <= datain;
      end
      else if (valid_i && ready_o && start_i) begin
        mode <= mode_i;
        key  <= key_i;
        iv   <= iv_i;
      end
    end
  end


  // output register
  always @(posedge clk_i, negedge reset_i) begin
    if (~reset_i) begin
      ready_o <= 0;
      dataout <= 0;
    end
    else begin
      if (valid_i && ready_o) begin
        ready_o <= 0;
      end
      else if (valid_o || (reset_i && ~reset)) begin
        ready_o <= 1;
        dataout <= des_dataout;
      end
    end
  end


  // des instance
  des i_des (
    .reset_i(reset),
    .clk_i(clk_i),
    .mode_i(des_mode),
    .key_i(des_key),
    .data_i(des_datain),
    .valid_i(validin),
    .data_o(des_dataout),
    .valid_o(valid_o)
  );


endmodule
