`timescale 1ns / 1ns
module top;

reg clk;
reg [3:0] cnt;

initial forever #25 clk = ~clk;

initial 
begin
`ifdef __ICARUS__
  $dumpfile("task_prob.lxt");
`else
  $dumpfile("task_prob.vcd");
`endif
  $dumpvars(0, top);
  clk = 0;
  cnt = 4'h0;
end

initial 
begin
  #20;
  `ifdef CAUSES_PROBLEM
  /*
   * C-Style quotes within an `ifdef causes problems.
   *
   */
  `endif
  auto_task_line_at_30(fail_here);
  auto_task;
  auto_task;
  #1;
  $finish;
end

initial 
begin
  #20;
  normal_task;
  normal_task;
  normal_task;
end

always @ (posedge clk)
  cnt <= cnt + 4'd1;

task automatic auto_task;
  begin
    @ (negedge cnt[3])
    //@ (negedge clk)
    $display("auto_task: Time is %5t", $time);
  end
endtask

task normal_task;
  begin
    @ (negedge cnt[3])
    //@ (negedge clk)
    $display("normal_task: Time is %5t", $time);
  end
endtask

endmodule
