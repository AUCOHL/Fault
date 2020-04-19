//# 4 inputs
//# 1 outputs
//# 3 D-type flipflops
//# 2 inverters
//# 8 gates (1 ANDs + 1 NANDs + 2 ORs + 4 NORs)

module dff (CK, reset, Q,D);

input D; // Data input 
input CK; // clock input 
output reg Q; // output Q 
input reset;
always @(posedge CK or posedge reset) begin 
  if(reset == 1) begin
    Q <= 1'b0;
  end
  else begin
   Q <= D;  
  end
end

endmodule

module s27(GND,VDD,CK, reset, G0,G1,G17,G2,G3);
input GND,VDD,CK,G0,G1,G2,G3;
input reset;
output G17;

  wire G5,G10,G6,G11,G7,G13,G14,G8,G15,G12,G16,G9;

  dff DFF_0(CK, reset, G5,G10);
  dff DFF_1(CK, reset, G6,G11);
  dff DFF_2(CK, reset, G7,G13);
  not NOT_0(G14,G0);
  not NOT_1(G17,G11);
  and AND2_0(G8,G14,G6);
  or OR2_0(G15,G12,G8);
  or OR2_1(G16,G3,G8);
  nand NAND2_0(G9,G16,G15);
  nor NOR2_0(G10,G14,G11);
  nor NOR2_1(G11,G5,G9);
  nor NOR2_2(G12,G1,G7);
  nor NOR2_3(G13,G2,G12);

endmodule
