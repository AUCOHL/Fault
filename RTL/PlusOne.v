module PlusOne(
    input[7:0] a,
    input nowidth,
    output[7:0] b
);
    assign b = a + 1;
endmodule