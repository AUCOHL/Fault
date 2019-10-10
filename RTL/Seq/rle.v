module rle (clk, rst, rd_req , recv_ready ,send_ready, in_data , out_data, end_of_stream ,wr_req);
input clk,rst; 				//Use global Clk and Reset
input recv_ready,send_ready;		//recv_ready indicates input side FIFO is not empty. send_ready indicates output side FIFO is not full
input [7:0] in_data;			//input data comes from input side FIFO
input end_of_stream ;			//Indicate the end of bit stream. Flush out the last segment to FIFO.
output [23:0] out_data;			//Output data to output side FIFO. [23] has bit ID, [22:0] has bit counting value
output rd_req,wr_req;			//Read request for input side FIFO

reg rd_reg,wr_reg;			//Write request for output side FIFO
reg [22:0] bit_count;			//Store number of consecutive bits in bit stream
reg [3:0] shift_count;			//Current shift amount of shift_buf
reg value_type;				//Bit ID
reg [7:0] shift_buf;			//Store 8 bit segment of bit stream comes from input side FIFO
					//Will be shifted out to calculate number of bits
reg [3:0] state;
reg [3:0] next_state;

reg new_bitstream; 			//Indicate new consecutive bit is starting. Current encoded data segment is passed to output side FIFO

//Reference the state machine for Lab slide.
parameter INIT  = 4'b0000,REQUEST_INPUT = 4'b0001,WAIT_INPUT = 4'b0010,COUNT_BITS = 4'b0011,
SHIFT_BITS = 4'b0100,COUNT_DONE = 4'b0101,WAIT_OUTPUT = 4'b0110, RESET_COUNT = 4'b0111, READ_INPUT  = 4'b1000;

always @(state or recv_ready or send_ready or end_of_stream or bit_count or new_bitstream or shift_count) begin //combinational logic
	case(state)
		INIT: begin
			next_state = REQUEST_INPUT;
		end
		REQUEST_INPUT: begin
			if(recv_ready) next_state = WAIT_INPUT;
			else if(end_of_stream  && bit_count) next_state = COUNT_DONE;
			else next_state = REQUEST_INPUT;
		end
		WAIT_INPUT: next_state = READ_INPUT ;
		READ_INPUT : next_state = COUNT_BITS;
		COUNT_BITS: next_state = SHIFT_BITS;
		SHIFT_BITS:
		begin
			if(new_bitstream) next_state = COUNT_DONE;
			else begin
				if(shift_count == 7) next_state = REQUEST_INPUT;
				else next_state = COUNT_BITS;
			end
		end
		COUNT_DONE:
		begin
			if(send_ready) next_state = WAIT_OUTPUT ;
			else next_state = COUNT_DONE;
		end
		WAIT_OUTPUT : next_state = RESET_COUNT ;
		RESET_COUNT : begin
			if(end_of_stream ) next_state = INIT;
			else next_state = COUNT_BITS;
		end
		default: next_state = INIT;
	endcase
end

always @(posedge clk) begin  //sequential logic
	if(rst) state <= INIT;
	else state <= next_state;

	case(state)
	INIT: begin
		//Initialize registers
		bit_count <= 0;
		//shift_count<=0;
		shift_buf <= 0;
		rd_reg <= 0;
		wr_reg <= 0;
		new_bitstream <= 1;
	end
	REQUEST_INPUT: begin
		//Assert rd_req signal to FIFO by setting rd_reg
		rd_reg<=1;
		shift_count<=0; //
		//FIFO takes rd_req signal at next clock
	end
	WAIT_INPUT: begin
		//De-assert rd_req by setting rd_reg
		rd_reg<=0;
	end
	READ_INPUT : begin
		//FIFO provides valid data after taking rd_req
		//shift_buf stores 8 bit input data
		shift_buf<=in_data;
	end
	COUNT_BITS: begin
		//Count number of consecutive bits in shift_buf
		//If new type of bit starts, store bit ID in value_type register
		//If current value_type and shift_buf[0] is not matched, notify current encoding is completed and new encoding will be started
		if(new_bitstream) begin
			value_type<=shift_buf[0];
			bit_count<=bit_count+1;
			new_bitstream<=0;
		end
		else begin
			if(shift_buf[0] == value_type) begin
				bit_count<=bit_count+1;
			end
			else begin
				//output bit id and counting
				new_bitstream<=1;
			end
		end
	end
	SHIFT_BITS: begin
		//Right shift the shift_buf
		//Increase shift_count
		if(!new_bitstream) begin
			shift_buf<=(shift_buf>>1);			
			shift_count<=shift_count+1;
		end
	end
	COUNT_DONE: begin
		//Assert wr_req by setting wr_reg
		//FIFO will take wr_req signal in next clock cycle
		wr_reg<=1;
	end
	WAIT_OUTPUT : begin //required to stall program for one cycle
		//De-assert wr_req by setting wr_reg
		wr_reg<=0;
	end
	RESET_COUNT : begin
		//Reset bit counting register after passing encoded data to output side FIFO
		bit_count<=0;
	end
	endcase
end

assign rd_req = rd_reg;
assign wr_req = wr_reg;
assign out_data[23] = value_type;
assign out_data[22:0] = bit_count[22:0];
endmodule
