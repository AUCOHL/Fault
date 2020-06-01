module jtagTasks();
    /*
        Pulls tms high for at least five clock cycles.
        Puts the tap controller at the test-logic reset state.
    */
    task resetTap;
        output tms;
        tms = 1;
        #10;
    endtask

    /*
        Shifts a new instruction on the tdi line.
        Assumes that tap is either at update-IR/DR state or Run-test Idle state. 
        Applies the following tms pattern: 
            0. run-test idle  : 0
            1. select-DR      : 1
            2. select-IR      : 1
            3. capture-IR     : 0
            4. shift-IR       : 0
            5. exit-IR        : 1
            6. update-IR      : 1
            7. run-test idle  : 0
    */
    task shiftIR;
        input[3:0] instruction;
        output tms;
        output tdi;

        wire [7:0] tmsPattern = 8'b 01100110;

        for (i = 0; i< 5; i = i + 1) begin
            tms = tmsPattern[i];
            #2;
        end

        // At shift-IR: shift new instruction on tdi line
        for (i = 0; i < 4; i = i + 1) begin
            tdi = samplePreload[i];
            if(i == 3) begin
                tms = tmsPattern[5];     // exit-ir
            end
            #2;
        end

        tms = tmsPattern[6];     // update-ir 
        #2;
        tms = tmsPattern[7];     // run test-idle
        #6;

    endtask

    task test;

    endtask

endmodule
