module CLA32(CarryIn, a, b, result, CarryOut);
   input  a, b;
   input CarryIn;
   output CarryOut;
   output  result;
   parameter delay = 50;

   wire  p, g;
   wire  c;

   buf# (delay) buf0(c, CarryIn);

   genvar i;
   generate
   for(i=0; i<32; i++)
       begin: CalculatePandG
           and# (delay) myAnd(g, a, b);
           or # (delay) myOr(p, a, b);
       end
   endgenerate

   carry_lookahead myCarryLookAhead(p, g, CarryIn, c, CarryOut);

   genvar j;
   generate
   for(j=0; j<32; j++)
       begin: JoinedAdder
           xor# (delay) Adderj(result, c, a, b);
       end
   endgenerate
endmodule
//CARRY-LOOKAHEAD
module carry_lookahead(p, g, CarryIn, c, CarryOut);
   input  p, g;
   input CarryIn;
   output  c;
   output CarryOut;

   buf# 50 buf0(c, CarryIn);

   genvar i;
   generate
   for(i=0; i<31; i++)
       begin: CarryLookAhead
           cal_carry myCarry(p, g, c, c);
       end
   endgenerate
   cal_carry myCarry31(p, g, c, CarryOut);
endmodule
module cal_carry(p, g, cin, cout);
   input p, g, cin;
   output cout;
   parameter delay = 50;

   wire temp;

   and# (delay) and0(temp, p, c);
   or # (delay) or0(cout, temp, g);
endmodule