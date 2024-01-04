module TripleDelay(
    input clk,
    input rst,
    input in,
    output out
);
    reg store;
    wire store_next;
    
    BufferedInverter ui1(
        .clk(clk),
        .rstn(rst),
        .in(in),
        .out(store_next)
    );
    
    always @ (posedge clk or negedge rst) begin
        if (!rst) begin
            store <= 1'b0;
        end else begin
            store <= store_next;
        end
    end
    
    BufferedInverter ui2(
        .clk(clk),
        .rstn(rst),
        .in(store),
        .out(out)
    );

endmodule
