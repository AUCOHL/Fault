module BufferedInverter(
    input clk,
    input rstn,
    input in,
    output out
);
    reg store;
    always @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            store <= 1'b0;
        end else begin
            store <= ~in;
        end
    end
endmodule
