module Counter(input clk, input rst, output[7:0] out);

    reg[7:0] counter;
    
    always @ (posedge clk or negedge rst) begin
        if (!rst)
            counter <= 0;
        else
            counter <= counter + 1;
    end

    assign out = counter;

endmodule