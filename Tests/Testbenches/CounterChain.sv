`include "Tech/osu035/osu035_stdcells.v"
`include "Netlists/RTL/Counter.v.netlist.v.chained.v"

module Testbench;

    reg clk, rst, shift, sin;
    wire sout;
    wire[7:0] out;

    Counter uut(clk, rst, out, shift, sin, sout, rst, clk, 1'b0, 1'b0);

    always #1 clk = !clk;

    // Try to serialize then read "100010101010010101"
    wire[0:15] serializable = 16'b1100101010010101;
    reg[0:15] serial = 16'b0;
    integer i;

    initial begin
        $dumpvars(0, Testbench);
        clk = 0;
        rst = 0;
        shift = 0;
        sin = 0;
        #10;
        rst = 1;
        shift = 1;
        for (i = 0; i < 16; i = i + 1) begin
            sin = serializable[i];
            #2;
        end
        for (i = 0; i < 16; i = i + 1) begin
            serial[i] = sout;
            #2;
        end
        if (serial == serializable)
            $display("Serialization successful.");
        else
            $display("Serialization failed.");
        #16;

        $finish;
    end

endmodule