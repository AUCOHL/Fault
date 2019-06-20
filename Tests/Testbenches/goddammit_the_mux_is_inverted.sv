`include "Tech/osu035/osu035_stdcells.v"

module mux_tb;

  reg A, B, S;
  wire y;

  MUX2X1 uut(
    .A(A),
    .B(B),
    .S(S),
    .Y(Y)
  );

  wire uninverted_mux = S ? A: B;

  integer ai;

  initial begin
    $dumpvars(1, mux_tb);
    for (ai = 0; ai < 10; ai += 1) begin
      A = $random;
      B = $random;
      S = $random;
      #5;
    end    
  end

endmodule