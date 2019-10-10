


// A Verilog example taken from comp.lang.verilog



//-----------------------Cache Coherence Protocol-----------------------------

// This finite-state machine (Melay type) reads bus 

// per cycle and changes the state of each block in cache.



module cache_coherence ( 

	new_state, 

	Cache_Sector_Fill, 

	Invalidate,  

	AdrRetry,

	RMS, 

	RME, 

	WM, 

	WH,  

	SHR, 

	SHW, 

	state, 

	READ_DONE, 

	clk, 

	reset, 

	send_abort, 

	write_back_done,

	AllInvDone);



input RMS, RME, WM, WH, SHR, SHW, READ_DONE, clk, 

      reset, send_abort, write_back_done, AllInvDone;



input [2:0] state;



output [2:0] new_state;

output Cache_Sector_Fill, Invalidate, AdrRetry;



reg Cache_Sector_Fill, Invalidate, AdrRetry ;

reg [2:0] new_state; 



// The four possible states (symbolic names) for a sector 

// in the cache plus 2 mandatory states



parameter /*[2:0]*/ // synopsys enum state_info

	INVALID = 3'b000,

	SHARED_1 = 3'b001,

	EXCLUSIVE = 3'b010,

	MODIFIED = 3'b011,

	Cache_Fill = 3'b100,

	start_write_back = 3'b101,

	/* start_write_back = 5, */

	WaitUntilAllInv = 3'b110;



// Declare current_state and next_state variable.

reg [2:0] 	/* synopsys enum state_info */	present_state;

reg [2:0]	/* synopsys enum state_info */	next_state;

// synopsys state_vector present_state



/* Combinational */

always @(present_state or RMS or RME or WM or WH or SHW or READ_DONE 

         or SHR or write_back_done or AllInvDone or send_abort or state or reset) 

begin

	Cache_Sector_Fill = 0; 	// Default values

	Invalidate = 0; 

	AdrRetry = 0; 

	next_state = present_state; 

	if (reset) next_state = state; else 

	begin

	case(present_state) 	// synopsys full_case

		INVALID: 

			// ReadMiss (shared/exclusive), Write Miss

			if (RMS || RME || WM)  			 

			begin

				Cache_Sector_Fill = 1;

				next_state = Cache_Fill ;

			end

			else 

			begin 

				next_state = INVALID;

			end



		Cache_Fill:	

			/* During This State Cache is filled with the sector,

			   But if any other processor have that copy in modified 

			   state, it sends an abort signal. If no other cache has

			   that copy in modified state. Requesting processor waits

			   for the read from memory to be done.

			*/

			if (send_abort) 

			begin 

				next_state = INVALID;

			end

			else if (READ_DONE) 

			begin

				if (RMS) 

				begin

					next_state = SHARED_1;

				end

				else if (RME) 

				begin 

					next_state = EXCLUSIVE;	

				end

				else if (WM)

				begin

					Invalidate = 1;

					next_state = WaitUntilAllInv;

				end 

				else 

				begin 

					next_state = Cache_Fill ;

				end

			end	

			else 

			begin 

				next_state = Cache_Fill ;

			end

			

		SHARED_1:	  

			if (SHW) // Snoop Hit on a Write.

			begin 

				next_state = INVALID;		

			end

			else if (WH) // Write Hit				

			begin

				Invalidate = 1;

				next_state = WaitUntilAllInv;

			end 

			else 

			begin // Snoop Hit on a Read or Read Hit or any other

				next_state = SHARED_1; 		

			end



		WaitUntilAllInv:

			/* In this state Requesting Processor waits for the 

			   all other processor's to invalidate its cache copy.

			*/



			if (AllInvDone) 

			begin 

				next_state = MODIFIED;

			end

			else 

			begin 

				next_state = WaitUntilAllInv;

			end



		EXCLUSIVE: 

								

			if (SHR) // Snoop Hit on a Read:

			begin

				AdrRetry = 0;

				next_state = SHARED_1;  

			end 					

			else if (SHW) // Snoop Hit on a Write 

			begin

				next_state = INVALID;	

			end

			else if (WH) // Write Hit

			begin

				next_state = MODIFIED;	

			end

			else 

			begin // Read Hit 

				next_state = EXCLUSIVE;		

			end



		MODIFIED:  	

			if (SHW) // Snoop Hit on a Write 

			begin

				next_state = INVALID;		

			end

			else if (SHR) // Snoop Hit on a Read 			

			begin

				AdrRetry = 1;

				next_state = start_write_back;

			end

			else // Read Hit or Write Hit or anything else.

			begin

				next_state = MODIFIED; 		

			end



		start_write_back: 

			/* In this state, Processor waits until other processor 

			   has written back the modified copy.

			*/

			if (write_back_done) 

			begin

				next_state = SHARED_1; 

			end

			else

			begin 

				next_state = start_write_back;

			end

			

	endcase

	end

	

end



/* Sequential */

always @(posedge clk) 

begin

	present_state = next_state;

	new_state = next_state;

end


endmodule
