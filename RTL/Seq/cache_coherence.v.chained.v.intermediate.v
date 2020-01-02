

module __UNIT__UNDER__FINANGLING__
(
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
  AllInvDone,
  shift,
  sin,
  sout
);

  input sin;
  output sout;
  input shift;
  input RMS;input RME;input WM;input WH;input SHR;input SHW;input READ_DONE;input clk;input reset;input send_abort;input write_back_done;input AllInvDone;
  input [2:0] state;
  output [2:0] new_state;
  output Cache_Sector_Fill;output Invalidate;output AdrRetry;
  reg Cache_Sector_Fill;reg Invalidate;reg AdrRetry;
  reg [2:0] new_state;
  parameter INVALID = 3'b000;parameter SHARED_1 = 3'b001;parameter EXCLUSIVE = 3'b010;parameter MODIFIED = 3'b011;parameter Cache_Fill = 3'b100;parameter start_write_back = 3'b101;parameter WaitUntilAllInv = 3'b110;
  reg [2:0] present_state;
  reg [2:0] next_state;

  always @(present_state or RMS or RME or WM or WH or SHW or READ_DONE or SHR or write_back_done or AllInvDone or send_abort or state or reset) begin
    Cache_Sector_Fill = 0;
    Invalidate = 0;
    AdrRetry = 0;
    next_state = present_state;
    if(reset) next_state = state; 
    else begin
      case(present_state)
        INVALID: if(RMS || RME || WM) begin
          Cache_Sector_Fill = 1;
          next_state = Cache_Fill;
        end else begin
          next_state = INVALID;
        end
        Cache_Fill: if(send_abort) begin
          next_state = INVALID;
        end else if(READ_DONE) begin
          if(RMS) begin
            next_state = SHARED_1;
          end else if(RME) begin
            next_state = EXCLUSIVE;
          end else if(WM) begin
            Invalidate = 1;
            next_state = WaitUntilAllInv;
          end else begin
            next_state = Cache_Fill;
          end
        end else begin
          next_state = Cache_Fill;
        end
        SHARED_1: if(SHW) begin
          next_state = INVALID;
        end else if(WH) begin
          Invalidate = 1;
          next_state = WaitUntilAllInv;
        end else begin
          next_state = SHARED_1;
        end
        WaitUntilAllInv: if(AllInvDone) begin
          next_state = MODIFIED;
        end else begin
          next_state = WaitUntilAllInv;
        end
        EXCLUSIVE: if(SHR) begin
          AdrRetry = 0;
          next_state = SHARED_1;
        end else if(SHW) begin
          next_state = INVALID;
        end else if(WH) begin
          next_state = MODIFIED;
        end else begin
          next_state = EXCLUSIVE;
        end
        MODIFIED: if(SHW) begin
          next_state = INVALID;
        end else if(SHR) begin
          AdrRetry = 1;
          next_state = start_write_back;
        end else begin
          next_state = MODIFIED;
        end
        start_write_back: if(write_back_done) begin
          next_state = SHARED_1;
        end else begin
          next_state = start_write_back;
        end
      endcase
    end
  end


  always @(posedge clk) begin
    present_state = next_state;
    new_state = next_state;
  end

  assign sout = sin;

endmodule



module BoundaryScanRegister_input
(
  din,
  dout,
  sin,
  sout,
  clock,
  reset,
  testing
);

  input din;
  output dout;
  input sin;
  output sout;
  input clock;input reset;input testing;
  reg store;

  always @(posedge clock or posedge reset) begin
    if(reset) begin
      store <= 1'b0;
    end else begin
      store <= sin;
    end
  end

  assign sout = store;
  assign dout = (testing)? store : din;

endmodule



module BoundaryScanRegister_output
(
  din,
  dout,
  sin,
  sout,
  clock,
  reset,
  testing
);

  input din;
  output dout;
  input sin;
  output sout;
  input clock;input reset;input testing;
  reg store;

  always @(posedge clock or posedge reset) begin
    if(reset) begin
      store <= 1'b0;
    end else begin
      store <= (testing)? sin : din;
    end
  end

  assign sout = store;
  assign dout = din;

endmodule



module cache_coherence
(
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
  AllInvDone,
  shift,
  sin,
  sout
);

  wire __sin_0__;
  wire __sin_1__;
  wire __sin_2__;
  wire __sin_3__;
  wire __sin_4__;
  wire __sin_5__;
  wire __sin_6__;
  wire __sin_7__;
  wire __sin_8__;
  wire __sin_9__;
  input sin;
  output sout;
  input shift;
  assign __sin_0__ = sin;
  input RMS;
  wire RMS__dout;

  BoundaryScanRegister_input
  __BoundaryScanRegister_input_0__
  (
    .din(RMS[0]),
    .dout(RMS__dout[0]),
    .sin(__sin_0__),
    .sout(__sin_1__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );

  input [2:0] state;
  wire [2:0] state__dout;

  BoundaryScanRegister_input
  __BoundaryScanRegister_input_1__
  (
    .din(state[0]),
    .dout(state__dout[0]),
    .sin(__sin_1__),
    .sout(__sin_2__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );


  BoundaryScanRegister_input
  __BoundaryScanRegister_input_2__
  (
    .din(state[1]),
    .dout(state__dout[1]),
    .sin(__sin_2__),
    .sout(__sin_3__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );


  BoundaryScanRegister_input
  __BoundaryScanRegister_input_3__
  (
    .din(state[2]),
    .dout(state__dout[2]),
    .sin(__sin_3__),
    .sout(__sin_4__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );

  output [2:0] new_state;
  wire [2:0] new_state_din;

  BoundaryScanRegister_output
  __BoundaryScanRegister_output_4__
  (
    .din(new_state_din[0]),
    .dout(new_state[0]),
    .sin(__sin_5__),
    .sout(__sin_6__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );


  BoundaryScanRegister_output
  __BoundaryScanRegister_output_5__
  (
    .din(new_state_din[1]),
    .dout(new_state[1]),
    .sin(__sin_6__),
    .sout(__sin_7__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );


  BoundaryScanRegister_output
  __BoundaryScanRegister_output_6__
  (
    .din(new_state_din[2]),
    .dout(new_state[2]),
    .sin(__sin_7__),
    .sout(__sin_8__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );

  output Cache_Sector_Fill;
  wire Cache_Sector_Fill_din;

  BoundaryScanRegister_output
  __BoundaryScanRegister_output_7__
  (
    .din(Cache_Sector_Fill_din[0]),
    .dout(Cache_Sector_Fill[0]),
    .sin(__sin_8__),
    .sout(__sin_9__),
    .clock(clk),
    .reset(reset),
    .testing(shift)
  );


  __UNIT__UNDER__FINANGLING__
  __uuf__
  (
    .RMS(RMS__dout),
    .state(state__dout),
    .shift(shift),
    .sin(__sin_4__),
    .sout(__sin_5__),
    .new_state(new_state_din),
    .Cache_Sector_Fill(Cache_Sector_Fill_din)
  );

  assign sout = __sin_9__;

endmodule


