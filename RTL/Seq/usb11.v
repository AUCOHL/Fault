/////////////////////////////////////////////////////////////////////
////                                                             ////
////  USB 1.1 PHY                                                ////
////                                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/cores/usb_phy/   ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000-2002 Rudolf Usselmann                    ////
////                         www.asics.ws                        ////
////                         rudi@asics.ws                       ////
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

//  CVS Log
//
//  $Id: usb_phy.v,v 1.4 2003-10-21 05:58:40 rudi Exp $
//
//  $Date: 2003-10-21 05:58:40 $
//  $Revision: 1.4 $
//  $Author: rudi $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.3  2003/10/19 17:40:13  rudi
//               - Made core more robust against line noise
//               - Added Error Checking and Reporting
//               (See README.txt for more info)
//
//               Revision 1.2  2002/09/16 16:06:37  rudi
//               Changed top level name to be consistent ...
//
//               Revision 1.1.1.1  2002/09/16 14:26:59  rudi
//               Created Directory Structure
//
//
//
//
//
//
//
//

//`include "timescale.v"

module usb_phy(clk, rst, phy_tx_mode, usb_rst,
	
		// Transciever Interface
		txdp, txdn, txoe,	
		rxd, rxdp, rxdn,

		// UTMI Interface
		DataOut_i, TxValid_i, TxReady_o, RxValid_o,
		RxActive_o, RxError_o, DataIn_o, LineState_o
		);

input		clk;
input		rst;
input		phy_tx_mode;
output		usb_rst;
output		txdp, txdn, txoe;
input		rxd, rxdp, rxdn;
input	[7:0]	DataOut_i;
input		TxValid_i;
output		TxReady_o;
output	[7:0]	DataIn_o;
output		RxValid_o;
output		RxActive_o;
output		RxError_o;
output	[1:0]	LineState_o;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

reg	[4:0]	rst_cnt;
reg		usb_rst;
wire		fs_ce;
wire		rst;

///////////////////////////////////////////////////////////////////
//
// Misc Logic
//

///////////////////////////////////////////////////////////////////
//
// TX Phy
//

usb_tx_phy i_tx_phy(
	.clk(		clk		),
	.rst(		rst		),
	.fs_ce(		fs_ce		),
	.phy_mode(	phy_tx_mode	),

	// Transciever Interface
	.txdp(		txdp		),
	.txdn(		txdn		),
	.txoe(		txoe		),

	// UTMI Interface
	.DataOut_i(	DataOut_i	),
	.TxValid_i(	TxValid_i	),
	.TxReady_o(	TxReady_o	)
	);

///////////////////////////////////////////////////////////////////
//
// RX Phy and DPLL
//

usb_rx_phy i_rx_phy(
	.clk(		clk		),
	.rst(		rst		),
	.fs_ce(		fs_ce		),

	// Transciever Interface
	.rxd(		rxd		),
	.rxdp(		rxdp		),
	.rxdn(		rxdn		),

	// UTMI Interface
	.DataIn_o(	DataIn_o	),
	.RxValid_o(	RxValid_o	),
	.RxActive_o(	RxActive_o	),
	.RxError_o(	RxError_o	),
	.RxEn_i(	txoe		),
	.LineState(	LineState_o	)
	);

///////////////////////////////////////////////////////////////////
//
// Generate an USB Reset is we see SE0 for at least 2.5uS
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)			rst_cnt <= 5'h0;
	else
	if(LineState_o != 2'h0)		rst_cnt <= 5'h0;
	else	
	if(!usb_rst && fs_ce)		rst_cnt <= rst_cnt + 5'h1;

always @(posedge clk)
	usb_rst <= (rst_cnt == 5'h1f);

endmodule
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  USB 1.1 PHY                                                ////
////  RX & DPLL                                                  ////
////                                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/cores/usb_phy/   ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000-2002 Rudolf Usselmann                    ////
////                         www.asics.ws                        ////
////                         rudi@asics.ws                       ////
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

//  CVS Log
//
//  $Id: usb_rx_phy.v,v 1.5 2004-10-19 09:29:07 rudi Exp $
//
//  $Date: 2004-10-19 09:29:07 $
//  $Revision: 1.5 $
//  $Author: rudi $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.4  2003/12/02 04:56:00  rudi
//               Fixed a bug reported by Karl C. Posch from Graz University of Technology. Thanks Karl !
//
//               Revision 1.3  2003/10/19 18:07:45  rudi
//               - Fixed Sync Error to be only checked/generated during the sync phase
//
//               Revision 1.2  2003/10/19 17:40:13  rudi
//               - Made core more robust against line noise
//               - Added Error Checking and Reporting
//               (See README.txt for more info)
//
//               Revision 1.1.1.1  2002/09/16 14:27:01  rudi
//               Created Directory Structure
//
//
//
//
//
//
//
//

//`include "timescale.v"

module usb_rx_phy(	clk, rst, fs_ce,
	
			// Transciever Interface
			rxd, rxdp, rxdn,

			// UTMI Interface
			RxValid_o, RxActive_o, RxError_o, DataIn_o,
			RxEn_i, LineState);

input		clk;
input		rst;
output		fs_ce;
input		rxd, rxdp, rxdn;
output	[7:0]	DataIn_o;
output		RxValid_o;
output		RxActive_o;
output		RxError_o;
input		RxEn_i;
output	[1:0]	LineState;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

reg		rxd_s0, rxd_s1,  rxd_s;
reg		rxdp_s0, rxdp_s1, rxdp_s, rxdp_s_r;
reg		rxdn_s0, rxdn_s1, rxdn_s, rxdn_s_r;
reg		synced_d;
wire		k, j, se0;
reg		rxd_r;
reg		rx_en;
reg		rx_active;
reg	[2:0]	bit_cnt;
reg		rx_valid1, rx_valid;
reg		shift_en;
reg		sd_r;
reg		sd_nrzi;
reg	[7:0]	hold_reg;
wire		drop_bit;	// Indicates a stuffed bit
reg	[2:0]	one_cnt;

reg	[1:0]	dpll_state, dpll_next_state;
reg		fs_ce_d;
reg		fs_ce;
wire		change;
wire		lock_en;
reg	[2:0]	fs_state, fs_next_state;
reg		rx_valid_r;
reg		sync_err_d, sync_err;
reg		bit_stuff_err;
reg		se0_r, byte_err;
reg		se0_s;

///////////////////////////////////////////////////////////////////
//
// Misc Logic
//

assign RxActive_o = rx_active;
assign RxValid_o = rx_valid;
assign RxError_o = sync_err | bit_stuff_err | byte_err;
assign DataIn_o = hold_reg;
assign LineState = {rxdn_s1, rxdp_s1};

always @(posedge clk)	rx_en <= RxEn_i;
always @(posedge clk)	sync_err <= !rx_active & sync_err_d;

///////////////////////////////////////////////////////////////////
//
// Synchronize Inputs
//

// First synchronize to the local system clock to
// avoid metastability outside the sync block (*_s0).
// Then make sure we see the signal for at least two
// clock cycles stable to avoid glitches and noise

always @(posedge clk)	rxd_s0  <= rxd;
always @(posedge clk)	rxd_s1  <= rxd_s0;
always @(posedge clk)							// Avoid detecting Line Glitches and noise
	if(rxd_s0 && rxd_s1)	rxd_s <= 1'b1;
	else
	if(!rxd_s0 && !rxd_s1)	rxd_s <= 1'b0;

always @(posedge clk)	rxdp_s0  <= rxdp;
always @(posedge clk)	rxdp_s1  <= rxdp_s0;
always @(posedge clk)	rxdp_s_r <= rxdp_s0 & rxdp_s1;
always @(posedge clk)	rxdp_s   <= (rxdp_s0 & rxdp_s1) | rxdp_s_r;	// Avoid detecting Line Glitches and noise

always @(posedge clk)	rxdn_s0  <= rxdn;
always @(posedge clk)	rxdn_s1  <= rxdn_s0;
always @(posedge clk)	rxdn_s_r <= rxdn_s0 & rxdn_s1;
always @(posedge clk)	rxdn_s   <= (rxdn_s0 & rxdn_s1) | rxdn_s_r;	// Avoid detecting Line Glitches and noise

assign k = !rxdp_s &  rxdn_s;
assign j =  rxdp_s & !rxdn_s;
assign se0 = !rxdp_s & !rxdn_s;

always @(posedge clk)	if(fs_ce)	se0_s <= se0;

///////////////////////////////////////////////////////////////////
//
// DPLL
//

// This design uses a clock enable to do 12Mhz timing and not a
// real 12Mhz clock. Everything always runs at 48Mhz. We want to
// make sure however, that the clock enable is always exactly in
// the middle between two virtual 12Mhz rising edges.
// We monitor rxdp and rxdn for any changes and do the appropiate
// adjustments.
// In addition to the locking done in the dpll FSM, we adjust the
// final latch enable to compensate for various sync registers ...

// Allow lockinf only when we are receiving
assign	lock_en = rx_en;

always @(posedge clk)	rxd_r <= rxd_s;

// Edge detector
assign change = rxd_r != rxd_s;

// DPLL FSM
`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	dpll_state <= 2'h1;
	else		dpll_state <= dpll_next_state;

always @(dpll_state or lock_en or change)
   begin
	fs_ce_d = 1'b0;
	case(dpll_state)	// synopsys full_case parallel_case
	   2'h0:
		if(lock_en && change)	dpll_next_state = 2'h0;
		else			dpll_next_state = 2'h1;
	   2'h1:begin
		fs_ce_d = 1'b1;
		if(lock_en && change)	dpll_next_state = 2'h3;
		else			dpll_next_state = 2'h2;
		end
	   2'h2:
		if(lock_en && change)	dpll_next_state = 2'h0;
		else			dpll_next_state = 2'h3;
	   2'h3:
		if(lock_en && change)	dpll_next_state = 2'h0;
		else			dpll_next_state = 2'h0;
	endcase
   end

// Compensate for sync registers at the input - allign full speed
// clock enable to be in the middle between two bit changes ...
reg	fs_ce_r1, fs_ce_r2;

always @(posedge clk)	fs_ce_r1 <= fs_ce_d;
always @(posedge clk)	fs_ce_r2 <= fs_ce_r1;
always @(posedge clk)	fs_ce <= fs_ce_r2;


///////////////////////////////////////////////////////////////////
//
// Find Sync Pattern FSM
//

parameter	FS_IDLE	= 3'h0,
		K1	= 3'h1,
		J1	= 3'h2,
		K2	= 3'h3,
		J2	= 3'h4,
		K3	= 3'h5,
		J3	= 3'h6,
		K4	= 3'h7;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	fs_state <= FS_IDLE;
	else		fs_state <= fs_next_state;

always @(fs_state or fs_ce or k or j or rx_en or rx_active or se0 or se0_s)
   begin
	synced_d = 1'b0;
	sync_err_d = 1'b0;
	fs_next_state = fs_state;
	if(fs_ce && !rx_active && !se0 && !se0_s)
	   case(fs_state)	// synopsys full_case parallel_case
		FS_IDLE:
		     begin
			if(k && rx_en)	fs_next_state = K1;
		     end
		K1:
		     begin
			if(j && rx_en)	fs_next_state = J1;
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		J1:
		     begin
			if(k && rx_en)	fs_next_state = K2;
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		K2:
		     begin
			if(j && rx_en)	fs_next_state = J2;
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		J2:
		     begin
			if(k && rx_en)	fs_next_state = K3;
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		K3:
		     begin
			if(j && rx_en)	fs_next_state = J3;
			else
			if(k && rx_en)
			   begin
					fs_next_state = FS_IDLE;	// Allow missing first K-J
					synced_d = 1'b1;
			   end
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		J3:
		     begin
			if(k && rx_en)	fs_next_state = K4;
			else
			   begin
					sync_err_d = 1'b1;
					fs_next_state = FS_IDLE;
			   end
		     end
		K4:
		     begin
			if(k)	synced_d = 1'b1;
			fs_next_state = FS_IDLE;
		     end
	   endcase
   end

///////////////////////////////////////////////////////////////////
//
// Generate RxActive
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		rx_active <= 1'b0;
	else
	if(synced_d && rx_en)	rx_active <= 1'b1;
	else
	if(se0 && rx_valid_r)	rx_active <= 1'b0;

always @(posedge clk)
	if(rx_valid)	rx_valid_r <= 1'b1;
	else
	if(fs_ce)	rx_valid_r <= 1'b0;

///////////////////////////////////////////////////////////////////
//
// NRZI Decoder
//

always @(posedge clk)
	if(fs_ce)	sd_r <= rxd_s;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		sd_nrzi <= 1'b0;
	else
	if(!rx_active)		sd_nrzi <= 1'b1;
	else
	if(rx_active && fs_ce)	sd_nrzi <= !(rxd_s ^ sd_r);

///////////////////////////////////////////////////////////////////
//
// Bit Stuff Detect
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	one_cnt <= 3'h0;
	else
	if(!shift_en)	one_cnt <= 3'h0;
	else
	if(fs_ce)
	   begin
		if(!sd_nrzi || drop_bit)	one_cnt <= 3'h0;
		else				one_cnt <= one_cnt + 3'h1;
	   end

assign drop_bit = (one_cnt==3'h6);

always @(posedge clk)	bit_stuff_err <= drop_bit & sd_nrzi & fs_ce & !se0 & rx_active; // Bit Stuff Error

///////////////////////////////////////////////////////////////////
//
// Serial => Parallel converter
//

always @(posedge clk)
	if(fs_ce)	shift_en <= synced_d | rx_active;

always @(posedge clk)
	if(fs_ce && shift_en && !drop_bit)
		hold_reg <= {sd_nrzi, hold_reg[7:1]};

///////////////////////////////////////////////////////////////////
//
// Generate RxValid
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		bit_cnt <= 3'b0;
	else
	if(!shift_en)		bit_cnt <= 3'h0;
	else
	if(fs_ce && !drop_bit)	bit_cnt <= bit_cnt + 3'h1;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)					rx_valid1 <= 1'b0;
	else
	if(fs_ce && !drop_bit && (bit_cnt==3'h7))	rx_valid1 <= 1'b1;
	else
	if(rx_valid1 && fs_ce && !drop_bit)		rx_valid1 <= 1'b0;

always @(posedge clk)	rx_valid <= !drop_bit & rx_valid1 & fs_ce;

always @(posedge clk)	se0_r <= se0;

always @(posedge clk)	byte_err <= se0 & !se0_r & (|bit_cnt[2:1]) & rx_active;

endmodule

/////////////////////////////////////////////////////////////////////
////                                                             ////
////  USB 1.1 PHY                                                ////
////  TX                                                         ////
////                                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/cores/usb_phy/   ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000-2002 Rudolf Usselmann                    ////
////                         www.asics.ws                        ////
////                         rudi@asics.ws                       ////
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

//  CVS Log
//
//  $Id: usb_tx_phy.v,v 1.4 2004-10-19 09:29:07 rudi Exp $
//
//  $Date: 2004-10-19 09:29:07 $
//  $Revision: 1.4 $
//  $Author: rudi $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.3  2003/10/21 05:58:41  rudi
//               usb_rst is no longer or'ed with the incomming reset internally.
//               Now usb_rst is simply an output, the application can decide how
//               to utilize it.
//
//               Revision 1.2  2003/10/19 17:40:13  rudi
//               - Made core more robust against line noise
//               - Added Error Checking and Reporting
//               (See README.txt for more info)
//
//               Revision 1.1.1.1  2002/09/16 14:27:02  rudi
//               Created Directory Structure
//
//
//
//
//
//
//

//`include "timescale.v"

module usb_tx_phy(
		clk, rst, fs_ce, phy_mode,
	
		// Transciever Interface
		txdp, txdn, txoe,	

		// UTMI Interface
		DataOut_i, TxValid_i, TxReady_o
		);

input		clk;
input		rst;
input		fs_ce;
input		phy_mode;
output		txdp, txdn, txoe;
input	[7:0]	DataOut_i;
input		TxValid_i;
output		TxReady_o;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

parameter	IDLE	= 3'd0,
		SOP	= 3'h1,
		DATA	= 3'h2,
		EOP1	= 3'h3,
		EOP2	= 3'h4,
		WAIT	= 3'h5;

reg		TxReady_o;
reg	[2:0]	state, next_state;
reg		tx_ready_d;
reg		ld_sop_d;
reg		ld_data_d;
reg		ld_eop_d;
reg		tx_ip;
reg		tx_ip_sync;
reg	[2:0]	bit_cnt;
reg	[7:0]	hold_reg;
reg	[7:0]	hold_reg_d;

reg		sd_raw_o;
wire		hold;
reg		data_done;
reg		sft_done;
reg		sft_done_r;
wire		sft_done_e;
reg		ld_data;
wire		eop_done;
reg	[2:0]	one_cnt;
wire		stuff;
reg		sd_bs_o;
reg		sd_nrzi_o;
reg		append_eop;
reg		append_eop_sync1;
reg		append_eop_sync2;
reg		append_eop_sync3;
reg		append_eop_sync4;
reg		txdp, txdn;
reg		txoe_r1, txoe_r2;
reg		txoe;

///////////////////////////////////////////////////////////////////
//
// Misc Logic
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	TxReady_o <= 1'b0;
	else		TxReady_o <= tx_ready_d & TxValid_i;

always @(posedge clk) ld_data <= ld_data_d;

///////////////////////////////////////////////////////////////////
//
// Transmit in progress indicator
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	tx_ip <= 1'b0;
	else
	if(ld_sop_d)	tx_ip <= 1'b1;
	else
	if(eop_done)	tx_ip <= 1'b0;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		tx_ip_sync <= 1'b0;
	else
	if(fs_ce)		tx_ip_sync <= tx_ip;

// data_done helps us to catch cases where TxValid drops due to
// packet end and then gets re-asserted as a new packet starts.
// We might not see this because we are still transmitting.
// data_done should solve those cases ...
`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)			data_done <= 1'b0;
	else
	if(TxValid_i && ! tx_ip)	data_done <= 1'b1;
	else
	if(!TxValid_i)			data_done <= 1'b0;

///////////////////////////////////////////////////////////////////
//
// Shift Register
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		bit_cnt <= 3'h0;
	else
	if(!tx_ip_sync)		bit_cnt <= 3'h0;
	else
	if(fs_ce && !hold)	bit_cnt <= bit_cnt + 3'h1;

assign hold = stuff;

always @(posedge clk)
	if(!tx_ip_sync)		sd_raw_o <= 1'b0;
	else
	case(bit_cnt)	// synopsys full_case parallel_case
	   3'h0: sd_raw_o <= hold_reg_d[0];
	   3'h1: sd_raw_o <= hold_reg_d[1];
	   3'h2: sd_raw_o <= hold_reg_d[2];
	   3'h3: sd_raw_o <= hold_reg_d[3];
	   3'h4: sd_raw_o <= hold_reg_d[4];
	   3'h5: sd_raw_o <= hold_reg_d[5];
	   3'h6: sd_raw_o <= hold_reg_d[6];
	   3'h7: sd_raw_o <= hold_reg_d[7];
	endcase

always @(posedge clk)
	sft_done <= !hold & (bit_cnt == 3'h7);

always @(posedge clk)
	sft_done_r <= sft_done;

assign sft_done_e = sft_done & !sft_done_r;

// Out Data Hold Register
always @(posedge clk)
	if(ld_sop_d)	hold_reg <= 8'h80;
	else
	if(ld_data)	hold_reg <= DataOut_i;

always @(posedge clk) hold_reg_d <= hold_reg;

///////////////////////////////////////////////////////////////////
//
// Bit Stuffer
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	one_cnt <= 3'h0;
	else
	if(!tx_ip_sync)	one_cnt <= 3'h0;
	else
	if(fs_ce)
	   begin
		if(!sd_raw_o || stuff)	one_cnt <= 3'h0;
		else			one_cnt <= one_cnt + 3'h1;
	   end

assign stuff = (one_cnt==3'h6);

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	sd_bs_o <= 1'h0;
	else
	if(fs_ce)	sd_bs_o <= !tx_ip_sync ? 1'b0 : (stuff ? 1'b0 : sd_raw_o);

///////////////////////////////////////////////////////////////////
//
// NRZI Encoder
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)			sd_nrzi_o <= 1'b1;
	else
	if(!tx_ip_sync || !txoe_r1)	sd_nrzi_o <= 1'b1;
	else
	if(fs_ce)			sd_nrzi_o <= sd_bs_o ? sd_nrzi_o : ~sd_nrzi_o;

///////////////////////////////////////////////////////////////////
//
// EOP append logic
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)		append_eop <= 1'b0;
	else
	if(ld_eop_d)		append_eop <= 1'b1;
	else
	if(append_eop_sync2)	append_eop <= 1'b0;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	append_eop_sync1 <= 1'b0;
	else
	if(fs_ce)	append_eop_sync1 <= append_eop;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	append_eop_sync2 <= 1'b0;
	else
	if(fs_ce)	append_eop_sync2 <= append_eop_sync1;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	append_eop_sync3 <= 1'b0;
	else
	if(fs_ce)	append_eop_sync3 <= append_eop_sync2 |
			(append_eop_sync3 & !append_eop_sync4);	// Make sure always 2 bit wide

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	append_eop_sync4 <= 1'b0;
	else
	if(fs_ce)	append_eop_sync4 <= append_eop_sync3;

assign eop_done = append_eop_sync3;

///////////////////////////////////////////////////////////////////
//
// Output Enable Logic
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	txoe_r1 <= 1'b0;
	else
	if(fs_ce)	txoe_r1 <= tx_ip_sync;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	txoe_r2 <= 1'b0;
	else
	if(fs_ce)	txoe_r2 <= txoe_r1;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	txoe <= 1'b1;
	else
	if(fs_ce)	txoe <= !(txoe_r1 | txoe_r2);

///////////////////////////////////////////////////////////////////
//
// Output Registers
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	txdp <= 1'b1;
	else
	if(fs_ce)	txdp <= phy_mode ?
					(!append_eop_sync3 &  sd_nrzi_o) :
					sd_nrzi_o;

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	txdn <= 1'b0;
	else
	if(fs_ce)	txdn <= phy_mode ?
					(!append_eop_sync3 & ~sd_nrzi_o) :
					append_eop_sync3;

///////////////////////////////////////////////////////////////////
//
// Tx Statemashine
//

`ifdef USB_ASYNC_REST
always @(posedge clk or negedge rst)
`else
always @(posedge clk)
`endif
	if(!rst)	state <= IDLE;
	else		state <= next_state;

always @(state or TxValid_i or data_done or sft_done_e or eop_done or fs_ce)
   begin
	next_state = state;
	tx_ready_d = 1'b0;

	ld_sop_d = 1'b0;
	ld_data_d = 1'b0;
	ld_eop_d = 1'b0;

	case(state)	// synopsys full_case parallel_case
	   IDLE:
			if(TxValid_i)
			   begin
				ld_sop_d = 1'b1;
				next_state = SOP;
			   end
	   SOP:
			if(sft_done_e)
			   begin
				tx_ready_d = 1'b1;
				ld_data_d = 1'b1;
				next_state = DATA;
			   end
	   DATA:
		   begin
			if(!data_done && sft_done_e)
			   begin
				ld_eop_d = 1'b1;
				next_state = EOP1;
			   end
			
			if(data_done && sft_done_e)
			   begin
				tx_ready_d = 1'b1;
				ld_data_d = 1'b1;
			   end
		   end
	   EOP1:
			if(eop_done)		next_state = EOP2;
	   EOP2:
			if(!eop_done && fs_ce)	next_state = WAIT;
	   WAIT:
			if(fs_ce)		next_state = IDLE;
	endcase
   end

endmodule

