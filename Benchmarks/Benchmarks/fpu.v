/////////////////////////////////////////////////////////////////////
////                                                             ////
////  EXCEPT                                                     ////
////  Floating Point Exception/Special Numbers Unit              ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000 Rudolf Usselmann                         ////
////                    rudi@asics.ws                            ////
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


`timescale 1ns / 100ps


module except(	clk, opa, opb, inf, ind, qnan, snan, opa_nan, opb_nan,
		opa_00, opb_00, opa_inf, opb_inf, opa_dn, opb_dn);
input		clk;
input	[31:0]	opa, opb;
output		inf, ind, qnan, snan, opa_nan, opb_nan;
output		opa_00, opb_00;
output		opa_inf, opb_inf;
output		opa_dn;
output		opb_dn;

////////////////////////////////////////////////////////////////////////
//
// Local Wires and registers
//

wire	[7:0]	expa, expb;		// alias to opX exponent
wire	[22:0]	fracta, fractb;		// alias to opX fraction
reg		expa_ff, infa_f_r, qnan_r_a, snan_r_a;
reg		expb_ff, infb_f_r, qnan_r_b, snan_r_b;
reg		inf, ind, qnan, snan;	// Output registers
reg		opa_nan, opb_nan;
reg		expa_00, expb_00, fracta_00, fractb_00;
reg		opa_00, opb_00;
reg		opa_inf, opb_inf;
reg		opa_dn, opb_dn;

////////////////////////////////////////////////////////////////////////
//
// Aliases
//

assign   expa = opa[30:23];
assign   expb = opb[30:23];
assign fracta = opa[22:0];
assign fractb = opb[22:0];

////////////////////////////////////////////////////////////////////////
//
// Determine if any of the input operators is a INF or NAN or any other special number
//

always @(posedge clk)
	expa_ff <= #1 &expa;

always @(posedge clk)
	expb_ff <= #1 &expb;
	
always @(posedge clk)
	infa_f_r <= #1 !(|fracta);

always @(posedge clk)
	infb_f_r <= #1 !(|fractb);

always @(posedge clk)
	qnan_r_a <= #1  fracta[22];

always @(posedge clk)
	snan_r_a <= #1 !fracta[22] & |fracta[21:0];
	
always @(posedge clk)
	qnan_r_b <= #1  fractb[22];

always @(posedge clk)
	snan_r_b <= #1 !fractb[22] & |fractb[21:0];

always @(posedge clk)
	ind  <= #1 (expa_ff & infa_f_r) & (expb_ff & infb_f_r);

always @(posedge clk)
	inf  <= #1 (expa_ff & infa_f_r) | (expb_ff & infb_f_r);

always @(posedge clk)
	qnan <= #1 (expa_ff & qnan_r_a) | (expb_ff & qnan_r_b);

always @(posedge clk)
	snan <= #1 (expa_ff & snan_r_a) | (expb_ff & snan_r_b);

always @(posedge clk)
	opa_nan <= #1 &expa & (|fracta[22:0]);

always @(posedge clk)
	opb_nan <= #1 &expb & (|fractb[22:0]);

always @(posedge clk)
	opa_inf <= #1 (expa_ff & infa_f_r);

always @(posedge clk)
	opb_inf <= #1 (expb_ff & infb_f_r);

always @(posedge clk)
	expa_00 <= #1 !(|expa);

always @(posedge clk)
	expb_00 <= #1 !(|expb);

always @(posedge clk)
	fracta_00 <= #1 !(|fracta);

always @(posedge clk)
	fractb_00 <= #1 !(|fractb);

always @(posedge clk)
	opa_00 <= #1 expa_00 & fracta_00;

always @(posedge clk)
	opb_00 <= #1 expb_00 & fractb_00;

always @(posedge clk)
	opa_dn <= #1 expa_00;

always @(posedge clk)
	opb_dn <= #1 expb_00;

endmodule


/*

FPU Operations (fpu_op):
========================

0 = add
1 = sub
2 = mul
3 = div
4 =
5 =
6 =
7 =

Rounding Modes (rmode):
=======================

0 = round_nearest_even
1 = round_to_zero
2 = round_up
3 = round_down

*/


module fpu( clk, rmode, fpu_op, opa, opb, out, inf, snan, qnan, ine, overflow, underflow, zero, div_by_zero);
input		clk;
input	[1:0]	rmode;
input	[2:0]	fpu_op;
input	[31:0]	opa, opb;
output	[31:0]	out;
output		inf, snan, qnan;
output		ine;
output		overflow, underflow;
output		zero;
output		div_by_zero;

parameter	INF  = 31'h7f800000,
		QNAN = 31'h7fc00001,
		SNAN = 31'h7f800001;

////////////////////////////////////////////////////////////////////////
//
// Local Wires
//
reg		zero;
reg	[31:0]	opa_r, opb_r;		// Input operand registers
reg	[31:0]	out;			// Output register
reg		div_by_zero;		// Divide by zero output register
wire		signa, signb;		// alias to opX sign
wire		sign_fasu;		// sign output
wire	[26:0]	fracta, fractb;		// Fraction Outputs from EQU block
wire	[7:0]	exp_fasu;		// Exponent output from EQU block
reg	[7:0]	exp_r;			// Exponent output (registerd)
wire	[26:0]	fract_out_d;		// fraction output
wire		co;			// carry output
reg	[27:0]	fract_out_q;		// fraction output (registerd)
wire	[30:0]	out_d;			// Intermediate final result output
wire		overflow_d, underflow_d;// Overflow/Underflow Indicators
reg		overflow, underflow;	// Output registers for Overflow & Underflow
reg		inf, snan, qnan;	// Output Registers for INF, SNAN and QNAN
reg		ine;			// Output Registers for INE
reg	[1:0]	rmode_r1, rmode_r2, 	// Pipeline registers for rounding mode
		rmode_r3;
reg	[2:0]	fpu_op_r1, fpu_op_r2,	// Pipeline registers for fp opration
		fpu_op_r3;
wire		mul_inf, div_inf;
wire		mul_00, div_00;

////////////////////////////////////////////////////////////////////////
//
// Input Registers
//

always @(posedge clk)
	opa_r <= #1 opa;

always @(posedge clk)
	opb_r <= #1 opb;

always @(posedge clk)
	rmode_r1 <= #1 rmode;

always @(posedge clk)
	rmode_r2 <= #1 rmode_r1;

always @(posedge clk)
	rmode_r3 <= #1 rmode_r2;

always @(posedge clk)
	fpu_op_r1 <= #1 fpu_op;

always @(posedge clk)
	fpu_op_r2 <= #1 fpu_op_r1;

always @(posedge clk)
	fpu_op_r3 <= #1 fpu_op_r2;

////////////////////////////////////////////////////////////////////////
//
// Exceptions block
//
wire		inf_d, ind_d, qnan_d, snan_d, opa_nan, opb_nan;
wire		opa_00, opb_00;
wire		opa_inf, opb_inf;
wire		opa_dn, opb_dn;

except u0(	.clk(clk),
		.opa(opa_r), .opb(opb_r),
		.inf(inf_d), .ind(ind_d),
		.qnan(qnan_d), .snan(snan_d),
		.opa_nan(opa_nan), .opb_nan(opb_nan),
		.opa_00(opa_00), .opb_00(opb_00),
		.opa_inf(opa_inf), .opb_inf(opb_inf),
		.opa_dn(opa_dn), .opb_dn(opb_dn)
		);

////////////////////////////////////////////////////////////////////////
//
// Pre-Normalize block
// - Adjusts the numbers to equal exponents and sorts them
// - determine result sign
// - determine actual operation to perform (add or sub)
//

wire		nan_sign_d, result_zero_sign_d;
reg		sign_fasu_r;
wire	[7:0]	exp_mul;
wire		sign_mul;
reg		sign_mul_r;
wire	[23:0]	fracta_mul, fractb_mul;
wire		inf_mul;
reg		inf_mul_r;
wire	[1:0]	exp_ovf;
reg	[1:0]	exp_ovf_r;
wire		sign_exe;
reg		sign_exe_r;
wire	[2:0]	underflow_fmul_d;


pre_norm u1(.clk(clk),				// System Clock
	.rmode(rmode_r2),			// Roundin Mode
	.add(!fpu_op_r1[0]),			// Add/Sub Input
	.opa(opa_r),  .opb(opb_r),		// Registered OP Inputs
	.opa_nan(opa_nan),			// OpA is a NAN indicator
	.opb_nan(opb_nan),			// OpB is a NAN indicator
	.fracta_out(fracta),			// Equalized and sorted fraction
	.fractb_out(fractb),			// outputs (Registered)
	.exp_dn_out(exp_fasu),			// Selected exponent output (registered);
	.sign(sign_fasu),			// Encoded output Sign (registered)
	.nan_sign(nan_sign_d),			// Output Sign for NANs (registered)
	.result_zero_sign(result_zero_sign_d),	// Output Sign for zero result (registered)
	.fasu_op(fasu_op)			// Actual fasu operation output (registered)
	);

always @(posedge clk)
	sign_fasu_r <= #1 sign_fasu;

pre_norm_fmul u2(
		.clk(clk),
		.fpu_op(fpu_op_r1),
		.opa(opa_r), .opb(opb_r),
		.fracta(fracta_mul),
		.fractb(fractb_mul),
		.exp_out(exp_mul),	// FMUL exponent output (registered)
		.sign(sign_mul),	// FMUL sign output (registered)
		.sign_exe(sign_exe),	// FMUL exception sign output (registered)
		.inf(inf_mul),		// FMUL inf output (registered)
		.exp_ovf(exp_ovf),	// FMUL exponnent overflow output (registered)
		.underflow(underflow_fmul_d)
		);


always @(posedge clk)
	sign_mul_r <= #1 sign_mul;

always @(posedge clk)
	sign_exe_r <= #1 sign_exe;

always @(posedge clk)
	inf_mul_r <= #1 inf_mul;

always @(posedge clk)
	exp_ovf_r <= #1 exp_ovf;


////////////////////////////////////////////////////////////////////////
//
// Add/Sub
//

add_sub27 u3(
	.add(fasu_op),			// Add/Sub
	.opa(fracta),			// Fraction A input
	.opb(fractb),			// Fraction B Input
	.sum(fract_out_d),		// SUM output
	.co(co_d) );			// Carry Output

always @(posedge clk)
	fract_out_q <= #1 {co_d, fract_out_d};

////////////////////////////////////////////////////////////////////////
//
// Mul
//
wire	[47:0]	prod;

mul_r2 u5(.clk(clk), .opa(fracta_mul), .opb(fractb_mul), .prod(prod));

////////////////////////////////////////////////////////////////////////
//
// Divide
//
wire	[49:0]	quo;
wire	[49:0]	fdiv_opa;
wire	[49:0]	remainder;
wire		remainder_00;
reg	[4:0]	div_opa_ldz_d, div_opa_ldz_r1, div_opa_ldz_r2;

always @(fracta_mul)
	casex(fracta_mul[22:0])
	   23'b1??????????????????????: div_opa_ldz_d = 1;
	   23'b01?????????????????????: div_opa_ldz_d = 2;
	   23'b001????????????????????: div_opa_ldz_d = 3;
	   23'b0001???????????????????: div_opa_ldz_d = 4;
	   23'b00001??????????????????: div_opa_ldz_d = 5;
	   23'b000001?????????????????: div_opa_ldz_d = 6;
	   23'b0000001????????????????: div_opa_ldz_d = 7;
	   23'b00000001???????????????: div_opa_ldz_d = 8;
	   23'b000000001??????????????: div_opa_ldz_d = 9;
	   23'b0000000001?????????????: div_opa_ldz_d = 10;
	   23'b00000000001????????????: div_opa_ldz_d = 11;
	   23'b000000000001???????????: div_opa_ldz_d = 12;
	   23'b0000000000001??????????: div_opa_ldz_d = 13;
	   23'b00000000000001?????????: div_opa_ldz_d = 14;
	   23'b000000000000001????????: div_opa_ldz_d = 15;
	   23'b0000000000000001???????: div_opa_ldz_d = 16;
	   23'b00000000000000001??????: div_opa_ldz_d = 17;
	   23'b000000000000000001?????: div_opa_ldz_d = 18;
	   23'b0000000000000000001????: div_opa_ldz_d = 19;
	   23'b00000000000000000001???: div_opa_ldz_d = 20;
	   23'b000000000000000000001??: div_opa_ldz_d = 21;
	   23'b0000000000000000000001?: div_opa_ldz_d = 22;
	   23'b0000000000000000000000?: div_opa_ldz_d = 23;
	endcase

assign fdiv_opa = !(|opa_r[30:23]) ? {(fracta_mul<<div_opa_ldz_d), 26'h0} : {fracta_mul, 26'h0};


div_r2 u6(.clk(clk), .opa(fdiv_opa), .opb(fractb_mul), .quo(quo), .rem(remainder));

assign remainder_00 = !(|remainder);

always @(posedge clk)
	div_opa_ldz_r1 <= #1 div_opa_ldz_d;

always @(posedge clk)
	div_opa_ldz_r2 <= #1 div_opa_ldz_r1;


////////////////////////////////////////////////////////////////////////
//
// Normalize Result
//
wire		ine_d;
reg	[47:0]	fract_denorm;
wire	[47:0]	fract_div;
wire		sign_d;
reg		sign;
reg	[30:0]	opa_r1;
reg	[47:0]	fract_i2f;
reg		opas_r1, opas_r2;
wire		f2i_out_sign;

always @(posedge clk)			// Exponent must be once cycle delayed
	case(fpu_op_r2)
	  0,1:	exp_r <= #1 exp_fasu;
	  2,3:	exp_r <= #1 exp_mul;
	  4:	exp_r <= #1 0;
	  5:	exp_r <= #1 opa_r1[30:23];
	endcase

assign fract_div = (opb_dn ? quo[49:2] : {quo[26:0], 21'h0});

always @(posedge clk)
	opa_r1 <= #1 opa_r[30:0];

always @(posedge clk)
	fract_i2f <= #1 (fpu_op_r2==5) ?
			(sign_d ?  1-{24'h00, (|opa_r1[30:23]), opa_r1[22:0]}-1 : {24'h0, (|opa_r1[30:23]), opa_r1[22:0]}) :
			(sign_d ? 1 - {opa_r1, 17'h01} : {opa_r1, 17'h0});

always @(fpu_op_r3 or fract_out_q or prod or fract_div or fract_i2f)
	case(fpu_op_r3)
	   0,1:	fract_denorm = {fract_out_q, 20'h0};
	   2:	fract_denorm = prod;
	   3:	fract_denorm = fract_div;
	   4,5:	fract_denorm = fract_i2f;
	endcase


always @(posedge clk)
	opas_r1 <= #1 opa_r[31];

always @(posedge clk)
	opas_r2 <= #1 opas_r1;

assign sign_d = fpu_op_r2[1] ? sign_mul : sign_fasu;

always @(posedge clk)
	sign <= #1 (rmode_r2==2'h3) ? !sign_d : sign_d;

post_norm u4(.clk(clk),			// System Clock
	.fpu_op(fpu_op_r3),		// Floating Point Operation
	.opas(opas_r2),			// OPA Sign
	.sign(sign),			// Sign of the result
	.rmode(rmode_r3),		// Rounding mode
	.fract_in(fract_denorm),	// Fraction Input
	.exp_ovf(exp_ovf_r),		// Exponent Overflow
	.exp_in(exp_r),			// Exponent Input
	.opa_dn(opa_dn),		// Operand A Denormalized
	.opb_dn(opb_dn),		// Operand A Denormalized
	.rem_00(remainder_00),		// Diveide Remainder is zero
	.div_opa_ldz(div_opa_ldz_r2),	// Divide opa leading zeros count
	.output_zero(mul_00 | div_00),	// Force output to Zero
	.out(out_d),			// Normalized output (un-registered)
	.ine(ine_d),			// Result Inexact output (un-registered)
	.overflow(overflow_d),		// Overflow output (un-registered)
	.underflow(underflow_d),	// Underflow output (un-registered)
	.f2i_out_sign(f2i_out_sign)	// F2I Output Sign
	);

////////////////////////////////////////////////////////////////////////
//
// FPU Outputs
//
reg		fasu_op_r1, fasu_op_r2;
wire	[30:0]	out_fixed;
wire		output_zero_fasu;
wire		output_zero_fdiv;
wire		output_zero_fmul;
reg		inf_mul2;
wire		overflow_fasu;
wire		overflow_fmul;
wire		overflow_fdiv;
wire		inf_fmul;
wire		sign_mul_final;
wire		out_d_00;
wire		sign_div_final;
wire		ine_mul, ine_mula, ine_div, ine_fasu;
wire		underflow_fasu, underflow_fmul, underflow_fdiv;
wire		underflow_fmul1;
reg	[2:0]	underflow_fmul_r;
reg		opa_nan_r;


always @(posedge clk)
	fasu_op_r1 <= #1 fasu_op;

always @(posedge clk)
	fasu_op_r2 <= #1 fasu_op_r1;

always @(posedge clk)
	inf_mul2 <= #1 exp_mul == 8'hff;


// Force pre-set values for non numerical output
assign mul_inf = (fpu_op_r3==3'b010) & (inf_mul_r | inf_mul2) & (rmode_r3==2'h0);
assign div_inf = (fpu_op_r3==3'b011) & (opb_00 | opa_inf);

assign mul_00 = (fpu_op_r3==3'b010) & (opa_00 | opb_00);
assign div_00 = (fpu_op_r3==3'b011) & (opa_00 | opb_inf);

assign out_fixed = (	(qnan_d | snan_d) |
			(ind_d & !fasu_op_r2) | 
			((fpu_op_r3==3'b011) & opb_00 & opa_00) |
			(((opa_inf & opb_00) | (opb_inf & opa_00 )) & fpu_op_r3==3'b010)
		   )  ? QNAN : INF;

always @(posedge clk)
	out[30:0] <= #1 (mul_inf | div_inf | (inf_d & (fpu_op_r3!=3'b011) & (fpu_op_r3!=3'b101)) | snan_d | qnan_d) & fpu_op_r3!=3'b100 ? out_fixed :
			out_d;

assign out_d_00 = !(|out_d);

assign sign_mul_final = (sign_exe_r & ((opa_00 & opb_inf) | (opb_00 & opa_inf))) ? !sign_mul_r : sign_mul_r;
assign sign_div_final = (sign_exe_r & (opa_inf & opb_inf)) ? !sign_mul_r : sign_mul_r | (opa_00 & opb_00);

always @(posedge clk)
	out[31] <= #1	((fpu_op_r3==3'b101) & out_d_00) ? (f2i_out_sign & !(qnan_d | snan_d) ) :
			((fpu_op_r3==3'b010) & !(snan_d | qnan_d)) ?	sign_mul_final :
			((fpu_op_r3==3'b011) & !(snan_d | qnan_d)) ?	sign_div_final :
			(snan_d | qnan_d | ind_d) ?			nan_sign_d :
			output_zero_fasu ?				result_zero_sign_d :
									sign_fasu_r;

// Exception Outputs
assign ine_mula = ((inf_mul_r |  inf_mul2 | opa_inf | opb_inf) & (rmode_r3==2'h1) & 
		!((opa_inf & opb_00) | (opb_inf & opa_00 )) & fpu_op_r3[1]);

assign ine_mul  = (ine_mula | ine_d | inf_fmul | out_d_00 | overflow_d | underflow_d) &
		  !opa_00 & !opb_00 & !(snan_d | qnan_d | inf_d);
assign ine_div  = (ine_d | overflow_d | underflow_d) & !(opb_00 | snan_d | qnan_d | inf_d);
assign ine_fasu = (ine_d | overflow_d | underflow_d) & !(snan_d | qnan_d | inf_d);

always @(posedge  clk)
	ine <= #1	 fpu_op_r3[2] ? ine_d :
			!fpu_op_r3[1] ? ine_fasu :
			 fpu_op_r3[0] ? ine_div  : ine_mul;


assign overflow_fasu = overflow_d & !(snan_d | qnan_d | inf_d);
assign overflow_fmul = !inf_d & (inf_mul_r | inf_mul2 | overflow_d) & !(snan_d | qnan_d);
assign overflow_fdiv = (overflow_d & !(opb_00 | inf_d | snan_d | qnan_d));

always @(posedge clk)
	overflow <= #1	 fpu_op_r3[2] ? 0 :
			!fpu_op_r3[1] ? overflow_fasu :
			 fpu_op_r3[0] ? overflow_fdiv : overflow_fmul;

always @(posedge clk)
	underflow_fmul_r <= #1 underflow_fmul_d;


assign underflow_fmul1 = underflow_fmul_r[0] |
			(underflow_fmul_r[1] & underflow_d ) |
			((opa_dn | opb_dn) & out_d_00 & (prod!=0) & sign) |
			(underflow_fmul_r[2] & ((out_d[30:23]==0) | (out_d[22:0]==0)));

assign underflow_fasu = underflow_d & !(inf_d | snan_d | qnan_d);
assign underflow_fmul = underflow_fmul1 & !(snan_d | qnan_d | inf_mul_r);
assign underflow_fdiv = underflow_fasu & !opb_00;

always @(posedge clk)
	underflow <= #1  fpu_op_r3[2] ? 0 :
			!fpu_op_r3[1] ? underflow_fasu :
			 fpu_op_r3[0] ? underflow_fdiv : underflow_fmul;

always @(posedge clk)
	snan <= #1 snan_d;

// synopsys translate_off
wire		mul_uf_del;
wire		uf2_del, ufb2_del, ufc2_del,  underflow_d_del;
wire		co_del;
wire	[30:0]	out_d_del;
wire		ov_fasu_del, ov_fmul_del;
wire	[2:0]	fop;
wire	[4:0]	ldza_del;
wire	[49:0]	quo_del;

delay1  #0 ud000(clk, underflow_fmul1, mul_uf_del);
delay1  #0 ud001(clk, underflow_fmul_r[0], uf2_del);
delay1  #0 ud002(clk, underflow_fmul_r[1], ufb2_del);
delay1  #0 ud003(clk, underflow_d, underflow_d_del);
delay1  #0 ud004(clk, test.u0.u4.exp_out1_co, co_del);
delay1  #0 ud005(clk, underflow_fmul_r[2], ufc2_del);
delay1 #30 ud006(clk, out_d, out_d_del);

delay1  #0 ud007(clk, overflow_fasu, ov_fasu_del);
delay1  #0 ud008(clk, overflow_fmul, ov_fmul_del);

delay1  #2 ud009(clk, fpu_op_r3, fop);

delay3  #4 ud010(clk, div_opa_ldz_d, ldza_del);

delay1  #49 ud012(clk, quo, quo_del);

always @(test.error_event)
   begin
	#0.2
	$display("muf: %b uf0: %b uf1: %b uf2: %b, tx0: %b, co: %b, out_d: %h (%h %h), ov_fasu: %b, ov_fmul: %b, fop: %h",
			mul_uf_del, uf2_del, ufb2_del, ufc2_del, underflow_d_del, co_del, out_d_del, out_d_del[30:23], out_d_del[22:0],
			ov_fasu_del, ov_fmul_del, fop );
	$display("ldza: %h, quo: %b",
			ldza_del, quo_del);
   end
// synopsys translate_on



// Status Outputs
always @(posedge clk)
	qnan <= #1	fpu_op_r3[2] ? 0 : (
						snan_d | qnan_d | (ind_d & !fasu_op_r2) |
						(opa_00 & opb_00 & fpu_op_r3==3'b011) |
						(((opa_inf & opb_00) | (opb_inf & opa_00 )) & fpu_op_r3==3'b010)
					   );

assign inf_fmul = 	(((inf_mul_r | inf_mul2) & (rmode_r3==2'h0)) | opa_inf | opb_inf) & 
			!((opa_inf & opb_00) | (opb_inf & opa_00 )) &
			fpu_op_r3==3'b010;

always @(posedge clk)
	inf <= #1	fpu_op_r3[2] ? 0 :
			(!(qnan_d | snan_d) & (
						((&out_d[30:23]) & !(|out_d[22:0]) & !(opb_00 & fpu_op_r3==3'b011)) |
						(inf_d & !(ind_d & !fasu_op_r2) & !fpu_op_r3[1]) |
						inf_fmul |
						(!opa_00 & opb_00 & fpu_op_r3==3'b011) |
						(fpu_op_r3==3'b011 & opa_inf & !opb_inf)
					      )
			);

assign output_zero_fasu = out_d_00 & !(inf_d | snan_d | qnan_d);
assign output_zero_fdiv = (div_00 | (out_d_00 & !opb_00)) & !(opa_inf & opb_inf) &
			  !(opa_00 & opb_00) & !(qnan_d | snan_d);
assign output_zero_fmul = (out_d_00 | opa_00 | opb_00) &
			  !(inf_mul_r | inf_mul2 | opa_inf | opb_inf | snan_d | qnan_d) &
			  !(opa_inf & opb_00) & !(opb_inf & opa_00);

always @(posedge clk)
	zero <= #1	fpu_op_r3==3'b101 ?	out_d_00 & !(snan_d | qnan_d):
			fpu_op_r3==3'b011 ?	output_zero_fdiv :
			fpu_op_r3==3'b010 ?	output_zero_fmul :
						output_zero_fasu ;

always @(posedge clk)
	opa_nan_r <= #1 !opa_nan & fpu_op_r2==3'b011;

always @(posedge clk)
	div_by_zero <= #1 opa_nan_r & !opa_00 & !opa_inf & opb_00;

endmodule

module post_norm( clk, fpu_op, opas, sign, rmode, fract_in, exp_in, exp_ovf,
		opa_dn, opb_dn, rem_00, div_opa_ldz, output_zero, out,
		ine, overflow, underflow, f2i_out_sign);
input		clk;
input	[2:0]	fpu_op;
input		opas;
input		sign;
input	[1:0]	rmode;
input	[47:0]	fract_in;
input	[1:0]	exp_ovf;
input	[7:0]	exp_in;
input		opa_dn, opb_dn;
input		rem_00;
input	[4:0]	div_opa_ldz;
input		output_zero;
output	[30:0]	out;
output		ine;
output		overflow, underflow;
output		f2i_out_sign;

////////////////////////////////////////////////////////////////////////
//
// Local Wires and registers
//

wire	[22:0]	fract_out;
wire	[7:0]	exp_out;
wire	[30:0]	out;
wire		exp_out1_co, overflow, underflow;
wire	[22:0]	fract_out_final;
reg	[22:0]	fract_out_rnd;
wire	[8:0]	exp_next_mi;
wire		dn;
wire		exp_rnd_adj;
wire	[7:0]	exp_out_final;
reg	[7:0]	exp_out_rnd;
wire		op_dn = opa_dn | opb_dn;
wire		op_mul = fpu_op[2:0]==3'b010;
wire		op_div = fpu_op[2:0]==3'b011;
wire		op_i2f = fpu_op[2:0]==3'b100;
wire		op_f2i = fpu_op[2:0]==3'b101;
reg	[5:0]	fi_ldz;

wire		g, r, s;
wire		round, round2, round2a, round2_fasu, round2_fmul;
wire	[7:0]	exp_out_rnd0, exp_out_rnd1, exp_out_rnd2, exp_out_rnd2a;
wire	[22:0]	fract_out_rnd0, fract_out_rnd1, fract_out_rnd2, fract_out_rnd2a;
wire		exp_rnd_adj0, exp_rnd_adj2a;
wire		r_sign;
wire		ovf0, ovf1;
wire	[23:0]	fract_out_pl1;
wire	[7:0]	exp_out_pl1, exp_out_mi1;
wire		exp_out_00, exp_out_fe, exp_out_ff, exp_in_00, exp_in_ff;
wire		exp_out_final_ff, fract_out_7fffff;
wire	[24:0]	fract_trunc;
wire	[7:0]	exp_out1;
wire		grs_sel;
wire		fract_out_00, fract_in_00;
wire		shft_co;
wire	[8:0]	exp_in_pl1, exp_in_mi1;
wire	[47:0]	fract_in_shftr;
wire	[47:0]	fract_in_shftl;

wire	[7:0]	exp_div;
wire	[7:0]	shft2;
wire	[7:0]	exp_out1_mi1;
wire		div_dn;
wire		div_nr;
wire		grs_sel_div;

wire		div_inf;
wire	[6:0]	fi_ldz_2a;
wire	[7:0]	fi_ldz_2;
wire	[7:0]	div_shft1, div_shft2, div_shft3, div_shft4;
wire		div_shft1_co;
wire	[8:0]	div_exp1;
wire	[7:0]	div_exp2, div_exp3;
wire		left_right, lr_mul, lr_div;
wire	[7:0]	shift_right, shftr_mul, shftr_div;
wire	[7:0]	shift_left,  shftl_mul, shftl_div;
wire	[7:0]	fasu_shift;
wire	[7:0]	exp_fix_div;

wire	[7:0]	exp_fix_diva, exp_fix_divb;
wire	[5:0]	fi_ldz_mi1;
wire	[5:0]	fi_ldz_mi22;
wire		exp_zero;
wire	[6:0]	ldz_all;
wire	[7:0]	ldz_dif;

wire	[8:0]	div_scht1a;
wire	[7:0]	f2i_shft;
wire	[55:0]	exp_f2i_1;
wire		f2i_zero, f2i_max;
wire	[7:0]	f2i_emin;
wire	[7:0]	conv_shft;
wire	[7:0]	exp_i2f, exp_f2i, conv_exp;
wire		round2_f2i;

////////////////////////////////////////////////////////////////////////
//
// Normalize and Round Logic
//

// ---------------------------------------------------------------------
// Count Leading zeros in fraction

always @(fract_in)
   casex(fract_in)	// synopsys full_case parallel_case
	48'b1???????????????????????????????????????????????: fi_ldz =  1;
	48'b01??????????????????????????????????????????????: fi_ldz =  2;
	48'b001?????????????????????????????????????????????: fi_ldz =  3;
	48'b0001????????????????????????????????????????????: fi_ldz =  4;
	48'b00001???????????????????????????????????????????: fi_ldz =  5;
	48'b000001??????????????????????????????????????????: fi_ldz =  6;
	48'b0000001?????????????????????????????????????????: fi_ldz =  7;
	48'b00000001????????????????????????????????????????: fi_ldz =  8;
	48'b000000001???????????????????????????????????????: fi_ldz =  9;
	48'b0000000001??????????????????????????????????????: fi_ldz =  10;
	48'b00000000001?????????????????????????????????????: fi_ldz =  11;
	48'b000000000001????????????????????????????????????: fi_ldz =  12;
	48'b0000000000001???????????????????????????????????: fi_ldz =  13;
	48'b00000000000001??????????????????????????????????: fi_ldz =  14;
	48'b000000000000001?????????????????????????????????: fi_ldz =  15;
	48'b0000000000000001????????????????????????????????: fi_ldz =  16;
	48'b00000000000000001???????????????????????????????: fi_ldz =  17;
	48'b000000000000000001??????????????????????????????: fi_ldz =  18;
	48'b0000000000000000001?????????????????????????????: fi_ldz =  19;
	48'b00000000000000000001????????????????????????????: fi_ldz =  20;
	48'b000000000000000000001???????????????????????????: fi_ldz =  21;
	48'b0000000000000000000001??????????????????????????: fi_ldz =  22;
	48'b00000000000000000000001?????????????????????????: fi_ldz =  23;
	48'b000000000000000000000001????????????????????????: fi_ldz =  24;
	48'b0000000000000000000000001???????????????????????: fi_ldz =  25;
	48'b00000000000000000000000001??????????????????????: fi_ldz =  26;
	48'b000000000000000000000000001?????????????????????: fi_ldz =  27;
	48'b0000000000000000000000000001????????????????????: fi_ldz =  28;
	48'b00000000000000000000000000001???????????????????: fi_ldz =  29;
	48'b000000000000000000000000000001??????????????????: fi_ldz =  30;
	48'b0000000000000000000000000000001?????????????????: fi_ldz =  31;
	48'b00000000000000000000000000000001????????????????: fi_ldz =  32;
	48'b000000000000000000000000000000001???????????????: fi_ldz =  33;
	48'b0000000000000000000000000000000001??????????????: fi_ldz =  34;
	48'b00000000000000000000000000000000001?????????????: fi_ldz =  35;
	48'b000000000000000000000000000000000001????????????: fi_ldz =  36;
	48'b0000000000000000000000000000000000001???????????: fi_ldz =  37;
	48'b00000000000000000000000000000000000001??????????: fi_ldz =  38;
	48'b000000000000000000000000000000000000001?????????: fi_ldz =  39;
	48'b0000000000000000000000000000000000000001????????: fi_ldz =  40;
	48'b00000000000000000000000000000000000000001???????: fi_ldz =  41;
	48'b000000000000000000000000000000000000000001??????: fi_ldz =  42;
	48'b0000000000000000000000000000000000000000001?????: fi_ldz =  43;
	48'b00000000000000000000000000000000000000000001????: fi_ldz =  44;
	48'b000000000000000000000000000000000000000000001???: fi_ldz =  45;
	48'b0000000000000000000000000000000000000000000001??: fi_ldz =  46;
	48'b00000000000000000000000000000000000000000000001?: fi_ldz =  47;
	48'b00000000000000000000000000000000000000000000000?: fi_ldz =  48;
   endcase


// ---------------------------------------------------------------------
// Normalize

wire		exp_in_80;
wire		rmode_00, rmode_01, rmode_10, rmode_11;

// Misc common signals
assign exp_in_ff        = &exp_in;
assign exp_in_00        = !(|exp_in);
assign exp_in_80	= exp_in[7] & !(|exp_in[6:0]);
assign exp_out_ff       = &exp_out;
assign exp_out_00       = !(|exp_out);
assign exp_out_fe       = &exp_out[7:1] & !exp_out[0];
assign exp_out_final_ff = &exp_out_final;

assign fract_out_7fffff = &fract_out;
assign fract_out_00     = !(|fract_out);
assign fract_in_00      = !(|fract_in);

assign rmode_00 = (rmode==2'b00);
assign rmode_01 = (rmode==2'b01);
assign rmode_10 = (rmode==2'b10);
assign rmode_11 = (rmode==2'b11);

// Fasu Output will be denormalized ...
assign dn = !op_mul & !op_div & (exp_in_00 | (exp_next_mi[8] & !fract_in[47]) );

// ---------------------------------------------------------------------
// Fraction Normalization
parameter	f2i_emax = 8'h9d;

// Incremented fraction for rounding
assign fract_out_pl1 = fract_out + 1;

// Special Signals for f2i
assign f2i_emin = rmode_00 ? 8'h7e : 8'h7f;
assign f2i_zero = (!opas & (exp_in<f2i_emin)) | (opas & (exp_in>f2i_emax)) | (opas & (exp_in<f2i_emin) & (fract_in_00 | !rmode_11));
assign f2i_max = (!opas & (exp_in>f2i_emax)) | (opas & (exp_in<f2i_emin) & !fract_in_00 & rmode_11);

// Claculate various shifting options

assign {shft_co,shftr_mul} = (!exp_ovf[1] & exp_in_00) ? {1'b0, exp_out} : exp_in_mi1 ;
assign {div_shft1_co, div_shft1} = exp_in_00 ? {1'b0, div_opa_ldz} : div_scht1a;

assign div_scht1a = exp_in-div_opa_ldz; // 9 bits - includes carry out
assign div_shft2  = exp_in+2;
assign div_shft3  = div_opa_ldz+exp_in;
assign div_shft4  = div_opa_ldz-exp_in;

assign div_dn    = op_dn & div_shft1_co;
assign div_nr    = op_dn & exp_ovf[1]  & !(|fract_in[46:23]) & (div_shft3>8'h16);

assign f2i_shft  = exp_in-8'h7d;

// Select shifting direction
assign left_right = op_div ? lr_div : op_mul ? lr_mul : 1;

assign lr_div = 	(op_dn & !exp_ovf[1] & exp_ovf[0])     ? 1 :
			(op_dn & exp_ovf[1])                   ? 0 :
			(op_dn & div_shft1_co)                 ? 0 :
			(op_dn & exp_out_00)                   ? 1 :
			(!op_dn & exp_out_00 & !exp_ovf[1])    ? 1 :
			exp_ovf[1]                             ? 0 :
			                                         1;
assign lr_mul = 	(shft_co | (!exp_ovf[1] & exp_in_00) |
			(!exp_ovf[1] & !exp_in_00 & (exp_out1_co | exp_out_00) )) ? 	1 :
			( exp_ovf[1] | exp_in_00 ) ?					0 :
											1;

// Select Left and Right shift value
assign fasu_shift  = (dn | exp_out_00) ? (exp_in_00 ? 8'h2 : exp_in_pl1[7:0]) : {2'h0, fi_ldz};
assign shift_right = op_div ? shftr_div : shftr_mul;

assign conv_shft = op_f2i ? f2i_shft : {2'h0, fi_ldz};

assign shift_left  = op_div ? shftl_div : op_mul ? shftl_mul : (op_f2i | op_i2f) ? conv_shft : fasu_shift;

assign shftl_mul = 	(shft_co |
			(!exp_ovf[1] & exp_in_00) |
			(!exp_ovf[1] & !exp_in_00 & (exp_out1_co | exp_out_00))) ? exp_in_pl1[7:0] : {2'h0, fi_ldz};

assign shftl_div = 	( op_dn & exp_out_00 & !(!exp_ovf[1] & exp_ovf[0]))	? div_shft1[7:0] :
			(!op_dn & exp_out_00 & !exp_ovf[1])    			? exp_in[7:0] :
			                                        		 {2'h0, fi_ldz};
assign shftr_div = 	(op_dn & exp_ovf[1])                   ? div_shft3 :
			(op_dn & div_shft1_co)                 ? div_shft4 :
								 div_shft2;
// Do the actual shifting
assign fract_in_shftr   = (|shift_right[7:6])                      ? 0 : fract_in>>shift_right[5:0];
assign fract_in_shftl   = (|shift_left[7:6] | (f2i_zero & op_f2i)) ? 0 : fract_in<<shift_left[5:0];

// Chose final fraction output
assign {fract_out,fract_trunc} = left_right ? fract_in_shftl : fract_in_shftr;

// ---------------------------------------------------------------------
// Exponent Normalization

assign fi_ldz_mi1    = fi_ldz - 1;
assign fi_ldz_mi22   = fi_ldz - 22;
assign exp_out_pl1   = exp_out + 1;
assign exp_out_mi1   = exp_out - 1;
assign exp_in_pl1    = exp_in  + 1;	// 9 bits - includes carry out
assign exp_in_mi1    = exp_in  - 1;	// 9 bits - includes carry out
assign exp_out1_mi1  = exp_out1 - 1;

assign exp_next_mi  = exp_in_pl1 - fi_ldz_mi1;	// 9 bits - includes carry out

assign exp_fix_diva = exp_in - fi_ldz_mi22;
assign exp_fix_divb = exp_in - fi_ldz_mi1;

assign exp_zero  = (exp_ovf[1] & !exp_ovf[0] & op_mul & (!exp_rnd_adj2a | !rmode[1])) | (op_mul & exp_out1_co);
assign {exp_out1_co, exp_out1} = fract_in[47] ? exp_in_pl1 : exp_next_mi;

assign f2i_out_sign =  !opas ? ((exp_in<f2i_emin) ? 0 : (exp_in>f2i_emax) ? 0 : opas) :
			       ((exp_in<f2i_emin) ? 0 : (exp_in>f2i_emax) ? 1 : opas);

assign exp_i2f   = fract_in_00 ? (opas ? 8'h9e : 0) : (8'h9e-fi_ldz);
assign exp_f2i_1 = {{8{fract_in[47]}}, fract_in }<<f2i_shft;
assign exp_f2i   = f2i_zero ? 0 : f2i_max ? 8'hff : exp_f2i_1[55:48];
assign conv_exp  = op_f2i ? exp_f2i : exp_i2f;

assign exp_out = op_div ? exp_div : (op_f2i | op_i2f) ? conv_exp : exp_zero ? 8'h0 : dn ? {6'h0, fract_in[47:46]} : exp_out1;

assign ldz_all   = div_opa_ldz + fi_ldz;
assign ldz_dif   = fi_ldz_2 - div_opa_ldz;
assign fi_ldz_2a = 6'd23 - fi_ldz;
assign fi_ldz_2  = {fi_ldz_2a[6], fi_ldz_2a[6:0]};

assign div_exp1  = exp_in_mi1 + fi_ldz_2;	// 9 bits - includes carry out

assign div_exp2  = exp_in_pl1 - ldz_all;
assign div_exp3  = exp_in + ldz_dif;

assign exp_div =(opa_dn & opb_dn)					? div_exp3 :
		 opb_dn							? div_exp1[7:0] :
		(opa_dn & !( (exp_in<div_opa_ldz) | (div_exp2>9'hfe) ))	? div_exp2 :
		(opa_dn | (exp_in_00 & !exp_ovf[1]) )			? 0 :
									  exp_out1_mi1;

assign div_inf = opb_dn & !opa_dn & (div_exp1[7:0] < 8'h7f);

// ---------------------------------------------------------------------
// Round

// Extract rounding (GRS) bits
assign grs_sel_div = op_div & (exp_ovf[1] | div_dn | exp_out1_co | exp_out_00);

assign g = grs_sel_div ? fract_out[0]                   : fract_out[0];
assign r = grs_sel_div ? (fract_trunc[24] & !div_nr)    : fract_trunc[24];
assign s = grs_sel_div ? |fract_trunc[24:0]             : (|fract_trunc[23:0] | (fract_trunc[24] & op_div));

// Round to nearest even
assign round = (g & r) | (r & s) ;
assign {exp_rnd_adj0, fract_out_rnd0} = round ? fract_out_pl1 : {1'b0, fract_out};
assign exp_out_rnd0 =  exp_rnd_adj0 ? exp_out_pl1 : exp_out;
assign ovf0 = exp_out_final_ff & !rmode_01 & !op_f2i;

// round to zero
assign fract_out_rnd1 = (exp_out_ff & !op_div & !dn & !op_f2i) ? 23'h7fffff : fract_out;
assign exp_fix_div    = (fi_ldz>22) ? exp_fix_diva : exp_fix_divb;
assign exp_out_rnd1   = (g & r & s & exp_in_ff) ? (op_div ? exp_fix_div : exp_next_mi[7:0]) :
			(exp_out_ff & !op_f2i) ? exp_in : exp_out;
assign ovf1 = exp_out_ff & !dn;

// round to +inf (UP) and -inf (DOWN)
assign r_sign = sign;

assign round2a = !exp_out_fe | !fract_out_7fffff | (exp_out_fe & fract_out_7fffff);
assign round2_fasu = ((r | s) & !r_sign) & (!exp_out[7] | (exp_out[7] & round2a));

assign round2_fmul = !r_sign & 
		(
			(exp_ovf[1] & !fract_in_00 &
				( ((!exp_out1_co | op_dn) & (r | s | (!rem_00 & op_div) )) | fract_out_00 | (!op_dn & !op_div))
			 ) |
			(
				(r | s | (!rem_00 & op_div)) & (
						(!exp_ovf[1] & (exp_in_80 | !exp_ovf[0])) | op_div |
						( exp_ovf[1] & !exp_ovf[0] & exp_out1_co)
					)
			)
		);

assign round2_f2i = rmode_10 & (( |fract_in[23:0] & !opas & (exp_in<8'h80 )) | (|fract_trunc));
assign round2 = (op_mul | op_div) ? round2_fmul : op_f2i ? round2_f2i : round2_fasu;

assign {exp_rnd_adj2a, fract_out_rnd2a} = round2 ? fract_out_pl1 : {1'b0, fract_out};
assign exp_out_rnd2a  = exp_rnd_adj2a ? ((exp_ovf[1] & op_mul) ? exp_out_mi1 : exp_out_pl1) : exp_out;

assign fract_out_rnd2 = (r_sign & exp_out_ff & !op_div & !dn & !op_f2i) ? 23'h7fffff : fract_out_rnd2a;
assign exp_out_rnd2   = (r_sign & exp_out_ff & !op_f2i) ? 8'hfe      : exp_out_rnd2a;


// Choose rounding mode
always @(rmode or exp_out_rnd0 or exp_out_rnd1 or exp_out_rnd2)
	case(rmode)	// synopsys full_case parallel_case
	   0: exp_out_rnd = exp_out_rnd0;
	   1: exp_out_rnd = exp_out_rnd1;
	 2,3: exp_out_rnd = exp_out_rnd2;
	endcase

always @(rmode or fract_out_rnd0 or fract_out_rnd1 or fract_out_rnd2)
	case(rmode)	// synopsys full_case parallel_case
	   0: fract_out_rnd = fract_out_rnd0;
	   1: fract_out_rnd = fract_out_rnd1;
	 2,3: fract_out_rnd = fract_out_rnd2;
	endcase

// ---------------------------------------------------------------------
// Final Output Mux
// Fix Output for denormalized and special numbers
wire	max_num, inf_out;

assign	max_num =  ( !rmode_00 & (op_mul | op_div ) & (
							  ( exp_ovf[1] &  exp_ovf[0]) |
							  (!exp_ovf[1] & !exp_ovf[0] & exp_in_ff & (fi_ldz_2<24) & (exp_out!=8'hfe) )
							  )
		   ) |

		   ( op_div & (
				   ( rmode_01 & ( div_inf |
							 (exp_out_ff & !exp_ovf[1] ) |
							 (exp_ovf[1] &  exp_ovf[0] )
						)
				   ) |
		
				   ( rmode[1] & !exp_ovf[1] & (
								   ( exp_ovf[0] & exp_in_ff & r_sign & fract_in[47]
								   ) |
						
								   (  r_sign & (
										(fract_in[47] & div_inf) |
										(exp_in[7] & !exp_out_rnd[7] & !exp_in_80 & exp_out!=8'h7f ) |
										(exp_in[7] &  exp_out_rnd[7] & r_sign & exp_out_ff & op_dn &
											 div_exp1>9'h0fe )
										)
								   ) |

								   ( exp_in_00 & r_sign & (
												div_inf |
												(r_sign & exp_out_ff & fi_ldz_2<24)
											  )
								   )
							       )
				  )
			    )
		   );


assign inf_out = (rmode[1] & (op_mul | op_div) & !r_sign & (	(exp_in_ff & !op_div) |
								(exp_ovf[1] & exp_ovf[0] & (exp_in_00 | exp_in[7]) ) 
							   )
		) | (div_inf & op_div & (
				 rmode_00 |
				(rmode[1] & !exp_in_ff & !exp_ovf[1] & !exp_ovf[0] & !r_sign ) |
				(rmode[1] & !exp_ovf[1] & exp_ovf[0] & exp_in_00 & !r_sign)
				)
		) | (op_div & rmode[1] & exp_in_ff & op_dn & !r_sign & (fi_ldz_2 < 24)  & (exp_out_rnd!=8'hfe) );

assign fract_out_final =	(inf_out | ovf0 | output_zero ) ? 23'h0 :
				(max_num | (f2i_max & op_f2i) ) ? 23'h7fffff :
				fract_out_rnd;

assign exp_out_final =	((op_div & exp_ovf[1] & !exp_ovf[0]) | output_zero ) ? 8'h00 :
			((op_div & exp_ovf[1] &  exp_ovf[0] & rmode_00) | inf_out | (f2i_max & op_f2i) ) ? 8'hff :
			max_num ? 8'hfe :
			exp_out_rnd;


// ---------------------------------------------------------------------
// Pack Result

assign out = {exp_out_final, fract_out_final};

// ---------------------------------------------------------------------
// Exceptions
wire		underflow_fmul;
wire		overflow_fdiv;
wire		undeflow_div;

wire		z =	shft_co | ( exp_ovf[1] |  exp_in_00) |
			(!exp_ovf[1] & !exp_in_00 & (exp_out1_co | exp_out_00));

assign underflow_fmul = ( (|fract_trunc) & z & !exp_in_ff ) |
			(fract_out_00 & !fract_in_00 & exp_ovf[1]);

assign undeflow_div =	!(exp_ovf[1] &  exp_ovf[0] & rmode_00) & !inf_out & !max_num & exp_out_final!=8'hff & (

			((|fract_trunc) & !opb_dn & (
							( op_dn & !exp_ovf[1] & exp_ovf[0])	|
							( op_dn &  exp_ovf[1])			|
							( op_dn &  div_shft1_co)		| 
							  exp_out_00				|
							  exp_ovf[1]
						  )

			) |

			( exp_ovf[1] & !exp_ovf[0] & (
							(  op_dn & exp_in>8'h16 & fi_ldz<23) |
							(  op_dn & exp_in<23 & fi_ldz<23 & !rem_00) |
							( !op_dn & (exp_in[7]==exp_div[7]) & !rem_00) |
							( !op_dn & exp_in_00 & (exp_div[7:1]==7'h7f) ) |
							( !op_dn & exp_in<8'h7f & exp_in>8'h20 )
							)
			) |

			(!exp_ovf[1] & !exp_ovf[0] & (
							( op_dn & fi_ldz<23 & exp_out_00) |
							( exp_in_00 & !rem_00) |
							( !op_dn & ldz_all<23 & exp_in==1 & exp_out_00 & !rem_00)
							)
			)

			);

assign underflow = op_div ? undeflow_div : op_mul ? underflow_fmul : (!fract_in[47] & exp_out1_co) & !dn;

assign overflow_fdiv =	inf_out |
			(!rmode_00 & max_num) |
			(exp_in[7] & op_dn & exp_out_ff) |
			(exp_ovf[0] & (exp_ovf[1] | exp_out_ff) );

assign overflow  = op_div ? overflow_fdiv : (ovf0 | ovf1);

wire		f2i_ine;

assign f2i_ine =	(f2i_zero & !fract_in_00 & !opas) |
			(|fract_trunc) |
			(f2i_zero & (exp_in<8'h80) & opas & !fract_in_00) |
			(f2i_max & rmode_11 & (exp_in<8'h80));



assign ine =	op_f2i ? f2i_ine :
		op_i2f ? (|fract_trunc) :
		((r & !dn) | (s & !dn) | max_num | (op_div & !rem_00));

// ---------------------------------------------------------------------
// Debugging Stuff

// synopsys translate_off

wire	[26:0]	fracta_del, fractb_del;
wire	[2:0]	grs_del;
wire		dn_del;
wire	[7:0]	exp_in_del;
wire	[7:0]	exp_out_del;
wire	[22:0]	fract_out_del;
wire	[47:0]	fract_in_del;
wire		overflow_del;
wire	[1:0]	exp_ovf_del;
wire	[22:0]	fract_out_x_del, fract_out_rnd2a_del;
wire	[24:0]	trunc_xx_del;
wire		exp_rnd_adj2a_del;
wire	[22:0]	fract_dn_del;
wire	[4:0]	div_opa_ldz_del;
wire	[23:0]	fracta_div_del;
wire	[23:0]	fractb_div_del;
wire		div_inf_del;
wire	[7:0]	fi_ldz_2_del;
wire		inf_out_del, max_out_del;
wire	[5:0]	fi_ldz_del;
wire		rx_del;
wire		ez_del;
wire		lr;
wire	[7:0]	shr, shl, exp_div_del;

delay2 #26 ud000(clk, test.u0.fracta, fracta_del);
delay2 #26 ud001(clk, test.u0.fractb, fractb_del);
delay1  #2 ud002(clk, {g,r,s}, grs_del);
delay1  #0 ud004(clk, dn, dn_del);
delay1  #7 ud005(clk, exp_in, exp_in_del);
delay1  #7 ud007(clk, exp_out_rnd, exp_out_del);
delay1 #47 ud009(clk, fract_in, fract_in_del);
delay1  #0 ud010(clk, overflow, overflow_del);
delay1  #1 ud011(clk, exp_ovf, exp_ovf_del);
delay1 #22 ud014(clk, fract_out, fract_out_x_del);
delay1 #24 ud015(clk, fract_trunc, trunc_xx_del);
delay1 	#0 ud017(clk, exp_rnd_adj2a, exp_rnd_adj2a_del);
delay1  #4 ud019(clk, div_opa_ldz, div_opa_ldz_del);
delay3 #23 ud020(clk, test.u0.fdiv_opa[49:26],	fracta_div_del);
delay3 #23 ud021(clk, test.u0.fractb_mul,	fractb_div_del);
delay1 	#0 ud023(clk, div_inf, div_inf_del);
delay1  #7 ud024(clk, fi_ldz_2, fi_ldz_2_del);
delay1 	#0 ud025(clk, inf_out, inf_out_del);
delay1 	#0 ud026(clk, max_num, max_num_del);
delay1 	#5 ud027(clk, fi_ldz, fi_ldz_del);
delay1  #0 ud028(clk, rem_00, rx_del);

delay1  #0 ud029(clk, left_right, lr);
delay1  #7 ud030(clk, shift_right, shr);
delay1  #7 ud031(clk, shift_left, shl);
delay1 #22 ud032(clk, fract_out_rnd2a, fract_out_rnd2a_del);

delay1  #7 ud033(clk, exp_div, exp_div_del);

always @(test.error_event)
   begin

	$display("\n----------------------------------------------");

	$display("ERROR: GRS: %b exp_ovf: %b dn: %h exp_in: %h exp_out: %h, exp_rnd_adj2a: %b",
			grs_del, exp_ovf_del, dn_del, exp_in_del, exp_out_del, exp_rnd_adj2a_del);

	$display("      div_opa: %b, div_opb: %b, rem_00: %b, exp_div: %h",
			fracta_div_del, fractb_div_del, rx_del, exp_div_del);

	$display("      lr: %b, shl: %h, shr: %h",
			lr, shl, shr);


	$display("       overflow: %b, fract_in=%b  fa:%h fb:%h",
			overflow_del, fract_in_del, fracta_del, fractb_del);

	$display("       div_opa_ldz: %h, div_inf: %b, inf_out: %b, max_num: %b, fi_ldz: %h, fi_ldz_2: %h",
			div_opa_ldz_del, div_inf_del, inf_out_del, max_num_del, fi_ldz_del, fi_ldz_2_del);

	$display("       fract_out_x: %b, fract_out_rnd2a_del: %h, fract_trunc: %b\n",
			fract_out_x_del, fract_out_rnd2a_del, trunc_xx_del);
   end


// synopsys translate_on

endmodule

// synopsys translate_off

module delay1(clk, in, out);
parameter	N = 1;
input	[N:0]	in;
output	[N:0]	out;
input		clk;

reg	[N:0]	out;

always @(posedge clk)
	out <= #1 in;

endmodule


module delay2(clk, in, out);
parameter	N = 1;
input	[N:0]	in;
output	[N:0]	out;
input		clk;

reg	[N:0]	out, r1;

always @(posedge clk)
	r1 <= #1 in;

always @(posedge clk)
	out <= #1 r1;

endmodule

module delay3(clk, in, out);
parameter	N = 1;
input	[N:0]	in;
output	[N:0]	out;
input		clk;

reg	[N:0]	out, r1, r2;

always @(posedge clk)
	r1 <= #1 in;

always @(posedge clk)
	r2 <= #1 r1;

always @(posedge clk)
	out <= #1 r2;

endmodule

// synopsys translate_on

module pre_norm(clk, rmode, add, opa, opb, opa_nan, opb_nan, fracta_out,
		fractb_out, exp_dn_out, sign, nan_sign, result_zero_sign,
		fasu_op);
input		clk;
input	[1:0]	rmode;
input		add;
input	[31:0]	opa, opb;
input		opa_nan, opb_nan;
output	[26:0]	fracta_out, fractb_out;
output	[7:0]	exp_dn_out;
output		sign;
output		nan_sign, result_zero_sign;
output		fasu_op;			// Operation Output

////////////////////////////////////////////////////////////////////////
//
// Local Wires and registers
//

wire		signa, signb;		// alias to opX sign
wire	[7:0]	expa, expb;		// alias to opX exponent
wire	[22:0]	fracta, fractb;		// alias to opX fraction
wire		expa_lt_expb;		// expa is larger than expb indicator
wire		fractb_lt_fracta;	// fractb is larger than fracta indicator
reg	[7:0]	exp_dn_out;		// de normalized exponent output
wire	[7:0]	exp_small, exp_large;
wire	[7:0]	exp_diff;		// Numeric difference of the two exponents
wire	[22:0]	adj_op;			// Fraction adjustment: input
wire	[26:0]	adj_op_tmp;
wire	[26:0]	adj_op_out;		// Fraction adjustment: output
wire	[26:0]	fracta_n, fractb_n;	// Fraction selection after normalizing
wire	[26:0]	fracta_s, fractb_s;	// Fraction Sorting out
reg	[26:0]	fracta_out, fractb_out;	// Fraction Output
reg		sign, sign_d;		// Sign Output
reg		add_d;			// operation (add/sub)
reg		fasu_op;		// operation (add/sub) register
wire		expa_dn, expb_dn;
reg		sticky;
reg		result_zero_sign;
reg		add_r, signa_r, signb_r;
wire	[4:0]	exp_diff_sft;
wire		exp_lt_27;
wire		op_dn;
wire	[26:0]	adj_op_out_sft;
reg		fracta_lt_fractb, fracta_eq_fractb;
wire		nan_sign1;
reg		nan_sign;

////////////////////////////////////////////////////////////////////////
//
// Aliases
//

assign  signa = opa[31];
assign  signb = opb[31];
assign   expa = opa[30:23];
assign   expb = opb[30:23];
assign fracta = opa[22:0];
assign fractb = opb[22:0];

////////////////////////////////////////////////////////////////////////
//
// Pre-Normalize exponents (and fractions)
//

assign expa_lt_expb = expa > expb;		// expa is larger than expb

// ---------------------------------------------------------------------
// Normalize

assign expa_dn = !(|expa);			// opa denormalized
assign expb_dn = !(|expb);			// opb denormalized

// ---------------------------------------------------------------------
// Calculate the difference between the smaller and larger exponent

wire	[7:0]	exp_diff1, exp_diff1a, exp_diff2;

assign exp_small  = expa_lt_expb ? expb : expa;
assign exp_large  = expa_lt_expb ? expa : expb;
assign exp_diff1  = exp_large - exp_small;
assign exp_diff1a = exp_diff1-1;
assign exp_diff2  = (expa_dn | expb_dn) ? exp_diff1a : exp_diff1;
assign  exp_diff  = (expa_dn & expb_dn) ? 8'h0 : exp_diff2;

always @(posedge clk)	// If numbers are equal we should return zero
	exp_dn_out <= #1 (!add_d & expa==expb & fracta==fractb) ? 8'h0 : exp_large;

// ---------------------------------------------------------------------
// Adjust the smaller fraction


assign op_dn	  = expa_lt_expb ? expb_dn : expa_dn;
assign adj_op     = expa_lt_expb ? fractb : fracta;
assign adj_op_tmp = { ~op_dn, adj_op, 3'b0 };	// recover hidden bit (op_dn) 

// adj_op_out is 27 bits wide, so can only be shifted 27 bits to the right
assign exp_lt_27	= exp_diff  > 8'd27;
assign exp_diff_sft	= exp_lt_27 ? 5'd27 : exp_diff[4:0];
assign adj_op_out_sft	= adj_op_tmp >> exp_diff_sft;
assign adj_op_out	= {adj_op_out_sft[26:1], adj_op_out_sft[0] | sticky };

// ---------------------------------------------------------------------
// Get truncated portion (sticky bit)

always @(exp_diff_sft or adj_op_tmp)
   case(exp_diff_sft)		// synopsys full_case parallel_case
	00: sticky = 1'h0;
	01: sticky =  adj_op_tmp[0]; 
	02: sticky = |adj_op_tmp[01:0];
	03: sticky = |adj_op_tmp[02:0];
	04: sticky = |adj_op_tmp[03:0];
	05: sticky = |adj_op_tmp[04:0];
	06: sticky = |adj_op_tmp[05:0];
	07: sticky = |adj_op_tmp[06:0];
	08: sticky = |adj_op_tmp[07:0];
	09: sticky = |adj_op_tmp[08:0];
	10: sticky = |adj_op_tmp[09:0];
	11: sticky = |adj_op_tmp[10:0];
	12: sticky = |adj_op_tmp[11:0];
	13: sticky = |adj_op_tmp[12:0];
	14: sticky = |adj_op_tmp[13:0];
	15: sticky = |adj_op_tmp[14:0];
	16: sticky = |adj_op_tmp[15:0];
	17: sticky = |adj_op_tmp[16:0];
	18: sticky = |adj_op_tmp[17:0];
	19: sticky = |adj_op_tmp[18:0];
	20: sticky = |adj_op_tmp[19:0];
	21: sticky = |adj_op_tmp[20:0];
	22: sticky = |adj_op_tmp[21:0];
	23: sticky = |adj_op_tmp[22:0];
	24: sticky = |adj_op_tmp[23:0];
	25: sticky = |adj_op_tmp[24:0];
	26: sticky = |adj_op_tmp[25:0];
	27: sticky = |adj_op_tmp[26:0];
   endcase

// ---------------------------------------------------------------------
// Select operands for add/sub (recover hidden bit)

assign fracta_n = expa_lt_expb ? {~expa_dn, fracta, 3'b0} : adj_op_out;
assign fractb_n = expa_lt_expb ? adj_op_out : {~expb_dn, fractb, 3'b0};

// ---------------------------------------------------------------------
// Sort operands (for sub only)

assign fractb_lt_fracta = fractb_n > fracta_n;	// fractb is larger than fracta
assign fracta_s = fractb_lt_fracta ? fractb_n : fracta_n;
assign fractb_s = fractb_lt_fracta ? fracta_n : fractb_n;

always @(posedge clk)
	fracta_out <= #1 fracta_s;

always @(posedge clk)
	fractb_out <= #1 fractb_s;

// ---------------------------------------------------------------------
// Determine sign for the output

// sign: 0=Positive Number; 1=Negative Number
always @(signa or signb or add or fractb_lt_fracta)
   case({signa, signb, add})		// synopsys full_case parallel_case

   	// Add
	3'b0_0_1: sign_d = 0;
	3'b0_1_1: sign_d = fractb_lt_fracta;
	3'b1_0_1: sign_d = !fractb_lt_fracta;
	3'b1_1_1: sign_d = 1;

	// Sub
	3'b0_0_0: sign_d = fractb_lt_fracta;
	3'b0_1_0: sign_d = 0;
	3'b1_0_0: sign_d = 1;
	3'b1_1_0: sign_d = !fractb_lt_fracta;
   endcase

always @(posedge clk)
	sign <= #1 sign_d;

// Fix sign for ZERO result
always @(posedge clk)
	signa_r <= #1 signa;

always @(posedge clk)
	signb_r <= #1 signb;

always @(posedge clk)
	add_r <= #1 add;

always @(posedge clk)
	result_zero_sign <= #1	( add_r &  signa_r &  signb_r) |
				(!add_r &  signa_r & !signb_r) |
				( add_r & (signa_r |  signb_r) & (rmode==3)) |
				(!add_r & (signa_r == signb_r) & (rmode==3));

// Fix sign for NAN result
always @(posedge clk)
	fracta_lt_fractb <= #1 fracta < fractb;

always @(posedge clk)
	fracta_eq_fractb <= #1 fracta == fractb;

assign nan_sign1 = fracta_eq_fractb ? (signa_r & signb_r) : fracta_lt_fractb ? signb_r : signa_r;

always @(posedge clk)
	nan_sign <= #1 (opa_nan & opb_nan) ? nan_sign1 : opb_nan ? signb_r : signa_r;

////////////////////////////////////////////////////////////////////////
//
// Decode Add/Sub operation
//

// add: 1=Add; 0=Subtract
always @(signa or signb or add)
   case({signa, signb, add})		// synopsys full_case parallel_case
   
   	// Add
	3'b0_0_1: add_d = 1;
	3'b0_1_1: add_d = 0;
	3'b1_0_1: add_d = 0;
	3'b1_1_1: add_d = 1;
	
	// Sub
	3'b0_0_0: add_d = 0;
	3'b0_1_0: add_d = 1;
	3'b1_0_0: add_d = 1;
	3'b1_1_0: add_d = 0;
   endcase

always @(posedge clk)
	fasu_op <= #1 add_d;

endmodule

module pre_norm_fmul(clk, fpu_op, opa, opb, fracta, fractb, exp_out, sign,
		sign_exe, inf, exp_ovf, underflow);
input		clk;
input	[2:0]	fpu_op;
input	[31:0]	opa, opb;
output	[23:0]	fracta, fractb;
output	[7:0]	exp_out;
output		sign, sign_exe;
output		inf;
output	[1:0]	exp_ovf;
output	[2:0]	underflow;

////////////////////////////////////////////////////////////////////////
//
// Local Wires and registers
//

reg	[7:0]	exp_out;
wire		signa, signb;
reg		sign, sign_d;
reg		sign_exe;
reg		inf;
wire	[1:0]	exp_ovf_d;
reg	[1:0]	exp_ovf;
wire	[7:0]	expa, expb;
wire	[7:0]	exp_tmp1, exp_tmp2;
wire		co1, co2;
wire		expa_dn, expb_dn;
wire	[7:0]	exp_out_a;
wire		opa_00, opb_00, fracta_00, fractb_00;
wire	[7:0]	exp_tmp3, exp_tmp4, exp_tmp5;
wire	[2:0]	underflow_d;
reg	[2:0]	underflow;
wire		op_div = (fpu_op == 3'b011);
wire	[7:0]	exp_out_mul, exp_out_div;

////////////////////////////////////////////////////////////////////////
//
// Aliases
//

assign  signa = opa[31];
assign  signb = opb[31];
assign   expa = opa[30:23];
assign   expb = opb[30:23];

////////////////////////////////////////////////////////////////////////
//
// Calculate Exponenet
//

assign expa_dn   = !(|expa);
assign expb_dn   = !(|expb);
assign opa_00    = !(|opa[30:0]);
assign opb_00    = !(|opb[30:0]);
assign fracta_00 = !(|opa[22:0]);
assign fractb_00 = !(|opb[22:0]);

assign fracta = {!expa_dn,opa[22:0]};	// Recover hidden bit
assign fractb = {!expb_dn,opb[22:0]};	// Recover hidden bit

assign {co1,exp_tmp1} = op_div ? (expa - expb)            : (expa + expb);
assign {co2,exp_tmp2} = op_div ? ({co1,exp_tmp1} + 8'h7f) : ({co1,exp_tmp1} - 8'h7f);

assign exp_tmp3 = exp_tmp2 + 1;
assign exp_tmp4 = 8'h7f - exp_tmp1;
assign exp_tmp5 = op_div ? (exp_tmp4+1) : (exp_tmp4-1);


always@(posedge clk)
	exp_out <= #1 op_div ? exp_out_div : exp_out_mul;

assign exp_out_div = (expa_dn | expb_dn) ? (co2 ? exp_tmp5 : exp_tmp3 ) : co2 ? exp_tmp4 : exp_tmp2;
assign exp_out_mul = exp_ovf_d[1] ? exp_out_a : (expa_dn | expb_dn) ? exp_tmp3 : exp_tmp2;
assign exp_out_a   = (expa_dn | expb_dn) ? exp_tmp5 : exp_tmp4;
assign exp_ovf_d[0] = op_div ? (expa[7] & !expb[7]) : (co2 & expa[7] & expb[7]);
assign exp_ovf_d[1] = op_div ? co2                  : ((!expa[7] & !expb[7] & exp_tmp2[7]) | co2);

always @(posedge clk)
	exp_ovf <= #1 exp_ovf_d;

assign underflow_d[0] =	(exp_tmp1 < 8'h7f) & !co1 & !(opa_00 | opb_00 | expa_dn | expb_dn);
assign underflow_d[1] =	((expa[7] | expb[7]) & !opa_00 & !opb_00) |
			 (expa_dn & !fracta_00) | (expb_dn & !fractb_00);
assign underflow_d[2] =	 !opa_00 & !opb_00 & (exp_tmp1 == 8'h7f);

always @(posedge clk)
	underflow <= #1 underflow_d;

always @(posedge clk)
	inf <= #1 op_div ? (expb_dn & !expa[7]) : ({co1,exp_tmp1} > 9'h17e) ;


////////////////////////////////////////////////////////////////////////
//
// Determine sign for the output
//

// sign: 0=Posetive Number; 1=Negative Number
always @(signa or signb)
   case({signa, signb})		// synopsys full_case parallel_case
	2'b0_0: sign_d = 0;
	2'b0_1: sign_d = 1;
	2'b1_0: sign_d = 1;
	2'b1_1: sign_d = 0;
   endcase

always @(posedge clk)
	sign <= #1 sign_d;

always @(posedge clk)
	sign_exe <= #1 signa & signb;

endmodule

module add_sub27(add, opa, opb, sum, co);
input		add;
input	[26:0]	opa, opb;
output	[26:0]	sum;
output		co;



assign {co, sum} = add ? (opa + opb) : (opa - opb);

endmodule

////////////////////////////////////////////////////////////////////////
//
// Multiply
//

module mul_r2(clk, opa, opb, prod);
input		clk;
input	[23:0]	opa, opb;
output	[47:0]	prod;

reg	[47:0]	prod1, prod;

always @(posedge clk)
	prod1 <= #1 opa * opb;

always @(posedge clk)
	prod <= #1 prod1;

endmodule

////////////////////////////////////////////////////////////////////////
//
// Divide
//

module div_r2(clk, opa, opb, quo, rem);
input		clk;
input	[49:0]	opa;
input	[23:0]	opb;
output	[49:0]	quo, rem;

reg	[49:0]	quo, rem, quo1, remainder;

always @(posedge clk)
	quo1 <= #1 opa / opb;

always @(posedge clk)
	quo <= #1 quo1;

always @(posedge clk)
	remainder <= #1 opa % opb;

always @(posedge clk)
	rem <= #1 remainder;

endmodule


