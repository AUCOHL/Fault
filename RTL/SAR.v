`timescale 1ns/1ns

module EdgeDetector(clk, reset, go, actuallyGo);

input clk, reset, go;
output actuallyGo;

reg status;

always @ (posedge clk or posedge reset) begin
    if (reset) begin
        status <= 1'b0;
    end
    else begin
        status <= go;
    end
end

assign actuallyGo = go & ~status;

endmodule

module SuccessiveApproximationControl(clk, reset, go, cmp, valid, result, value, sample);

input clk, go, cmp, reset;
output [15:0] value;
output [15:0] result;
output reg valid;
output reg sample;

wire actuallyGo;

reg [15: 0] successiveApproximationRegister;
reg [15: 0] position;
reg [7: 0] waiting;
reg running;

assign value = successiveApproximationRegister;
assign result = successiveApproximationRegister;

EdgeDetector goDetector(.clk(clk), .reset(reset), .go(go), .actuallyGo(actuallyGo));

always @ (posedge clk or posedge reset) begin
    if (reset) begin
        valid <= 1'b0;
        running <= 1'b0;
        sample <= 1'b0;
        waiting <= 8'b0;
        successiveApproximationRegister <= 16'h0;
    end
    else if (actuallyGo && !running) begin //Nothing is running
        running <= 1'b1;
        sample <= 1'b1;
        valid <= 1'b0;
        successiveApproximationRegister <= 16'h8000;
        waiting <= 8'd4;
        position <= 16'h8000;
    end
    else if (running && waiting) begin //Running, waiting
        waiting <= waiting - 1;
    end
    else if (running && position) begin 
        sample <= 0;
        // Intentionally blocking for the next set of lines
        if (cmp) begin
            successiveApproximationRegister = successiveApproximationRegister ^ position;
        end
        position = {1'b0, position[15:1]};
        successiveApproximationRegister = successiveApproximationRegister | position;
    end
    else if (running) begin
        valid <= 1'b1;
        running <= 1'b0;
    end
end

endmodule