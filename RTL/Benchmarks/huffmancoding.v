module huffman_coding
  (input logic signed [10:0] ac_input,
   input logic signed [11:0] dc_input,
   input enable, clk, img_rst, 
   output logic [31:0] jpeg_bitstream,
   output logic dataready);




logic dc_msb;
logic [10:0] dc_pos,dc_vli_inp;
logic [11:0] dc_neg;
logic [3:0] dc_index,dc_pos_index,dc_neg_index;

logic [3:0] dc_vli_count,dc_size,dc_huff_count;
logic [4:0] dc_total_count; //max is 20 only
logic [8:0] dc_huff_code;

logic [10:0] dc_vli_code, dc_vli_code_shifted_int;
logic [19:0] dc_vli_code_shifted,dc_full_code;


logic [3:0] zrl; //zero run length 0 to 15
logic [5:0] zrl_long; //can count upto 63 continuous zeros
logic [1:0] count_sixteen_zeros, stream_sel;
logic [1:0] zrl_long_msb,zrl_long_msb_1;
logic incr_count_sixteen_zeros, shift_mux_sel;
logic zero_check;
logic  shift_en1, shift_en2, shift_en3;


logic [10:0] ac_neg;
logic ac_msb;
logic [9:0] ac_pos, ac_vli_inp, ac_vli_code;
logic [3:0] ac_index,ac_pos_index,ac_neg_index;
logic [3:0] ac_size, ac_vli_count;
logic [15:0] ac_huff_code;
logic [4:0] ac_huff_count, ac_total_count, ac_total_count_1, ac_total_count_2, ac_total_count_buf1, ac_total_count_buf2, ac_total_count_buf3, ac_strmout_total_count;
logic [9:0] ac_vli_code_shifted_int;
logic [25:0] ac_vli_code_shifted, ac_full_code, ac_full_code_1, ac_full_code_2, ac_code_buf1, ac_code_buf2, ac_code_buf3, ac_strmout_full_code;

logic [4:0] orc, orc_1, orc_2; //output register count -> number of bits used in current jpeg 32 bit stream


logic [7:0] block_counter; 
logic eob, eob_buf1, eob_buf2, eob_buf3, eob_strmout, eob_final, eob_final_1, eob_final_2;

logic [25:0] jpeg_bits, jpeg_bits_1;
logic [31:0] jpeg_bits_tmp, jpeg_bits_shifted, jpeg_ro_bits;



logic rollover, data_ready_special;
logic enable_module, enable_1;

/////////////////////////////////HUFFMAN CODING LUTs//////////////////////

assign dc_msb = dc_input[11];
assign dc_pos = dc_input[10:0];
assign dc_neg = dc_input-1;
assign dc_index = dc_msb ? dc_neg_index : dc_pos_index;
assign dc_vli_inp = dc_msb ? dc_neg[10:0] : dc_pos;


always_comb 
begin
  if (dc_pos[10] ==1)
    dc_pos_index = 4'd10; //11(size or category)
  else if (dc_pos[9] ==1)
    dc_pos_index = 4'd9;  //10
  else if (dc_pos[8] ==1)
    dc_pos_index = 4'd8;  //9
  else if (dc_pos[7] ==1)     
    dc_pos_index = 4'd7;  //8
  else if (dc_pos[6] ==1)     
    dc_pos_index = 4'd6;  //7
  else if (dc_pos[5] ==1)     
    dc_pos_index = 4'd5;  //6
  else if (dc_pos[4] ==1)     
    dc_pos_index = 4'd4;  //5
  else if (dc_pos[3] ==1)     
    dc_pos_index = 4'd3;  //4
  else if (dc_pos[2] ==1)     
    dc_pos_index = 4'd2;  //3
  else if (dc_pos[1] ==1)     
    dc_pos_index = 4'd1;  //2
  else if (dc_pos[0] ==1) 
    dc_pos_index = 4'd0;  //1
  else
    dc_pos_index = 4'd15; //0
end  


always_comb 
begin
  if (dc_neg[11] ==1'b0)
    dc_neg_index = 4'd11;  //11(size or category)
  else if (dc_neg[10] ==1'b0)
    dc_neg_index = 4'd10;  //11
  else if (dc_neg[9] ==1'b0)
    dc_neg_index = 4'd9;   //10
  else if (dc_neg[8] ==1'b0) 
    dc_neg_index = 4'd8;   //9
  else if (dc_neg[7] ==1'b0)      
    dc_neg_index = 4'd7;   //8
  else if (dc_neg[6] ==1'b0)      
    dc_neg_index = 4'd6;   //7
  else if (dc_neg[5] ==1'b0)      
    dc_neg_index = 4'd5;   //6
  else if (dc_neg[4] ==1'b0)      
    dc_neg_index = 4'd4;   //5
  else if (dc_neg[3] ==1'b0)      
    dc_neg_index = 4'd3;   //4
  else if (dc_neg[2] ==1'b0)      
    dc_neg_index = 4'd2;   //3
  else if (dc_neg[1] ==1'b0)      
    dc_neg_index = 4'd1;   //2
  else if (dc_neg[0] ==1'b0)  
    dc_neg_index = 4'd0;   //1
  else                           
    dc_neg_index = 4'd15;  //0
end  

always_comb  //DC code size LUT : find dc category and vlc huff code (and huff code bit count) for DC
begin
  case(dc_index)
    11,10 : begin dc_size = 4'd11; dc_huff_code = 9'b111111110; dc_huff_count=4'd9;end
    9  : begin dc_size = 4'd10; dc_huff_code    = 9'b111111100; dc_huff_count=4'd8;end
    8  : begin  dc_size = 4'd9; dc_huff_code    = 9'b111111000; dc_huff_count=4'd7;end
    7  : begin dc_size = 4'd8; dc_huff_code     = 9'b111110000; dc_huff_count=4'd6;end
    6  : begin dc_size = 4'd7; dc_huff_code     = 9'b111100000; dc_huff_count=4'd5;end
    5  : begin dc_size = 4'd6; dc_huff_code     = 9'b111000000; dc_huff_count=4'd4;end
    4  : begin dc_size = 4'd5; dc_huff_code     = 9'b110000000; dc_huff_count=4'd3;end
    3  : begin dc_size = 4'd4; dc_huff_code     = 9'b101000000; dc_huff_count=4'd3;end
    2  : begin dc_size = 4'd3; dc_huff_code     = 9'b100000000; dc_huff_count=4'd3;end
    1  : begin dc_size = 4'd2; dc_huff_code     = 9'b011000000; dc_huff_count=4'd3;end
    0  : begin dc_size = 4'd1; dc_huff_code     = 9'b010000000; dc_huff_count=4'd3;end
    default : begin dc_size = 4'd0;  dc_huff_code     = 9'b000000000; dc_huff_count=4'd2;end
  endcase
end

assign dc_vli_count=dc_size;

always_comb // DC VLI look up table
begin
  dc_vli_code = 11'd0;
  case (dc_vli_count)
    11 : dc_vli_code[10:0] = dc_vli_inp[10:0];
    10 : dc_vli_code[9:0] = dc_vli_inp[9:0];     
    9 : dc_vli_code[8:0] = dc_vli_inp[8:0]; 
    8 : dc_vli_code[7:0] = dc_vli_inp[7:0]; 
    7 : dc_vli_code[6:0] = dc_vli_inp[6:0]; 
    6 : dc_vli_code[5:0] = dc_vli_inp[5:0]; 
    5 : dc_vli_code[4:0] = dc_vli_inp[4:0]; 
    4 : dc_vli_code[3:0] = dc_vli_inp[3:0]; 
    3 : dc_vli_code[2:0] = dc_vli_inp[2:0]; 
    2 : dc_vli_code[1:0] = dc_vli_inp[1:0]; 
    1 : dc_vli_code[0] = dc_vli_inp[0]; 
    default : dc_vli_code[0] = dc_vli_inp[0];
  endcase
end


/////////////AC LUTs//////////////////////////

assign ac_msb = ac_input[10];
assign ac_pos = ac_input[9:0];
assign ac_neg = ac_input-1;
assign ac_index = ac_msb ? ac_neg_index : ac_pos_index;
assign ac_vli_inp = ac_msb ? ac_neg[9:0] : ac_pos;

always_comb 
begin
  if (ac_pos[9] ==1)
    ac_pos_index = 4'd9;  //10 (coefficient size or category)
  else if (ac_pos[8] ==1)
    ac_pos_index = 4'd8;  //9
  else if (ac_pos[7] ==1)     
    ac_pos_index = 4'd7;  //8
  else if (ac_pos[6] ==1)     
    ac_pos_index = 4'd6;  //7
  else if (ac_pos[5] ==1)     
    ac_pos_index = 4'd5;  //6
  else if (ac_pos[4] ==1)     
    ac_pos_index = 4'd4;  //5
  else if (ac_pos[3] ==1)     
    ac_pos_index = 4'd3;  //4
  else if (ac_pos[2] ==1)     
    ac_pos_index = 4'd2;  //3
  else if (ac_pos[1] ==1)     
    ac_pos_index = 4'd1;  //2
  else if (ac_pos[0] ==1) 
    ac_pos_index = 4'd0;  //1
  else
    ac_pos_index = 4'd15; //0
end  

always_comb 
begin
  if (ac_neg[10] ==1'b0)
    ac_neg_index = 4'd10;  //10(coefficient size or category)
  else if (ac_neg[9] ==1'b0)
    ac_neg_index = 4'd9;   //10
  else if (ac_neg[8] ==1'b0) 
    ac_neg_index = 4'd8;   //9
  else if (ac_neg[7] ==1'b0)      
    ac_neg_index = 4'd7;   //8
  else if (ac_neg[6] ==1'b0)      
    ac_neg_index = 4'd6;   //7
  else if (ac_neg[5] ==1'b0)      
    ac_neg_index = 4'd5;   //6
  else if (ac_neg[4] ==1'b0)      
    ac_neg_index = 4'd4;   //5
  else if (ac_neg[3] ==1'b0)      
    ac_neg_index = 4'd3;   //4
  else if (ac_neg[2] ==1'b0)      
    ac_neg_index = 4'd2;   //3
  else if (ac_neg[1] ==1'b0)      
    ac_neg_index = 4'd1;   //2
  else if (ac_neg[0] ==1'b0)  
    ac_neg_index = 4'd0;   //1
  else                           
    ac_neg_index = 4'd15;  //0
end  

always_comb
begin
  case (ac_index)
    10,9 : ac_size = 4'd10;
    8  :  ac_size = 4'd9;
    7  : ac_size = 4'd8; 
    6  : ac_size = 4'd7; 
    5  : ac_size = 4'd6; 
    4  : ac_size = 4'd5; 
    3  : ac_size = 4'd4; 
    2  : ac_size = 4'd3; 
    1  : ac_size = 4'd2; 
    0  : ac_size = 4'd1; 
    default : ac_size = 4'd0;
  endcase      
end

always_comb
begin
  case ({zrl,ac_size})
    {4'd0,4'd1 } : begin ac_huff_code = 16'b0000_0000_0000_0000; ac_huff_count = 5'd2; end
    {4'd0,4'd2 } : begin ac_huff_code = 16'b0100_0000_0000_0000; ac_huff_count = 5'd2; end
    {4'd0,4'd3 } : begin ac_huff_code = 16'b1000_0000_0000_0000; ac_huff_count = 5'd3; end
    {4'd0,4'd4 } : begin ac_huff_code = 16'b1011_0000_0000_0000; ac_huff_count = 5'd4; end
    {4'd0,4'd5 } : begin ac_huff_code = 16'b1101_0000_0000_0000; ac_huff_count = 5'd5; end
    {4'd0,4'd6 } : begin ac_huff_code = 16'b1111_0000_0000_0000; ac_huff_count = 5'd7; end
    {4'd0,4'd7 } : begin ac_huff_code = 16'b1111_1000_0000_0000; ac_huff_count = 5'd8; end
    {4'd0,4'd8 } : begin ac_huff_code = 16'b1111_1101_1000_0000; ac_huff_count = 5'd10; end
    {4'd0,4'd9 } : begin ac_huff_code = 16'b1111_1111_1000_0010; ac_huff_count = 5'd16; end
    {4'd0,4'd10} : begin ac_huff_code = 16'b1111_1111_1000_0011; ac_huff_count = 5'd16; end
    ////////
    {4'd1,4'd1 } : begin ac_huff_code = 16'b1100_0000_0000_0000; ac_huff_count = 5'd4; end
    {4'd1,4'd2 } : begin ac_huff_code = 16'b1101_1000_0000_0000; ac_huff_count = 5'd5; end
    {4'd1,4'd3 } : begin ac_huff_code = 16'b1111_0010_0000_0000; ac_huff_count = 5'd7; end
    {4'd1,4'd4 } : begin ac_huff_code = 16'b1111_1011_0000_0000; ac_huff_count = 5'd9; end
    {4'd1,4'd5 } : begin ac_huff_code = 16'b1111_1110_1100_0000; ac_huff_count = 5'd11; end
    {4'd1,4'd6 } : begin ac_huff_code = 16'b1111_1111_1000_0100; ac_huff_count = 5'd16; end
    {4'd1,4'd7 } : begin ac_huff_code = 16'b1111_1111_1000_0101; ac_huff_count = 5'd16; end
    {4'd1,4'd8 } : begin ac_huff_code = 16'b1111_1111_1000_0110; ac_huff_count = 5'd16; end
    {4'd1,4'd9 } : begin ac_huff_code = 16'b1111_1111_1000_0111; ac_huff_count = 5'd16; end
    {4'd1,4'd10} : begin ac_huff_code = 16'b1111_1111_1000_1000; ac_huff_count = 5'd16; end
    ////////
    {4'd2,4'd1 } : begin ac_huff_code = 16'b1110_0000_0000_0000; ac_huff_count = 5'd5; end
    {4'd2,4'd2 } : begin ac_huff_code = 16'b1111_1001_0000_0000; ac_huff_count = 5'd8; end
    {4'd2,4'd3 } : begin ac_huff_code = 16'b1111_1101_1100_0000; ac_huff_count = 5'd10; end
    {4'd2,4'd4 } : begin ac_huff_code = 16'b1111_1111_0100_0000; ac_huff_count = 5'd12; end
    {4'd2,4'd5 } : begin ac_huff_code = 16'b1111_1111_1000_1001; ac_huff_count = 5'd16; end
    {4'd2,4'd6 } : begin ac_huff_code = 16'b1111_1111_1000_1010; ac_huff_count = 5'd16; end
    {4'd2,4'd7 } : begin ac_huff_code = 16'b1111_1111_1000_1011; ac_huff_count = 5'd16; end
    {4'd2,4'd8 } : begin ac_huff_code = 16'b1111_1111_1000_1100; ac_huff_count = 5'd16; end
    {4'd2,4'd9 } : begin ac_huff_code = 16'b1111_1111_1000_1101; ac_huff_count = 5'd16; end
    {4'd2,4'd10} : begin ac_huff_code = 16'b1111_1111_1000_1110; ac_huff_count = 5'd16; end
    ////////
    {4'd3,4'd1 } : begin ac_huff_code = 16'b1110_1000_0000_0000; ac_huff_count = 5'd6; end
    {4'd3,4'd2 } : begin ac_huff_code = 16'b1111_1011_1000_0000; ac_huff_count = 5'd9; end
    {4'd3,4'd3 } : begin ac_huff_code = 16'b1111_1111_0101_0000; ac_huff_count = 5'd12; end
    {4'd3,4'd4 } : begin ac_huff_code = 16'b1111_1111_1000_1111; ac_huff_count = 5'd16; end
    {4'd3,4'd5 } : begin ac_huff_code = 16'b1111_1111_1001_0000; ac_huff_count = 5'd16; end
    {4'd3,4'd6 } : begin ac_huff_code = 16'b1111_1111_1001_0001; ac_huff_count = 5'd16; end
    {4'd3,4'd7 } : begin ac_huff_code = 16'b1111_1111_1001_0010; ac_huff_count = 5'd16; end
    {4'd3,4'd8 } : begin ac_huff_code = 16'b1111_1111_1001_0011; ac_huff_count = 5'd16; end
    {4'd3,4'd9 } : begin ac_huff_code = 16'b1111_1111_1001_0100; ac_huff_count = 5'd16; end
    {4'd3,4'd10} : begin ac_huff_code = 16'b1111_1111_1001_0101; ac_huff_count = 5'd16; end
    ////////
    {4'd4,4'd1 } : begin ac_huff_code = 16'b1110_1100_0000_0000; ac_huff_count = 5'd6; end
    {4'd4,4'd2 } : begin ac_huff_code = 16'b1111_1110_0000_0000; ac_huff_count = 5'd10; end
    {4'd4,4'd3 } : begin ac_huff_code = 16'b1111_1111_1001_0110; ac_huff_count = 5'd16; end
    {4'd4,4'd4 } : begin ac_huff_code = 16'b1111_1111_1001_0111; ac_huff_count = 5'd16; end
    {4'd4,4'd5 } : begin ac_huff_code = 16'b1111_1111_1001_1000; ac_huff_count = 5'd16; end
    {4'd4,4'd6 } : begin ac_huff_code = 16'b1111_1111_1001_1001; ac_huff_count = 5'd16; end
    {4'd4,4'd7 } : begin ac_huff_code = 16'b1111_1111_1001_1010; ac_huff_count = 5'd16; end
    {4'd4,4'd8 } : begin ac_huff_code = 16'b1111_1111_1001_1011; ac_huff_count = 5'd16; end
    {4'd4,4'd9 } : begin ac_huff_code = 16'b1111_1111_1001_1100; ac_huff_count = 5'd16; end
    {4'd4,4'd10} : begin ac_huff_code = 16'b1111_1111_1001_1101; ac_huff_count = 5'd16; end
    ////////
    {4'd5,4'd1 } : begin ac_huff_code = 16'b1111_0100_0000_0000; ac_huff_count = 5'd7; end
    {4'd5,4'd2 } : begin ac_huff_code = 16'b1111_1110_1110_0000; ac_huff_count = 5'd11; end
    {4'd5,4'd3 } : begin ac_huff_code = 16'b1111_1111_1001_1110; ac_huff_count = 5'd16; end
    {4'd5,4'd4 } : begin ac_huff_code = 16'b1111_1111_1001_1111; ac_huff_count = 5'd16; end
    {4'd5,4'd5 } : begin ac_huff_code = 16'b1111_1111_1010_0000; ac_huff_count = 5'd16; end
    {4'd5,4'd6 } : begin ac_huff_code = 16'b1111_1111_1010_0001; ac_huff_count = 5'd16; end
    {4'd5,4'd7 } : begin ac_huff_code = 16'b1111_1111_1010_0010; ac_huff_count = 5'd16; end
    {4'd5,4'd8 } : begin ac_huff_code = 16'b1111_1111_1010_0011; ac_huff_count = 5'd16; end
    {4'd5,4'd9 } : begin ac_huff_code = 16'b1111_1111_1010_0100; ac_huff_count = 5'd16; end
    {4'd5,4'd10} : begin ac_huff_code = 16'b1111_1111_1010_0101; ac_huff_count = 5'd16; end
    ////////
    {4'd6,4'd1 } : begin ac_huff_code = 16'b1111_0110_0000_0000; ac_huff_count = 5'd7; end
    {4'd6,4'd2 } : begin ac_huff_code = 16'b1111_1111_0110_0000; ac_huff_count = 5'd12; end
    {4'd6,4'd3 } : begin ac_huff_code = 16'b1111_1111_1010_0110; ac_huff_count = 5'd16; end
    {4'd6,4'd4 } : begin ac_huff_code = 16'b1111_1111_1010_0111; ac_huff_count = 5'd16; end
    {4'd6,4'd5 } : begin ac_huff_code = 16'b1111_1111_1010_1000; ac_huff_count = 5'd16; end
    {4'd6,4'd6 } : begin ac_huff_code = 16'b1111_1111_1010_1001; ac_huff_count = 5'd16; end
    {4'd6,4'd7 } : begin ac_huff_code = 16'b1111_1111_1010_1010; ac_huff_count = 5'd16; end
    {4'd6,4'd8 } : begin ac_huff_code = 16'b1111_1111_1010_1011; ac_huff_count = 5'd16; end
    {4'd6,4'd9 } : begin ac_huff_code = 16'b1111_1111_1010_1100; ac_huff_count = 5'd16; end
    {4'd6,4'd10} : begin ac_huff_code = 16'b1111_1111_1010_1101; ac_huff_count = 5'd16; end
    ////////
    {4'd7,4'd1 } : begin ac_huff_code = 16'b1111_1010_0000_0000; ac_huff_count = 5'd8; end
    {4'd7,4'd2 } : begin ac_huff_code = 16'b1111_1111_0111_0000; ac_huff_count = 5'd12; end
    {4'd7,4'd3 } : begin ac_huff_code = 16'b1111_1111_1010_1110; ac_huff_count = 5'd16; end
    {4'd7,4'd4 } : begin ac_huff_code = 16'b1111_1111_1010_1111; ac_huff_count = 5'd16; end
    {4'd7,4'd5 } : begin ac_huff_code = 16'b1111_1111_1011_0000; ac_huff_count = 5'd16; end
    {4'd7,4'd6 } : begin ac_huff_code = 16'b1111_1111_1011_0001; ac_huff_count = 5'd16; end
    {4'd7,4'd7 } : begin ac_huff_code = 16'b1111_1111_1011_0010; ac_huff_count = 5'd16; end
    {4'd7,4'd8 } : begin ac_huff_code = 16'b1111_1111_1011_0011; ac_huff_count = 5'd16; end
    {4'd7,4'd9 } : begin ac_huff_code = 16'b1111_1111_1011_0100; ac_huff_count = 5'd16; end
    {4'd7,4'd10} : begin ac_huff_code = 16'b1111_1111_1011_0101; ac_huff_count = 5'd16; end
    ////////
    {4'd8,4'd1 } : begin ac_huff_code = 16'b1111_1100_0000_0000; ac_huff_count = 5'd9; end
    {4'd8,4'd2 } : begin ac_huff_code = 16'b1111_1111_1000_0000; ac_huff_count = 5'd15; end
    {4'd8,4'd3 } : begin ac_huff_code = 16'b1111_1111_1011_0110; ac_huff_count = 5'd16; end
    {4'd8,4'd4 } : begin ac_huff_code = 16'b1111_1111_1011_0111; ac_huff_count = 5'd16; end
    {4'd8,4'd5 } : begin ac_huff_code = 16'b1111_1111_1011_1000; ac_huff_count = 5'd16; end
    {4'd8,4'd6 } : begin ac_huff_code = 16'b1111_1111_1011_1001; ac_huff_count = 5'd16; end
    {4'd8,4'd7 } : begin ac_huff_code = 16'b1111_1111_1011_1010; ac_huff_count = 5'd16; end
    {4'd8,4'd8 } : begin ac_huff_code = 16'b1111_1111_1011_1011; ac_huff_count = 5'd16; end
    {4'd8,4'd9 } : begin ac_huff_code = 16'b1111_1111_1011_1100; ac_huff_count = 5'd16; end
    {4'd8,4'd10} : begin ac_huff_code = 16'b1111_1111_1011_1101; ac_huff_count = 5'd16; end
    ////////
    {4'd9,4'd1 } : begin ac_huff_code = 16'b1111_1100_1000_0000; ac_huff_count = 5'd9; end
    {4'd9,4'd2 } : begin ac_huff_code = 16'b1111_1111_1011_1110; ac_huff_count = 5'd16; end
    {4'd9,4'd3 } : begin ac_huff_code = 16'b1111_1111_1011_1111; ac_huff_count = 5'd16; end
    {4'd9,4'd4 } : begin ac_huff_code = 16'b1111_1111_1100_0000; ac_huff_count = 5'd16; end
    {4'd9,4'd5 } : begin ac_huff_code = 16'b1111_1111_1100_0001; ac_huff_count = 5'd16; end
    {4'd9,4'd6 } : begin ac_huff_code = 16'b1111_1111_1100_0010; ac_huff_count = 5'd16; end
    {4'd9,4'd7 } : begin ac_huff_code = 16'b1111_1111_1100_0011; ac_huff_count = 5'd16; end
    {4'd9,4'd8 } : begin ac_huff_code = 16'b1111_1111_1100_0100; ac_huff_count = 5'd16; end
    {4'd9,4'd9 } : begin ac_huff_code = 16'b1111_1111_1100_0101; ac_huff_count = 5'd16; end
    {4'd9,4'd10} : begin ac_huff_code = 16'b1111_1111_1100_0110; ac_huff_count = 5'd16; end
    ////////
    {4'd10,4'd1 } : begin ac_huff_code = 16'b1111_1101_0000_0000; ac_huff_count = 5'd9; end
    {4'd10,4'd2 } : begin ac_huff_code = 16'b1111_1111_1100_0111; ac_huff_count = 5'd16; end
    {4'd10,4'd3 } : begin ac_huff_code = 16'b1111_1111_1100_1000; ac_huff_count = 5'd16; end
    {4'd10,4'd4 } : begin ac_huff_code = 16'b1111_1111_1100_1001; ac_huff_count = 5'd16; end
    {4'd10,4'd5 } : begin ac_huff_code = 16'b1111_1111_1100_1010; ac_huff_count = 5'd16; end
    {4'd10,4'd6 } : begin ac_huff_code = 16'b1111_1111_1100_1011; ac_huff_count = 5'd16; end
    {4'd10,4'd7 } : begin ac_huff_code = 16'b1111_1111_1100_1100; ac_huff_count = 5'd16; end
    {4'd10,4'd8 } : begin ac_huff_code = 16'b1111_1111_1100_1101; ac_huff_count = 5'd16; end
    {4'd10,4'd9 } : begin ac_huff_code = 16'b1111_1111_1100_1110; ac_huff_count = 5'd16; end
    {4'd10,4'd10} : begin ac_huff_code = 16'b1111_1111_1100_1111; ac_huff_count = 5'd16; end
    ////////
    {4'd11,4'd1 } : begin ac_huff_code = 16'b1111_1110_0100_0000; ac_huff_count = 5'd10; end
    {4'd11,4'd2 } : begin ac_huff_code = 16'b1111_1111_1101_0000; ac_huff_count = 5'd16; end
    {4'd11,4'd3 } : begin ac_huff_code = 16'b1111_1111_1101_0001; ac_huff_count = 5'd16; end
    {4'd11,4'd4 } : begin ac_huff_code = 16'b1111_1111_1101_0010; ac_huff_count = 5'd16; end
    {4'd11,4'd5 } : begin ac_huff_code = 16'b1111_1111_1101_0011; ac_huff_count = 5'd16; end
    {4'd11,4'd6 } : begin ac_huff_code = 16'b1111_1111_1101_0100; ac_huff_count = 5'd16; end
    {4'd11,4'd7 } : begin ac_huff_code = 16'b1111_1111_1101_0101; ac_huff_count = 5'd16; end
    {4'd11,4'd8 } : begin ac_huff_code = 16'b1111_1111_1101_0110; ac_huff_count = 5'd16; end
    {4'd11,4'd9 } : begin ac_huff_code = 16'b1111_1111_1101_0111; ac_huff_count = 5'd16; end
    {4'd11,4'd10} : begin ac_huff_code = 16'b1111_1111_1101_1000; ac_huff_count = 5'd16; end
    ////////
    {4'd12,4'd1 } : begin ac_huff_code = 16'b1111_1110_1000_0000; ac_huff_count = 5'd10; end
    {4'd12,4'd2 } : begin ac_huff_code = 16'b1111_1111_1101_1001; ac_huff_count = 5'd16; end
    {4'd12,4'd3 } : begin ac_huff_code = 16'b1111_1111_1101_1010; ac_huff_count = 5'd16; end
    {4'd12,4'd4 } : begin ac_huff_code = 16'b1111_1111_1101_1011; ac_huff_count = 5'd16; end
    {4'd12,4'd5 } : begin ac_huff_code = 16'b1111_1111_1101_1100; ac_huff_count = 5'd16; end
    {4'd12,4'd6 } : begin ac_huff_code = 16'b1111_1111_1101_1101; ac_huff_count = 5'd16; end
    {4'd12,4'd7 } : begin ac_huff_code = 16'b1111_1111_1101_1110; ac_huff_count = 5'd16; end
    {4'd12,4'd8 } : begin ac_huff_code = 16'b1111_1111_1101_1111; ac_huff_count = 5'd16; end
    {4'd12,4'd9 } : begin ac_huff_code = 16'b1111_1111_1110_0000; ac_huff_count = 5'd16; end
    {4'd12,4'd10} : begin ac_huff_code = 16'b1111_1111_1110_0001; ac_huff_count = 5'd16; end
    ////////
    {4'd13,4'd1 } : begin ac_huff_code = 16'b1111_1111_0000_0000; ac_huff_count = 5'd11; end
    {4'd13,4'd2 } : begin ac_huff_code = 16'b1111_1111_1110_0010; ac_huff_count = 5'd16; end
    {4'd13,4'd3 } : begin ac_huff_code = 16'b1111_1111_1110_0011; ac_huff_count = 5'd16; end
    {4'd13,4'd4 } : begin ac_huff_code = 16'b1111_1111_1110_0100; ac_huff_count = 5'd16; end
    {4'd13,4'd5 } : begin ac_huff_code = 16'b1111_1111_1110_0101; ac_huff_count = 5'd16; end
    {4'd13,4'd6 } : begin ac_huff_code = 16'b1111_1111_1110_0110; ac_huff_count = 5'd16; end
    {4'd13,4'd7 } : begin ac_huff_code = 16'b1111_1111_1110_0111; ac_huff_count = 5'd16; end
    {4'd13,4'd8 } : begin ac_huff_code = 16'b1111_1111_1110_1000; ac_huff_count = 5'd16; end
    {4'd13,4'd9 } : begin ac_huff_code = 16'b1111_1111_1110_1001; ac_huff_count = 5'd16; end
    {4'd13,4'd10} : begin ac_huff_code = 16'b1111_1111_1110_1010; ac_huff_count = 5'd16; end
    ////////
    {4'd14,4'd1 } : begin ac_huff_code = 16'b1111_1111_1110_1011; ac_huff_count = 5'd16; end
    {4'd14,4'd2 } : begin ac_huff_code = 16'b1111_1111_1110_1100; ac_huff_count = 5'd16; end
    {4'd14,4'd3 } : begin ac_huff_code = 16'b1111_1111_1110_1101; ac_huff_count = 5'd16; end
    {4'd14,4'd4 } : begin ac_huff_code = 16'b1111_1111_1110_1110; ac_huff_count = 5'd16; end
    {4'd14,4'd5 } : begin ac_huff_code = 16'b1111_1111_1110_1111; ac_huff_count = 5'd16; end
    {4'd14,4'd6 } : begin ac_huff_code = 16'b1111_1111_1111_0000; ac_huff_count = 5'd16; end
    {4'd14,4'd7 } : begin ac_huff_code = 16'b1111_1111_1111_0001; ac_huff_count = 5'd16; end
    {4'd14,4'd8 } : begin ac_huff_code = 16'b1111_1111_1111_0010; ac_huff_count = 5'd16; end
    {4'd14,4'd9 } : begin ac_huff_code = 16'b1111_1111_1111_0011; ac_huff_count = 5'd16; end
    {4'd14,4'd10} : begin ac_huff_code = 16'b1111_1111_1111_0100; ac_huff_count = 5'd16; end
    ////////
    //{4'd15,4'd0 } : begin ac_huff_code = 16'b1111_1111_0010_0000; ac_huff_count = 5'd11; end
    {4'd15,4'd1 } : begin ac_huff_code = 16'b1111_1111_1111_0101; ac_huff_count = 5'd16; end
    {4'd15,4'd2 } : begin ac_huff_code = 16'b1111_1111_1111_0110; ac_huff_count = 5'd16; end
    {4'd15,4'd3 } : begin ac_huff_code = 16'b1111_1111_1111_0111; ac_huff_count = 5'd16; end
    {4'd15,4'd4 } : begin ac_huff_code = 16'b1111_1111_1111_1000; ac_huff_count = 5'd16; end
    {4'd15,4'd5 } : begin ac_huff_code = 16'b1111_1111_1111_1001; ac_huff_count = 5'd16; end
    {4'd15,4'd6 } : begin ac_huff_code = 16'b1111_1111_1111_1010; ac_huff_count = 5'd16; end
    {4'd15,4'd7 } : begin ac_huff_code = 16'b1111_1111_1111_1011; ac_huff_count = 5'd16; end
    {4'd15,4'd8 } : begin ac_huff_code = 16'b1111_1111_1111_1100; ac_huff_count = 5'd16; end
    {4'd15,4'd9 } : begin ac_huff_code = 16'b1111_1111_1111_1101; ac_huff_count = 5'd16; end
    {4'd15,4'd10} : begin ac_huff_code = 16'b1111_1111_1111_1110; ac_huff_count = 5'd16; end
    ////////
    default : begin ac_huff_code = 16'b0000_0000_0000_0000; ac_huff_count = 5'd0; end // 
  endcase
end

assign ac_vli_count = ac_size;


always_comb // AC VLI look up table
begin
  ac_vli_code = 10'd0;
  case (ac_vli_count)
    10 : ac_vli_code[9:0] = ac_vli_inp[9:0];     
    9 : ac_vli_code[8:0] = ac_vli_inp[8:0]; 
    8 : ac_vli_code[7:0] = ac_vli_inp[7:0]; 
    7 : ac_vli_code[6:0] = ac_vli_inp[6:0]; 
    6 : ac_vli_code[5:0] = ac_vli_inp[5:0]; 
    5 : ac_vli_code[4:0] = ac_vli_inp[4:0]; 
    4 : ac_vli_code[3:0] = ac_vli_inp[3:0]; 
    3 : ac_vli_code[2:0] = ac_vli_inp[2:0]; 
    2 : ac_vli_code[1:0] = ac_vli_inp[1:0]; 
    1 : ac_vli_code[0] = ac_vli_inp[0]; 
    default : ac_vli_code[0] = ac_vli_inp[0];
  endcase
end

assign ac_vli_code_shifted_int = ac_vli_code << (10-ac_vli_count);
assign ac_vli_code_shifted     = ac_vli_code_shifted_int << (16-ac_huff_count);
assign ac_total_count          = ac_vli_count + ac_huff_count; //total ac length in bitstream because of current ac code


assign ac_full_code[25] = (ac_huff_count>=1 ) ? ac_huff_code[15] : ac_vli_code_shifted[25];
assign ac_full_code[24] = (ac_huff_count>=2 ) ? ac_huff_code[14] : ac_vli_code_shifted[24];
assign ac_full_code[23] = (ac_huff_count>=3) ? ac_huff_code[13] : ac_vli_code_shifted[23];
assign ac_full_code[22] = (ac_huff_count>=4) ? ac_huff_code[12] : ac_vli_code_shifted[22];
assign ac_full_code[21] = (ac_huff_count>=5) ? ac_huff_code[11] : ac_vli_code_shifted[21];
assign ac_full_code[20] = (ac_huff_count>=6) ? ac_huff_code[10] : ac_vli_code_shifted[20];
assign ac_full_code[19] = (ac_huff_count>=7) ? ac_huff_code[9] : ac_vli_code_shifted[19];
assign ac_full_code[18] = (ac_huff_count>=8) ? ac_huff_code[8] : ac_vli_code_shifted[18];
assign ac_full_code[17] = (ac_huff_count>=9) ? ac_huff_code[7] : ac_vli_code_shifted[17];
assign ac_full_code[16] = (ac_huff_count>=10) ? ac_huff_code[6] : ac_vli_code_shifted[16];
assign ac_full_code[15] = (ac_huff_count>=11) ? ac_huff_code[5] : ac_vli_code_shifted[15];
assign ac_full_code[14] = (ac_huff_count>=12) ? ac_huff_code[4] : ac_vli_code_shifted[14];
assign ac_full_code[13] = (ac_huff_count>=13) ? ac_huff_code[3] : ac_vli_code_shifted[13];
assign ac_full_code[12] = (ac_huff_count>=14) ? ac_huff_code[2] : ac_vli_code_shifted[12];
assign ac_full_code[11] = (ac_huff_count>=15) ? ac_huff_code[1] : ac_vli_code_shifted[11];
assign ac_full_code[10] = (ac_huff_count==16) ? ac_huff_code[0] : ac_vli_code_shifted[10];
assign ac_full_code[9:0] = ac_vli_code_shifted[9:0];


  

//////////////////////////////////////////////////////////////////
assign dc_vli_code_shifted_int = dc_vli_code << (11-dc_vli_count);
assign dc_vli_code_shifted     = dc_vli_code_shifted_int << (9-dc_huff_count);
assign dc_total_count          = dc_vli_count + dc_huff_count; //total dc length in bitstream


always_ff @(posedge clk)
begin
  if (img_rst) 
    enable_module <= 0;
  else if (enable)
    enable_module <= 1;
end

always_ff @(posedge clk)
begin
  if (img_rst) 
    enable_1 <= 0;
  else
    enable_1 <= enable;
end
   
assign dc_full_code[19] = (dc_huff_count>=1 ) ? dc_huff_code[8] : dc_vli_code_shifted[19];
assign dc_full_code[18] = (dc_huff_count>=2 ) ? dc_huff_code[7] : dc_vli_code_shifted[18];
assign dc_full_code[17] = (dc_huff_count>=3 ) ? dc_huff_code[6] : dc_vli_code_shifted[17];
assign dc_full_code[16] = (dc_huff_count>=4 ) ? dc_huff_code[5] : dc_vli_code_shifted[16];
assign dc_full_code[15] = (dc_huff_count>=5 ) ? dc_huff_code[4] : dc_vli_code_shifted[15];
assign dc_full_code[14] = (dc_huff_count>=6 ) ? dc_huff_code[3] : dc_vli_code_shifted[14];
assign dc_full_code[13] = (dc_huff_count>=7 ) ? dc_huff_code[2] : dc_vli_code_shifted[13];
assign dc_full_code[12] = (dc_huff_count>=8 ) ? dc_huff_code[1] : dc_vli_code_shifted[12];
assign dc_full_code[11] = (dc_huff_count==9  ) ? dc_huff_code[0] : dc_vli_code_shifted[11];
assign dc_full_code[10:0] = dc_vli_code_shifted[10:0];


assign zero_check = ~(|ac_input); //all bits zero => zero detected

always_ff @(posedge clk)
begin
  if (img_rst) 
    zrl_long <= 0;
  else if (enable)
    zrl_long <= 0;
  else if ((enable_module) & (block_counter<8'd63))  begin
    if (zero_check==1'b1)
      zrl_long <= zrl_long+1;
    else 
      zrl_long <= 0;
  end
end
                            //purpose of zrl_long is to count the
                            //total number of continuous zeros (even after
                            //they exceed 16)
assign zrl = zrl_long[3:0]; //purpose of zrl is only for finding the {zrl,ac_size} huffman code
assign zrl_long_msb = zrl_long[5:4]; //represents number of 16 continuous zeros

always_ff @(posedge clk)
begin
  if (img_rst) 
    zrl_long_msb_1 <= 0;
  else if (enable)
    zrl_long_msb_1 <= 0;
  else if (enable_module)
      zrl_long_msb_1 <= zrl_long_msb;
end

assign incr_count_sixteen_zeros = (zrl_long_msb > zrl_long_msb_1)? 1 : 0;
assign shift_mux_sel = (zrl_long_msb < zrl_long_msb_1)? 1 : 0;


always_ff @(posedge clk)
begin
  if (img_rst) 
    count_sixteen_zeros <= 0; //represents total number of 16 continuous zeros in a block
  else if (enable)
    count_sixteen_zeros <= 0;
  else if (enable_module)
        if (incr_count_sixteen_zeros)
          count_sixteen_zeros <= count_sixteen_zeros + 1;
end

always_ff @(posedge clk)
begin
  if (img_rst) begin
    stream_sel <= 0;
    shift_en1 <= 0; 
    shift_en2 <= 0; 
    shift_en3 <= 0;
  end else if (enable) begin
    stream_sel <= 0;
    shift_en1 <= 0; 
    shift_en2 <= 0; 
    shift_en3 <= 0;
  end else if (enable_module) begin
      if (shift_mux_sel) begin
        stream_sel <= count_sixteen_zeros;
        case(count_sixteen_zeros)
          1 : shift_en1 <= 1;
          2 : begin shift_en1 <= 1; shift_en2 <= 1; end
          3 : begin shift_en1 <= 1; shift_en2 <= 1; shift_en3 <= 1; end
          default : begin shift_en1 <= 0; shift_en2 <= 0; shift_en3 <= 0; end
        endcase
      end
  end      
end

always_ff @(posedge clk)
begin
  if (img_rst) begin
    ac_code_buf1 <= 26'h3FC8000;  ac_total_count_buf1 <= 5'd11; eob_buf1 <= 1'b0; //we are loading the 15,0 ac huffman code and count here
    ac_code_buf2 <= 26'h3FC8000;  ac_total_count_buf2 <= 5'd11; eob_buf2 <= 1'b0; 
    ac_code_buf3 <= 26'h3FC8000;  ac_total_count_buf3 <= 5'd11; eob_buf3 <= 1'b0; 
  end else if (enable) begin
    ac_code_buf1 <= 26'h3FC8000;  ac_total_count_buf1 <= 5'd11;  eob_buf1 <= 1'b0; 
    ac_code_buf2 <= 26'h3FC8000;  ac_total_count_buf2 <= 5'd11;  eob_buf2 <= 1'b0; 
    ac_code_buf3 <= 26'h3FC8000;  ac_total_count_buf3 <= 5'd11;  eob_buf3 <= 1'b0; 
  end else if (enable_module) begin
    if (shift_en1==1) begin
      ac_code_buf1        <= ac_full_code_2;
      ac_total_count_buf1 <= ac_total_count_2;
      eob_buf1            <= eob;
    end if (shift_en2==1) begin
      ac_code_buf2        <= ac_code_buf1;
      ac_total_count_buf2 <= ac_total_count_buf1;
      eob_buf2            <= eob_buf1;
    end if (shift_en3==1) begin
      ac_code_buf3        <= ac_code_buf2;
      ac_total_count_buf3 <= ac_total_count_buf2;
      eob_buf3            <= eob_buf2;
    end
  end
end
    


always_ff @(posedge clk)
begin
  if (img_rst) begin
    eob <= 1'b0;
    ac_full_code_1 <= 0; 
    ac_full_code_2 <= 0;    
 end else if (enable) begin
    eob <= 1'b0;
    ac_full_code_1 <= 0;
    ac_full_code_2 <= 0; 
 end else if (enable_module) begin
    if (block_counter[6]==1'b1)  begin //if block counter >= 64
      eob <= 1'b1;
      ac_full_code_1 <= 26'd0;
      ac_full_code_2 <= 26'h2800000; //EOB
    end else begin
      ac_full_code_1 <= ac_full_code;
      ac_full_code_2 <= ac_full_code_1;
    end
 end
end

always_ff @(posedge clk)
begin
  if (img_rst) begin
    ac_total_count_1 <= 0;
    ac_total_count_2 <= 0;
  end else if (enable) begin
    ac_total_count_1 <= 0;
    ac_total_count_2 <= 0;
  end else if (enable_module) begin
    if (~eob) begin
      if (block_counter[6]==1'b1) begin
        ac_total_count_1 <= 0;
        ac_total_count_2 <= 5'd4; //EOB
      end else begin
        ac_total_count_1 <= ac_total_count;
        ac_total_count_2 <= ac_total_count_1;
      end
    end else
      ac_total_count_2 <= 0;
  end
end


always_comb
begin
  case (stream_sel)
    0 : begin ac_strmout_full_code =  ac_full_code_2; ac_strmout_total_count = ac_total_count_2;        eob_strmout = eob;      end
    1 : begin ac_strmout_full_code =  ac_code_buf1;   ac_strmout_total_count = ac_total_count_buf1;     eob_strmout = eob_buf1; end
    2 : begin ac_strmout_full_code =  ac_code_buf2;   ac_strmout_total_count = ac_total_count_buf2;     eob_strmout = eob_buf2; end
    3 : begin ac_strmout_full_code =  ac_code_buf3;   ac_strmout_total_count = ac_total_count_buf3;     eob_strmout = eob_buf3; end
    default : begin ac_strmout_full_code =  ac_full_code_2; ac_strmout_total_count = ac_total_count_2;  eob_strmout = eob;      end
  endcase
end

           
always_ff @(posedge clk)
begin
  if (img_rst) begin
    jpeg_bits   <= 0;
    jpeg_bits_1 <= 0;
  end else if (enable) begin
    jpeg_bits <= {dc_full_code,6'd0};
    jpeg_bits_1 <= 0;   
  end else if (enable_module) begin
    jpeg_bits   <= ac_strmout_full_code;
    jpeg_bits_1 <= jpeg_bits;    
  end
end

always_ff @(posedge clk)
begin
  if (img_rst) begin
    orc   <= 0;
    orc_1 <= 0;
    orc_2 <= 0;
    eob_final   <= 0;
    eob_final_1 <= 0;
    eob_final_2 <= 0;
  end else if (enable) begin
    orc <= dc_total_count;
    orc_1 <= 0;
    orc_2 <= 0;
    eob_final   <= 0;
    eob_final_1 <= 0;
    eob_final_2 <= 0;
  end else if (enable_module) begin
    orc <= orc+ac_strmout_total_count;
    orc_1 <= orc;
    orc_2 <= orc_1;

    eob_final   <= eob_strmout;
    eob_final_1 <= eob_final;
    eob_final_2 <= eob_final_1;
  end
end


assign jpeg_bits_tmp = {jpeg_bits,6'd0};
assign jpeg_bits_shifted = jpeg_bits_tmp >> orc_1;
assign jpeg_ro_bits = {jpeg_bits_1,6'd0} << (32-orc_2);

assign rollover = (eob_final_1 & ~eob_final_2) ? 1'b1 : (orc_2>orc_1);

always_ff @(posedge clk) //to handle a corner case of eob and roll over happening that is out of 1010 , 101 is in 1 32bit bus whereas the last 0 goes to next 32 bit bus => we need to generate data_ready in next cycle too 
begin
  if (img_rst)
    data_ready_special <= 0;
  else if (enable)
    data_ready_special <= 0;
  else
    data_ready_special <= (eob_final_1 & ~eob_final_2) & ((orc_2>orc_1) & (~(orc_1==0))) ; //orc_1==0 => it perfectly ends at 32 bits => we don't need to stretch the data ready for one more cycle
end 

always_ff @(posedge clk)
begin
  if (img_rst) begin
    jpeg_bitstream   <= 0;
  end else if (enable_1) begin
    jpeg_bitstream    <= jpeg_bits_shifted;
  end else begin
    if (rollover) begin
      jpeg_bitstream[31] <= (orc_1>=1) ? jpeg_ro_bits[31] : jpeg_bits_shifted[31];  
      jpeg_bitstream[30] <= (orc_1>=2) ? jpeg_ro_bits[30] : jpeg_bits_shifted[30]; 
      jpeg_bitstream[29] <= (orc_1>=3) ? jpeg_ro_bits[29] : jpeg_bits_shifted[29]; 
      jpeg_bitstream[28] <= (orc_1>=4) ? jpeg_ro_bits[28] : jpeg_bits_shifted[28]; 
      jpeg_bitstream[27] <= (orc_1>=5) ? jpeg_ro_bits[27] : jpeg_bits_shifted[27]; 
      jpeg_bitstream[26] <= (orc_1>=6) ? jpeg_ro_bits[26] : jpeg_bits_shifted[26]; 
      jpeg_bitstream[25] <= (orc_1>=7) ? jpeg_ro_bits[25] : jpeg_bits_shifted[25]; 
      jpeg_bitstream[24] <= (orc_1>=8) ? jpeg_ro_bits[24] : jpeg_bits_shifted[24]; 
      jpeg_bitstream[23] <= (orc_1>=9) ? jpeg_ro_bits[23] : jpeg_bits_shifted[23]; 
      jpeg_bitstream[22] <= (orc_1>=10) ? jpeg_ro_bits[22] : jpeg_bits_shifted[22]; 
      jpeg_bitstream[21] <= (orc_1>=11) ? jpeg_ro_bits[21] : jpeg_bits_shifted[21]; 
      jpeg_bitstream[20] <= (orc_1>=12) ? jpeg_ro_bits[20] : jpeg_bits_shifted[20]; 
      jpeg_bitstream[19] <= (orc_1>=13) ? jpeg_ro_bits[19] : jpeg_bits_shifted[19]; 
      jpeg_bitstream[18] <= (orc_1>=14) ? jpeg_ro_bits[18] : jpeg_bits_shifted[18]; 
      jpeg_bitstream[17] <= (orc_1>=15) ? jpeg_ro_bits[17] : jpeg_bits_shifted[17]; 
      jpeg_bitstream[16] <= (orc_1>=16) ? jpeg_ro_bits[16] : jpeg_bits_shifted[16]; 
      jpeg_bitstream[15] <= (orc_1>=17) ? jpeg_ro_bits[15] : jpeg_bits_shifted[15]; 
      jpeg_bitstream[14] <= (orc_1>=18) ? jpeg_ro_bits[14] : jpeg_bits_shifted[14]; 
      jpeg_bitstream[13] <= (orc_1>=19) ? jpeg_ro_bits[13] : jpeg_bits_shifted[13]; 
      jpeg_bitstream[12] <= (orc_1>=20) ? jpeg_ro_bits[12] : jpeg_bits_shifted[12]; 
      jpeg_bitstream[11] <= (orc_1>=21) ? jpeg_ro_bits[11] : jpeg_bits_shifted[11]; 
      jpeg_bitstream[10] <= (orc_1>=22) ? jpeg_ro_bits[10] : jpeg_bits_shifted[10]; 
      jpeg_bitstream[9] <= (orc_1>=23) ? jpeg_ro_bits[9] : jpeg_bits_shifted[9]; 
      jpeg_bitstream[8] <= (orc_1>=24) ? jpeg_ro_bits[8] : jpeg_bits_shifted[8];
      jpeg_bitstream[7:0] <= jpeg_bits_shifted[7:0];
    end else begin
      jpeg_bitstream[31] <= (orc_1>=1) ? jpeg_bitstream[31] : jpeg_bits_shifted[31];  
      jpeg_bitstream[30] <= (orc_1>=2) ? jpeg_bitstream[30] : jpeg_bits_shifted[30]; 
      jpeg_bitstream[29] <= (orc_1>=3) ? jpeg_bitstream[29] : jpeg_bits_shifted[29]; 
      jpeg_bitstream[28] <= (orc_1>=4) ? jpeg_bitstream[28] : jpeg_bits_shifted[28]; 
      jpeg_bitstream[27] <= (orc_1>=5) ? jpeg_bitstream[27] : jpeg_bits_shifted[27]; 
      jpeg_bitstream[26] <= (orc_1>=6) ? jpeg_bitstream[26] : jpeg_bits_shifted[26]; 
      jpeg_bitstream[25] <= (orc_1>=7) ? jpeg_bitstream[25] : jpeg_bits_shifted[25]; 
      jpeg_bitstream[24] <= (orc_1>=8) ? jpeg_bitstream[24] : jpeg_bits_shifted[24]; 
      jpeg_bitstream[23] <= (orc_1>=9) ? jpeg_bitstream[23] : jpeg_bits_shifted[23]; 
      jpeg_bitstream[22] <= (orc_1>=10) ? jpeg_bitstream[22] : jpeg_bits_shifted[22]; 
      jpeg_bitstream[21] <= (orc_1>=11) ? jpeg_bitstream[21] : jpeg_bits_shifted[21]; 
      jpeg_bitstream[20] <= (orc_1>=12) ? jpeg_bitstream[20] : jpeg_bits_shifted[20]; 
      jpeg_bitstream[19] <= (orc_1>=13) ? jpeg_bitstream[19] : jpeg_bits_shifted[19]; 
      jpeg_bitstream[18] <= (orc_1>=14) ? jpeg_bitstream[18] : jpeg_bits_shifted[18]; 
      jpeg_bitstream[17] <= (orc_1>=15) ? jpeg_bitstream[17] : jpeg_bits_shifted[17]; 
      jpeg_bitstream[16] <= (orc_1>=16) ? jpeg_bitstream[16] : jpeg_bits_shifted[16]; 
      jpeg_bitstream[15] <= (orc_1>=17) ? jpeg_bitstream[15] : jpeg_bits_shifted[15]; 
      jpeg_bitstream[14] <= (orc_1>=18) ? jpeg_bitstream[14] : jpeg_bits_shifted[14]; 
      jpeg_bitstream[13] <= (orc_1>=19) ? jpeg_bitstream[13] : jpeg_bits_shifted[13]; 
      jpeg_bitstream[12] <= (orc_1>=20) ? jpeg_bitstream[12] : jpeg_bits_shifted[12]; 
      jpeg_bitstream[11] <= (orc_1>=21) ? jpeg_bitstream[11] : jpeg_bits_shifted[11]; 
      jpeg_bitstream[10] <= (orc_1>=22) ? jpeg_bitstream[10] : jpeg_bits_shifted[10]; 
      jpeg_bitstream[9] <= (orc_1>=23) ? jpeg_bitstream[9] : jpeg_bits_shifted[9]; 
      jpeg_bitstream[8] <= (orc_1>=24) ? jpeg_bitstream[8] : jpeg_bits_shifted[8];
      jpeg_bitstream[7] <= (orc_1>=25) ? jpeg_bitstream[7] : jpeg_bits_shifted[7];
      jpeg_bitstream[6] <= (orc_1>=26) ? jpeg_bitstream[6] : jpeg_bits_shifted[6];
      jpeg_bitstream[5] <= (orc_1>=27) ? jpeg_bitstream[5] : jpeg_bits_shifted[5];
      jpeg_bitstream[4] <= (orc_1>=28) ? jpeg_bitstream[4] : jpeg_bits_shifted[4];
      jpeg_bitstream[3] <= (orc_1>=29) ? jpeg_bitstream[3] : jpeg_bits_shifted[3];
      jpeg_bitstream[2] <= (orc_1>=30) ? jpeg_bitstream[2] : jpeg_bits_shifted[2];
      jpeg_bitstream[1] <= (orc_1==31) ? jpeg_bitstream[1] : jpeg_bits_shifted[1];
      jpeg_bitstream[0] <= jpeg_bits_shifted[0];
    end  
  end
end

always_ff @(posedge clk)
begin
  if (img_rst) 
    block_counter <= 0;
  else if (enable)
    block_counter <= 0;
  else if (enable_module) begin
    if (~block_counter[6])      //dont increment after reaching 64
    block_counter <= block_counter+1;
  end
end




assign dataready = (rollover|data_ready_special); //todo                 


endmodule

