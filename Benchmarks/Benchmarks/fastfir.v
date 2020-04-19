////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fastfir.v
//
// Project:	DSP Filtering Example Project
//
// Purpose:	Implement a high speed (1-output per clock), adjustable tap
//		FIR.  Unlike our previous example in genericfir.v, this example
//	attempts to optimize the algorithm via the use of a better delay
//	structure for the input samples.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2018, Gisselquist Technology, LLC
//
// This file is part of the DSP filtering set of designs.
//
// The DSP filtering designs are free RTL designs: you can redistribute them
// and/or modify any of them under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.
//
// The DSP filtering designs are distributed in the hope that they will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
// General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with these designs.  (It's in the $(ROOT)/doc directory.  Run make
// with no target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	LGPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/lgpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	fastfir(i_clk, i_reset, i_tap_wr, i_tap, i_ce, i_sample, o_result);
`ifdef	FORMAL
	parameter		NTAPS=16, IW=9, TW=IW, OW=2*IW+5;
`else
	parameter		NTAPS=128, IW=12, TW=IW, OW=2*IW+7;
`endif
	parameter [0:0]		FIXED_TAPS=0;
	input	wire			i_clk, i_reset;
	//
	input	wire			i_tap_wr;	// Ignored if FIXED_TAPS
	input	wire	[(TW-1):0]	i_tap;		// Ignored if FIXED_TAPS
	//
	input	wire			i_ce;
	input	wire	[(IW-1):0]	i_sample;
	output	wire	[(OW-1):0]	o_result;

	wire	[(TW-1):0] tap		[NTAPS:0];
	wire	[(TW-1):0] tapout	[NTAPS:0];
	wire	[(IW-1):0] sample	[NTAPS:0];
	wire	[(OW-1):0] result	[NTAPS:0];
	wire		tap_wr;

	// The first sample in our sample chain is the sample we are given
	assign	sample[0]	= i_sample;
	// Initialize the partial summing accumulator with zero
	assign	result[0]	= 0;

	genvar	k;
	generate
	if(FIXED_TAPS)
	begin
		initial $readmemh("taps.hex", tap);

		assign	tap_wr = 1'b0;
	end else begin
		assign	tap_wr = i_tap_wr;
		assign	tap[0] = i_tap;
	end

	assign	tapout[0] = 0;

	for(k=0; k<NTAPS; k=k+1)
	begin: FILTER

		firtap #(.FIXED_TAPS(FIXED_TAPS),
				.IW(IW), .OW(OW), .TW(TW),
				.INITIAL_VALUE(0))
			tapk(i_clk, i_reset,
				// Tap update circuitry
				tap_wr, tap[k], tapout[k+1],
				// Sample delay line
				// We'll let the optimizer trim away sample[k+1]
				i_ce, sample[0], sample[k+1],
				// The output accumulator
				result[k], result[k+1]);

		if (!FIXED_TAPS)
			assign	tap[k+1] = tapout[k+1];

		// Make verilator happy
		// verilator lint_off UNUSED
		wire	[(TW-1):0]	unused_tap;
		if (FIXED_TAPS)
			assign	unused_tap    = tapout[k+1];
		// verilator lint_on UNUSED
	end endgenerate

	assign	o_result = result[NTAPS];

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[(TW):0]	unused;
	assign	unused = { i_tap_wr, i_tap };
	// verilator lint_on UNUSED

`ifdef	FORMAL
`define	PHASE_ONE_ASSERT	assert
`define	PHASE_TWO_ASSERT	assert

`ifdef	PHASE_TWO
`undef	PHASE_ONE_ASSERT
`define	PHASE_ONE_ASSERT	assume
`endif

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;


	///////////////////////////
	//
	// Assumptions
	//
	///////////////////////////

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_ce))
			//&&($past(f_past_valid))&&(!$past(i_ce,2))
			)
		assume(i_ce);
	// always @(*) if (!i_reset) assume(i_ce);

	always @(posedge i_clk)
	if ((!f_past_valid)||(i_reset)||($past(i_reset)))
		assume(i_sample == 0);

////////////////////////////////////////////////////////////////////////////////
//
// The Contract
//
// 1. Given an impulse, either +/- 2^k, return an impulse response
// 2. No overflowing
//
////////////////////////////////////////////////////////////////////////////////


	wire	[IW-1:0]	f_impulse;
	assign			f_impulse = $anyconst;
	wire			f_is_impulse, f_sign;
	wire	[4:0]		f_zeros;

	integer	m;
	always @(*)
	begin
		f_is_impulse = 1'b0;
		f_zeros = 5'h0;
		if (f_impulse == { 1'b1, {(IW-1){1'b0}}})
		begin
			f_is_impulse = 1'b1;
			f_zeros = IW-1;
		end else if (f_impulse == {(IW){1'b1}})
		begin
			f_is_impulse = 1'b1;
			f_zeros = 0;
		end else if (f_impulse[IW-1])
		begin
			// Signed impulse
			for(m=0; m<IW-1; m=m+1)
			begin
				if (f_impulse == (-1 << m))
				begin
					f_is_impulse = 1'b1;
					f_zeros = m;
				end
			end
		end else begin
			// Unsigned impulse
			for(m=0; m<IW-1; m=m+1)
			begin
				if (f_impulse == (1 << m))
				begin
					f_is_impulse = 1'b1;
					f_zeros = m;
				end
			end
		end

		f_sign = f_impulse[IW-1];
		assume(f_is_impulse);
	end

	reg	[9:0]	f_counts_to_clear, f_counts_since_impulse;
	initial	f_counts_to_clear = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_counts_to_clear <= 0;
	else if (i_tap_wr)
		f_counts_to_clear <= NTAPS;
	else if (i_ce)
	begin
		if ((i_sample != 0)||(i_tap_wr))
			f_counts_to_clear <= NTAPS;
		else // if (i_sample == 0)
			f_counts_to_clear <= f_counts_to_clear - 1'b1;
	end

	always @(*)
	if (f_counts_to_clear == 0)
		`PHASE_ONE_ASSERT((f_counts_since_impulse == 0)
			||(f_counts_since_impulse>NTAPS));

	initial	f_counts_since_impulse = 0;
	always @(posedge i_clk)
	if ((i_reset)||(!f_past_valid)||($past(i_reset))||(i_tap_wr))
		f_counts_since_impulse <= 0;
	else if (f_counts_since_impulse > NTAPS)
		f_counts_since_impulse <= 0;
	else if (i_ce)
	begin
		if ((i_sample != 0)&&(i_sample != f_impulse))
			f_counts_since_impulse <= 0;
		else if (i_sample == f_impulse)
			f_counts_since_impulse <= (f_counts_to_clear == 0);
		else if (f_counts_since_impulse > 0) // &&(i_sample == 0)
			f_counts_since_impulse <= f_counts_since_impulse + 1'b1;
	end


	///////////////////////////////////////
	//
	// Verify no overflow
	//
	///////////////////////////////////////
	always @(*)
	begin
		for(m=0; m<NTAPS; m=m+1)
		begin
			`PHASE_ONE_ASSERT((result[m][OW-1:OW-2] == 2'b00)
				||(result[m][OW-1:OW-2] == 2'b11));
		end
		`PHASE_ONE_ASSERT((o_result[OW-1:OW-2] == 2'b00)
			||(o_result[OW-1:OW-2] == 2'b11));
	end

	///////////////////////////////////////
	//
	// Verify the reset
	//
	///////////////////////////////////////
	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		for(m=1; m<NTAPS; m=m+1)
			`PHASE_ONE_ASSERT(sample[m] == 0);

		for(m=0; m<NTAPS; m=m+1)
			`PHASE_ONE_ASSERT(result[m] == 0);

		`PHASE_ONE_ASSERT(result[NTAPS] == 0);
	end

	always @(*)
	begin
		for(m=0; m<NTAPS; m=m+1)
			`PHASE_ONE_ASSERT((f_counts_to_clear > m)||(result[NTAPS-1-m] == 0));
	end

	//////////////////////////////////////////////
	always @(*)
	if (f_counts_since_impulse > 0)
		`PHASE_ONE_ASSERT(f_counts_to_clear == NTAPS + 1 - f_counts_since_impulse);


`ifdef	PHASE_TWO
	///////////////////////////////////////
	//
	// Verify the impulse response
	//
	///////////////////////////////////////
	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
		`PHASE_TWO_ASSERT(o_result == 0);
	else if (!$past(i_ce))
		`PHASE_TWO_ASSERT($stable(o_result));
	else if ((f_counts_since_impulse > 1)&&(f_counts_since_impulse <= NTAPS))
	begin
		if (f_sign)
			`PHASE_TWO_ASSERT(o_result == (-tapout[NTAPS-(f_counts_since_impulse-2)]<<f_zeros));
		else
			`PHASE_TWO_ASSERT(o_result == ( tapout[NTAPS-(f_counts_since_impulse-2)]<<f_zeros));
	end


	wire	[IW+TW-1:0]	widetaps	[0:NTAPS];
	wire	[IW+TW-1:0]	staps		[0:NTAPS];
	genvar	gk;

	generate begin for(gk=0; gk <= NTAPS; gk=gk+1)
	begin

		assign	widetaps[gk] = { {(IW){tapout[gk][TW-1]}}, tapout[gk][TW-1:0] };
		assign	staps[gk] = widetaps[gk] << f_zeros;

	end end endgenerate

	//
	// Insure that our internal variables are properly set between the
	// impulse and its output
	//
	always @(*)
	begin
	if ((f_counts_since_impulse >= 2)&&(f_counts_since_impulse < 2+NTAPS))
	begin
	for(m=0; m<NTAPS; m=m+1)
		if ((m >= (f_counts_since_impulse-2))&&(f_sign))
			`PHASE_TWO_ASSERT(result[m+1]
				== (-staps[m-(f_counts_since_impulse-2)+1]));
		else if (m >= (f_counts_since_impulse-2))
			`PHASE_TWO_ASSERT(result[m+1]
				== (staps[m-(f_counts_since_impulse-2)+1]));
		else
			`PHASE_TWO_ASSERT(result[m+1] == 0);
	end
`endif // PHASE_TWO
	always @(*)
	if (i_tap_wr)
		assume(i_reset);
	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_tap_wr)))
		assume(i_reset);
`endif // FORMAL
endmodule


////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	firtap.v
//
// Project:	DSP Filtering Example Project
//
// Purpose:	Implements a single tap within a FIR filter.  This particular
//		FIR tap design is specifically designed to make it easier
//	for the parent module to add (or remove) taps.  Hence, by stringing
//	N of these components together, an N tap filter can be created.
//
//	This fir tap is a component of genericfir.v, the high speed (1-sample
//	per clock, adjustable tap) FIR filter.
//
//	Be aware, implementing a FIR tap in this manner can be a very expensive
//	use of FPGA resources, very quickly necessitating a large FPGA for
//	even the smallest (128 tap) filters.
//
//	Resource usage may be minimized by minizing the number of taps,
//	minimizing the number of bits in each tap, and/or the number of bits
//	in the input (and output) samples.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2018, Gisselquist Technology, LLC
//
// This file is part of the DSP filtering set of designs.
//
// The DSP filtering designs are free RTL designs: you can redistribute them
// and/or modify any of them under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.
//
// The DSP filtering designs are distributed in the hope that they will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
// General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with these designs.  (It's in the $(ROOT)/doc directory.  Run make
// with no target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	LGPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/lgpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	firtap(i_clk, i_reset, i_tap_wr, i_tap, o_tap,
		i_ce, i_sample, o_sample,
		i_partial_acc, o_acc);
	parameter		IW=16, TW=IW, OW=IW+TW+8;
	parameter [0:0]		FIXED_TAPS=0;
	parameter [(TW-1):0]	INITIAL_VALUE=0;
	//
	input	wire			i_clk, i_reset;
	//
	input	wire			i_tap_wr;
	input	wire	[(TW-1):0]	i_tap;
	output	wire signed [(TW-1):0]	o_tap;
	//
	input	wire			i_ce;
	input	wire signed [(IW-1):0]	i_sample;
	output	wire	[(IW-1):0]	o_sample;
	//
	input	wire	[(OW-1):0]	i_partial_acc;
	output	wire	[(OW-1):0]	o_acc;
	//

	reg		[(IW-1):0]	delayed_sample;
	reg	signed	[(TW+IW-1):0]	product;

	// Determine the tap we are using
	generate
	if (FIXED_TAPS != 0)
		// If our taps are fixed, the tap is given by the i_tap
		// external input.  This allows the parent module to be
		// able to use readmemh to set all of the taps in a filter
		assign	o_tap = i_tap;

	else begin
		// If the taps are adjustable, then use the i_tap_wr signal
		// to know when to adjust the tap.  In this case, taps are
		// strung together through the filter structure--our output
		// tap becomes the input tap of the next tap module, and
		// i_tap_wr causes all of them to shift forward by one.
		reg	[(TW-1):0]	tap;

		initial	tap = INITIAL_VALUE;
		always @(posedge i_clk)
			if (i_tap_wr)
				tap <= i_tap;
		assign o_tap = tap;

	end endgenerate

	// Forward the sample on down the line, to be the input sample for the
	// next component
	initial	o_sample = 0;
	initial	delayed_sample = 0;
	always @(posedge i_clk)
		if (i_reset)
		begin
			delayed_sample <= 0;
			o_sample <= 0;
		end else if (i_ce)
		begin
			// Note the two sample delay in this forwarding
			// structure.  This aligns the inputs up so that the
			// accumulator structure (below) works.
			delayed_sample <= i_sample;
			o_sample <= delayed_sample;
		end

`ifndef	FORMAL
	// Multiply the filter tap by the incoming sample
	always @(posedge i_clk)
		if (i_reset)
			product <= 0;
		else if (i_ce)
			product <= o_tap * i_sample;
`else
	wire	[(TW+IW-1):0]	w_pre_product;

	abs_mpy #(.AW(TW), .BW(IW), .OPT_SIGNED(1'b1))
		abs_bypass(i_clk, i_reset, o_tap, i_sample, w_pre_product);

	initial	product = 0;
	always @(posedge i_clk)
	if (i_reset)
		product <= 0;
	else if (i_ce)
		product <= w_pre_product;
`endif

	// Continue summing together the output components of the FIR filter
	initial	o_acc = 0;
	always @(posedge i_clk)
		if (i_reset)
			o_acc <= 0;
		else if (i_ce)
			o_acc <= i_partial_acc
				+ { {(OW-(TW+IW)){product[(TW+IW-1)]}},
						product };


	// Make verilator happy
	// verilate lint_on  UNUSED
	wire	unused;
	assign	unused = i_tap_wr;
	// verilate lint_off UNUSED
endmodule
