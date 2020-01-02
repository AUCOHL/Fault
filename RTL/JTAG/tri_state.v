module Tristate (in, oe, out);

    input   in, oe;
    output  out;
    wire     out;

    bufif1  b1(out, in, oe);

endmodule