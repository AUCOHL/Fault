// file: SPM.v
// author: @donn

module CarrySaveAdder(x, y, s, clk, enable, resetn);

input clk, resetn, enable;
input x, y;

wire hsum1, car1, car2;

//Flipflop inputs
wire dIn0, dIn1;

//Flipflop outputs
reg sc;
output reg s; //Any warning on this line is an Icarus Verilog bug. Thanks, Steve. // https://github.com/steveicarus/iverilog/issues/93

//Bottom Half Adder
assign {car1, hsum1} = y + sc;

//FDHA
assign car2 = x & hsum1;

//Top Input
assign dIn0 = hsum1 ^ x;

//Right Input
assign dIn1 = car2 ^ car1;

always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        s <= 0;
        sc <= 0;
    end
    else if (enable) begin
        s <= dIn0;
        sc <= dIn1;
    end
end

endmodule

module EdgeDetector(clk, resetn, go, actuallyGo);

input clk, resetn, go;
output actuallyGo;

reg status;

always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        status <= 1'b0;
    end
    else begin
        status <= go;
    end
end

assign actuallyGo = go & ~status;

endmodule

module TwosComplement(a, clk, resetn, enable, s);

input a, clk, resetn, enable;

//Flipflop Inputs
wire dIn0, dIn1;

//Flipflop Outputs
reg z;
output reg s; //Any warning on this line is an Icarus Verilog bug. Thanks, Steve. // https://github.com/steveicarus/iverilog/issues/93


assign dIn0 = a ^ z;
assign dIn1 = a | z;

always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        s <= 0;
    end
    else begin
        s <= dIn0;
    end
end

always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        z <= 0;
    end
    else begin
        z <= dIn1;
    end
end


endmodule

module SerialParallelMultiplier(MP, MC, start, P, done, clk, resetn);
parameter N = 32;

input clk, resetn;
input [N - 1: 0] MP;
input [N - 1: 0] MC;
input start;

output done;

wire currentY =  extendedMC[0];

reg resetComponentsn;
reg practicallyDone;
reg trulyDone;
reg started;
reg [$clog2(N * 2): 0] counter;
reg [(N * 2) - 1: 0] extendedMC;
output reg [(N * 2) - 1:0] P;

wire [N - 1: 0] outputs;
wire startEdge;

EdgeDetector startDetector(.clk(clk), .resetn(resetn), .go(start), .actuallyGo(startEdge));

genvar i;
generate
    for (i = 0; i < N - 1; i = i + 1) begin : suffering
        CarrySaveAdder unit(.x(MP[i] & currentY), .y(outputs[i + 1]), .s(outputs[i]), .clk(clk), .resetn(resetn), .enable(~practicallyDone));
    end
endgenerate

TwosComplement finalunit(.a(MP[N - 1] & currentY), .s(outputs[N - 1]), .clk(clk), .resetn(resetn), .enable(~practicallyDone));

always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        practicallyDone <= 1'b0;
        trulyDone <= 1'b0;
        started <= 1'b0;
        P <= {(N * 2){1'b0}};
        counter <= {$clog2(N * 2){1'b0}};
    end
    else if (startEdge) begin
        P <= {2 * N{1'b0}};
        practicallyDone <= 1'b0;
        trulyDone <= 1'b0;
        started <= 1'b1;
        counter <= (N * 2);
        extendedMC <= {{32{MC[N-1]}}, MC};
    end
    else if (started && !practicallyDone) begin
        extendedMC = {extendedMC[0], extendedMC[(N * 2) - 1: 1]};
        P[(N * 2) - 1] = outputs[0];
        P = {1'b0, P[(N * 2) - 1: 1]};
        counter = counter - 1;
        if (counter == {$clog2(N * 2) + 1{1'b0}}) begin
            practicallyDone <= 1'b1;
        end
    end
    else if (started && practicallyDone && !trulyDone) begin
        P[(N * 2) - 1] = outputs[0];
        trulyDone = 1'b1;
        started = 1'b0;
    end
end

assign done = trulyDone && !start;

endmodule