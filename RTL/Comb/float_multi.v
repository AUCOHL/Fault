//float multi multiplies floating point numbers. Overflow flag is high in case of overflow
module float_multi(num1, num2, result, overflow);
  input [15:0] num1, num2;
  output [15:0] result;
  output overflow;
  wire sign1, sign2, signr; //hold signs
  wire [4:0] ex1, ex2; //hold exponents
  wire [9:0] fra1, fra2; //hold fractions
  wire [10:0] float1; // true value of fra1 i.e. 1.ffffffffff
  wire [5:0] exSum; //exponent sum
  wire [10:0] float_res; //fraction result
  reg [10:0] mid[9:0], mid2[1:0];

  assign overflow = exSum[5]; //extra digit of final sum exist at overflow
  //decode numbers
  assign {sign1, ex1, fra1} = num1;
  assign {sign2, ex2, fra2} = num2;
  //Same signs give 0 (positive), different signs give 1 (negative)
  assign signr = (sign1 ^ sign2);
  assign exSum = (ex1 + ex2); //exponentials are added
  assign float1 = {1'b1, fra1};
  assign float_res = float1 + mid2[1] + mid2[0]; //add mid2 terms and integer  of num2
  assign result = {signr, exSum[4:0], float_res[9:0]};

  always@* //create mids from fractions
    begin
      mid[0] = (float1 >> 10) & {16{fra2[0]}};
      mid[1] = (float1 >> 9) & {16{fra2[1]}};
      mid[2] = (float1 >> 8) & {16{fra2[2]}};
      mid[3] = (float1 >> 7) & {16{fra2[3]}};
      mid[4] = (float1 >> 6) & {16{fra2[4]}};
      mid[5] = (float1 >> 5) & {16{fra2[5]}};
      mid[6] = (float1 >> 4) & {16{fra2[6]}};
      mid[7] = (float1 >> 3) & {16{fra2[7]}};
      mid[8] = (float1 >> 2) & {16{fra2[8]}};
      mid[9] = (float1 >> 1) & {16{fra2[9]}};
    end

  always@* //create mid2s from mids
    begin
      mid2[1] = mid[0] + mid[1] + mid[2] + mid[3] + mid[4];
      mid2[0] = mid[5] + mid[6] + mid[7] + mid[8] + mid[9];
    end

endmodule