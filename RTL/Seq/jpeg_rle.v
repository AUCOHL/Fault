/////////////////////////////////////////////////////////////////////
////                                                             ////
////  JPEG Run-Length encoder                                    ////
////                                                             ////
////  1) Retreive zig-zag-ed samples (starting with DC coeff.)   ////
////  2) Translate DC-coeff. into 11bit-size and amplitude       ////
////  3) Translate AC-coeff. into zero-runs, size and amplitude  ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////


module jpeg_rle(clk, rst, ena, dstrb, din, size, rlen, amp, douten, bstart);

	//
	// parameters
	//

	//
	// inputs & outputs
	//
	input         clk;     // system clock
	input         rst;     // asynchronous reset
	input         ena;     // clock enable
	input         dstrb;
	input  [11:0] din;     // data input

	output [ 3:0] size;    // size
	output [ 3:0] rlen;    // run-length
	output [11:0] amp;     // amplitude
	output        douten;  // data output enable
	output        bstart;  // block start

	//
	// variables
	//

	wire [ 3:0] rle_rlen, rz1_rlen, rz2_rlen, rz3_rlen, rz4_rlen;
	wire [ 3:0] rle_size, rz1_size, rz2_size, rz3_size, rz4_size;
	wire [11:0] rle_amp,  rz1_amp,  rz2_amp,  rz3_amp,  rz4_amp;
	wire        rle_den,  rz1_den,  rz2_den,  rz3_den,  rz4_den;
	wire        rle_dc,   rz1_dc,   rz2_dc,   rz3_dc,   rz4_dc;

	//
	// module body
	//

	reg ddstrb;
	always @(posedge clk)
	  ddstrb <= #1 dstrb;

	// generate run-length encoded signals
	jpeg_rle1 rle(
		.clk(clk),
		.rst(rst),
		.ena(ena),
		.go(ddstrb),
		.din(din),
		.rlen(rle_rlen),
		.size(rle_size),
		.amp(rle_amp),
		.den(rle_den),
		.dcterm(rle_dc)
	);

	// Find (15,0) (0,0) sequences and replace by (0,0)
	// There can be max. 4 (15,0) sequences in a row

	// step1
	jpeg_rzs rz1(
		.clk(clk),
		.rst(rst),
		.ena(ena),
		.rleni(rle_rlen),
		.sizei(rle_size),
		.ampi(rle_amp),
		.deni(rle_den),
		.dci(rle_dc),
		.rleno(rz1_rlen),
		.sizeo(rz1_size),
		.ampo(rz1_amp),
		.deno(rz1_den),
		.dco(rz1_dc)
	);

	// step2
	jpeg_rzs rz2(
		.clk(clk),
		.rst(rst),
		.ena(ena),
		.rleni(rz1_rlen),
		.sizei(rz1_size),
		.ampi(rz1_amp),
		.deni(rz1_den),
		.dci(rz1_dc),
		.rleno(rz2_rlen),
		.sizeo(rz2_size),
		.ampo(rz2_amp),
		.deno(rz2_den),
		.dco(rz2_dc)
	);

	// step3
	jpeg_rzs rz3(
		.clk(clk),
		.rst(rst),
		.ena(ena),
		.rleni(rz2_rlen),
		.sizei(rz2_size),
		.ampi(rz2_amp),
		.deni(rz2_den),
		.dci(rz2_dc),
		.rleno(rz3_rlen),
		.sizeo(rz3_size),
		.ampo(rz3_amp),
		.deno(rz3_den),
		.dco(rz3_dc)
	);

	// step4
	jpeg_rzs rz4(
		.clk(clk),
		.rst(rst),
		.ena(ena),
		.rleni(rz3_rlen),
		.sizei(rz3_size),
		.ampi(rz3_amp),
		.deni(rz3_den),
		.dci(rz3_dc),
		.rleno(rz4_rlen),
		.sizeo(rz4_size),
		.ampo(rz4_amp),
		.deno(rz4_den),
		.dco(rz4_dc)
	);


	// assign outputs
	assign rlen   = rz4_rlen;
	assign size   = rz4_size;
	assign amp    = rz4_amp;
	assign douten = rz4_den;
	assign bstart = rz4_dc;
endmodule


module jpeg_rzs(clk, ena, rst, deni, dci, rleni, sizei, ampi, deno, dco, rleno, sizeo, ampo);

	//
	// inputs & outputs
	//
	input        clk;
	input        ena;
	input        rst;
	input        deni;
	input        dci;
	input [ 3:0] sizei;
	input [ 3:0] rleni;
	input [11:0] ampi;

	output        deno;
	output        dco;
	output [ 3:0] sizeo;
	output [ 3:0] rleno;
	output [11:0] ampo;

	reg        deno, dco;
	reg [ 3:0] sizeo, rleno;
	reg [11:0] ampo;

	//
	// variables
	//

	reg [ 3:0] size;
	reg [ 3:0] rlen;
	reg [11:0] amp;
	reg        den;
	reg        dc;

	wire eob;
	wire zerobl;
	reg  state;

	//
	// module body
	//

	always @(posedge clk)
	  if(ena & deni)
	    begin
	        size <= #1 sizei;
	        rlen <= #1 rleni;
	        amp  <= #1 ampi;
	    end

	always @(posedge clk)
	  if(ena)
	    begin
	        sizeo <= #1 size;
	        rleno <= #1 rlen;
	        ampo  <= #1 amp;

	        dc    <= #1 dci;
	        dco   <= #1 dc;
	    end

	assign zerobl = &rleni &  ~|sizei & deni;
	assign eob    = ~|{rleni, sizei} & deni & ~dci;

	always @(posedge clk or negedge rst)
	  if (!rst)
	     begin
	         state <= #1 1'b0;
	         den   <= #1 1'b0;
	         deno  <= #1 1'b0;
	     end
	  else
	    if(ena)
	      case (state) // synopsys full_case parallel_case
	         1'b0:
	             begin
	                 if (zerobl)
	                    begin
	                        state <= #1 1'b1; // go to zero-detection state
	                        den   <= #1 1'b0; // do not yet set data output enable
	                        deno  <= #1 den;  // output previous data
	                    end
	                 else
	                    begin
	                        state <= #1 1'b0; // stay in 'normal' state
	                        den   <= #1 deni; // set data output enable
	                        deno  <= #1 den;  // output previous data
	                    end
	             end

	         1'b1:
	             begin
	                 deno <= #1 1'b0;

	                 if (deni)
	                    if (zerobl)
	                       begin
	                           state <= #1 1'b1; // stay in zero-detection state
	                           den   <= #1 1'b0; // hold current zer-block
	                           deno  <= #1 1'b1; // output previous zero-block
	                       end
	                    else if (eob)
	                       begin
	                           state <= #1 1'b0; // go to 'normal' state
	                           den   <= #1 1'b1; // set output enable for EOB
	                           deno  <= #1 1'b0; // (was already zero), maybe optimize ??
	                       end
	                    else
	                       begin
	                           state <= #1 1'b0; // go to normal state
	                           den   <= #1 1'b1; // set data output enable
	                           deno  <= #1 1'b1; // oops, zero-block should have been output
	                       end
	             end
	      endcase
endmodule

module jpeg_rle1(clk, rst, ena, go, din, rlen, size, amp, den, dcterm);

	//
	// parameters
	//

	//
	// inputs & outputs
	//
	input         clk;    // system clock
	input         rst;    // asynchronous reset
	input         ena;    // clock enable
	input         go;
	input  [11:0] din;    // data input

	output [ 3:0] rlen;   // run-length
	output [ 3:0] size;   // size (or category)
	output [11:0] amp;    // amplitude
	output        den;    // data output enable
	output        dcterm; // DC-term (start of new block)

	reg [ 3:0] rlen, size;
	reg [11:0] amp;
	reg        den, dcterm;

	//
	// variables
	//

	reg [5:0] sample_cnt;
	reg [3:0] zero_cnt;
	wire      is_zero;

	reg       state;
	parameter dc = 1'b0;
	parameter ac = 1'b1;

	//
	// module body
	//

	//
	// function declarations
	//

	// Function abs; absolute value
	function [10:0] abs;
	  input [11:0] a;
	begin
	  if (a[11])
	      abs = (~a[10:0]) +11'h1;
	  else
	      abs = a[10:0];
	end
	endfunction

	// Function cat, calculates category for Din
	function [3:0] cat;
	  input [11:0] a;
	  reg   [10:0] tmp;
	begin
	    // get absolute value
	    tmp = abs(a);

	    // determine category
	    casex(tmp) // synopsys full_case parallel_case
	      11'b1??_????_???? : cat = 4'hb; // 1024..2047
	      11'b01?_????_???? : cat = 4'ha; //  512..1023
	      11'b001_????_???? : cat = 4'h9; //  256.. 511
	      11'b000_1???_???? : cat = 4'h8; //  128.. 255
	      11'b000_01??_???? : cat = 4'h7; //   64.. 127
	      11'b000_001?_???? : cat = 4'h6; //   32..  63
	      11'b000_0001_???? : cat = 4'h5; //   16..  31
	      11'b000_0000_1??? : cat = 4'h4; //    8..  15
	      11'b000_0000_01?? : cat = 4'h3; //    4..   7
	      11'b000_0000_001? : cat = 4'h2; //    2..   3
	      11'b000_0000_0001 : cat = 4'h1; //    1
	      11'b000_0000_0000 : cat = 4'h0; //    0 (DC only)
	    endcase
	end
	endfunction


	// Function modamp, calculate additional bits per category
	function [10:0] rem;
	  input [11:0] a;
	  reg   [10:0] tmp, tmp_rem;
	begin
	    tmp_rem = a[11] ? (a[10:0] - 10'h1) : a[10:0];

	    if(0)
	    begin
	      // get absolute value
	      tmp = abs(a);

	      casex(tmp) // synopsys full_case parallel_case
	        11'b1??_????_???? : rem = tmp_rem & 11'b111_1111_1111;
	        11'b01?_????_???? : rem = tmp_rem & 11'b011_1111_1111;
	        11'b001_????_???? : rem = tmp_rem & 11'b001_1111_1111;
	        11'b000_1???_???? : rem = tmp_rem & 11'b000_1111_1111;
	        11'b000_01??_???? : rem = tmp_rem & 11'b000_0111_1111;
	        11'b000_001?_???? : rem = tmp_rem & 11'b000_0011_1111;
	        11'b000_0001_???? : rem = tmp_rem & 11'b000_0001_1111;
	        11'b000_0000_1??? : rem = tmp_rem & 11'b000_0000_1111;
	        11'b000_0000_01?? : rem = tmp_rem & 11'b000_0000_0111;
	        11'b000_0000_001? : rem = tmp_rem & 11'b000_0000_0011;
	        11'b000_0000_0001 : rem = tmp_rem & 11'b000_0000_0001;
	        11'b000_0000_0000 : rem = tmp_rem & 11'b000_0000_0000;
	      endcase
	    end
	    else
	      rem = tmp_rem;
	end
	endfunction

	// detect zero
	assign is_zero = ~|din;

	// assign dout
	always @(posedge clk)
	  if (ena)
	      amp <= #1 rem(din);

	// generate sample counter
	always @(posedge clk)
	  if (ena)
	      if (go)
	          sample_cnt <= #1 1; // count AC-terms, 'go=1' is sample-zero
	      else
	          sample_cnt <= #1 sample_cnt +1;

	// generate zero counter
	always @(posedge clk)
	  if (ena)
	      if (is_zero)
	          zero_cnt <= #1 zero_cnt +1;
	      else
	          zero_cnt <= #1 0;

	// statemachine, create intermediate results
	always @(posedge clk or negedge rst)
	  if(!rst)
	    begin
	        state  <= #1 dc;
	        rlen   <= #1 0;
	        size   <= #1 0;
	        den    <= #1 1'b0;
	        dcterm <= #1 1'b0;
	    end
	  else if (ena)
	    case (state) // synopsys full_case parallel_case
	      dc:
	        begin
	            rlen <= #1 0;
	            size <= #1 cat(din);

	            if(go)
	              begin
	                  state  <= #1 ac;
	                  den    <= #1 1'b1;
	                  dcterm <= #1 1'b1;
	              end
	            else
	              begin
	                  state  <= #1 dc;
	                  den    <= #1 1'b0;
	                  dcterm <= #1 1'b0;
	              end
	        end

	      ac:
	        if(&sample_cnt)   // finished current block
	           begin
	               state <= #1 dc;

	               if (is_zero) // last sample zero? send EOB
	                  begin
	                      rlen   <= #1 0;
	                      size   <= #1 0;
	                      den    <= #1 1'b1;
	                      dcterm <= #1 1'b0;
	                  end
	               else
	                  begin
	                      rlen <= #1 zero_cnt;
	                      size <= #1 cat(din);
	                      den  <= #1 1'b1;
	                      dcterm <= #1 1'b0;
	                  end
	           end
	        else
	           begin
	               state  <= #1 ac;

	               rlen   <= #1 zero_cnt;
	               dcterm <= #1 1'b0;

	               if (is_zero)
	                  begin
	                      size   <= #1 0;
	                      den    <= #1 &zero_cnt;
	                  end
	               else
	                  begin
	                      size <= #1 cat(din);
	                      den  <= #1 1'b1;
	                  end
	           end
	    endcase

endmodule
