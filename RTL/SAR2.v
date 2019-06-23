/*******************************************************************
*
* Module: controller.v
* Project: SAR_ADC_Converter
* Author: Manar Abdelatty  manarabdelatty@aucegypt.edu
* Description:  
*
* Change history: 01/01/17 – 
*
**********************************************************************/
`timescale 1ns/1ns

module controller(clk, rst_n, go,  cmp,sample, value, valid, result );

 parameter n=8;
 parameter activeSample=8;         // #of cyles that sample should be active
 input clk; 
 input rst_n;
 input go; 
 input cmp;
 output  sample;
 output [n-1:0] value;
 output reg [n-1:0] result;
 output  valid;
 reg finished;
 reg [n-1:0] ringcount;
 wire start;
 
 
  sarfsm #(activeSample) fsm ( .clk(clk)  , .rst_n(rst_n) , .go(go) , .finished(finished) , .sample(sample) , .en(start), .valid(valid) );
 
   always @(posedge clk or negedge rst_n) begin 
 
       if (!rst_n) begin
           ringcount <= 0;
           result <=0;
           finished <=0;
       end
       else begin
          if (sample) begin
             ringcount <= {1'b1, {n-1{1'b0}} };
             finished <=0;
             result <=0;
          end
          else if (start) begin
          
          ringcount <= ringcount >>1;
          
             if (cmp) 
               result <= result | ringcount;
             
             if (ringcount[1]) 
                finished <=1'b1;
          end
      
       end
   end
   
   assign value = result | ringcount ;
 
endmodule

/*******************************************************************
*
* Module: sarfsm.v
* Project: SAR_ADC_Converter
* Author: Manar Abdelatty  manarabdelatty@aucegypt.edu
* Description: SAR Finite state machine 
*
* Change history: 01/01/17 – 
*
**********************************************************************/
`timescale 1ns/1ns

module sarfsm ( clk ,rst_n, go,finished, sample , en, valid);
 
 parameter activeSample= 8;                // Number of cycles that  the sample signal must be active for

 
 input clk;
 input rst_n;
 input go; 
 input finished;
 output sample;
 output en;
 output valid;
 wire exitSample;
 reg [activeSample-1:0] count;
 
 parameter [1:0] idle=2'b00, sh= 2'b01, start=2'b10, done= 2'b11;
 reg [1:0] state, newstate;

 always @* begin
      case(state) 
        idle:
              if (go) begin 
              newstate = sh;
              end
              else    newstate= idle;
        sh:                                 // sample and hold state
          if (go) begin
                if (exitSample)
                    newstate = start;
                  else   newstate = sh;
           end
             else newstate = idle;
                
        start: if (go)
                   if (finished)
                      newstate= done;
                   else newstate = start;
               else 
                 newstate = idle; 
        done: if (go)
                   newstate= done;
              else newstate= idle;
        default: newstate = 2'bxx;
      endcase
      
 end 
 
 always @(posedge clk or negedge rst_n) begin
           if (!rst_n) begin 
               state  <= idle;
               count <=0;
           end
           else begin
              state <=newstate; 
              if (state == sh)
                   count <= count+1;
              else count <= 0;
           end
 end

 assign sample = (state == sh);
 assign en  = (state == start);
 assign exitSample= (count >= activeSample);
 assign valid = (state==done);
 
endmodule