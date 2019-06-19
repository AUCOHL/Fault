`include "Tech/osu035/osu035_stdcells.v"
`include "Netlists/RTL/Counter.v.netlist.v"

module Testbench;

    reg clk, rst, __testing__, __input__;
    wire __output__;
    wire[7:0] out;

    Counter uut(clk, rst, out, __testing__, __input__, __output__);

    always #1 clk = !clk;

    // Try to serialize then read "10010101"
    wire[0:7] serializable = 8'b10010101;
    reg[0:7] serial;
    integer i;

    initial begin
        $dumpvars(0, Testbench);
        clk = 0;
        rst = 0;
        __testing__ = 0;
        __input__ = 0;
        #10;
        rst = 1;
        __testing__ = 1;
        for (i = 0; i < 8; i = i + 1) begin
            __input__ = serializable[i];
            #2;
        end
        for (i = 0; i < 8; i = i + 1) begin
            serial[i] = __output__;
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