`include "Tech/osu035/osu035_stdcells.v"
`include "Netlists/RTL/ISCAS_89/s27.v.netlist.v.chained.v.jtag.v.intermediate.v"

module testbench;
    wire[0:0] \tdo ;
    reg[0:0] \G0 ;
    reg[0:0] \tms ;
    wire[0:0] \G17 ;
    reg[0:0] \VDD ;
    reg[0:0] \G2 ;
    reg[0:0] \G1 ;
    reg[0:0] \reset ;
    reg[0:0] \GND ;
    reg[0:0] \trst ;
    reg[0:0] \G3 ;
    reg[0:0] \tdi ;
    reg[0:0] \CK ;
    reg[0:0] \tck ;

    
    always #1 CK = ~CK;
    always #1 tck = ~tck;

    s27 uut(
        .\tdo ( \tdo ) , .\G0 ( \G0 ) , .\tms ( \tms ) , .\G17 ( \G17 ) , .\VDD ( \VDD ) , .\G2 ( \G2 ) , .\G1 ( \G1 ) , .\reset ( \reset ) , .\GND ( \GND ) , .\trst ( \trst ) , .\G3 ( \G3 ) , .\tdi ( \tdi ) , .\CK ( \CK ) , .\tck ( \tck ) 
    );

    integer i;
    reg [6: 0] stores;
    // Supported Instructions
    wire[3:0] extest = 4'b 0000;
    wire[3:0] samplePreload = 4'b 0001;
    wire[3:0] bypass = 4'b 1111;
    wire[3:0] scanIn = 4'b 0100;

    reg[6:0] serializable = 7'b1011100;
    wire [6: 0] boundarySerial = 7'b0000001;
   
    reg[6:0] serial;
    
    wire [2: 0] scanInSerializable = 3'b110;
    reg[2:0] scanInSerial;

    initial begin
        \GND = 0 ;
        \VDD = 0 ;
        \CK = 0 ;
        \reset = 1 ;
        \G0 = 0 ;
        \G1 = 0 ;
        \G2 = 0 ;
        \G3 = 0 ;
        \tms = 1 ;
        \tck = 0 ;
        \tdi = 0 ;
        \trst = 0 ;

        #10;
        reset = ~reset;
        trst = 1;        
        #2;
        /*
            Test Sample/Preload Instruction
        */
        tms = 1;     // test logic reset state
        #10;
        tms = 0;     // run-test idle state
        #2;
        tms = 1;     // select-DR state
        #2;
        tms = 1;     // select-IR state
        #2;
        tms = 0;     // capture IR
        #2;
        tms = 0;     // Shift IR state
        #2

        // shift new instruction on tdi line
        for (i = 0; i < 4; i = i + 1) begin
            tdi = samplePreload[i];
            if(i == 3) begin
                tms = 1;     // exit-ir
            end
            #2;
        end
        tms = 1;     // update-ir 
        #2;
        tms = 0;     // run test-idle
        #6;

        // SAMPLE
        tms = 1;     // select-DR 
        #2;
        tms = 0;     // capture-DR 
        \GND = 1 ;
        \VDD = 0 ;
        \G0 = 1 ;
        \G1 = 1 ;
        \G2 = 1 ;
        \G3 = 0 ;

        #2;
        tms = 0;     // shift-DR 
        #2;
        serializable[0] = G17 ; 

        #2;
        for (i = 0; i < 7; i = i + 1) begin
            tms = 0;
            serial[i] = tdo; 
            #2;
        end
        if(serial != serializable) begin
            $error("EXECUTING_SAMPLE_INST_FAILED");
            $finish;
        end
        #100;
        tms = 1;     // Exit DR
        #2;
        tms = 1;     // update DR
        #2;
        tms = 0;     // Run test-idle
        #2;

        // PRELOAD
        tms = 1;     // select DR
        #2;
        tms = 0;     // capture DR
        #2;
        tms = 0;     // shift DR
        #2;
        for (i = 0; i < 7; i = i + 1) begin
            tdi = boundarySerial[i];
            if(i == 6)
                tms = 1;     // exit-dr
            #2;
        end
        tms = 1;     // update DR
        #2;
        tms = 0;     // run-test idle
        #2;
        stores[0] = uut.__dut__.\__BoundaryScanRegister_input_0__.store ;
        stores[1] = uut.__dut__.\__BoundaryScanRegister_input_1__.store ;
        stores[2] = uut.__dut__.\__BoundaryScanRegister_input_2__.store ;
        stores[3] = uut.__dut__.\__BoundaryScanRegister_input_3__.store ;
        stores[4] = uut.__dut__.\__BoundaryScanRegister_input_4__.store ;
        stores[5] = uut.__dut__.\__BoundaryScanRegister_input_5__.store ;
        stores[6] = uut.__dut__.\__BoundaryScanRegister_output_6__.store ;

        for(i = 0; i< 7; i = i + 1) begin
            if(stores[i] != boundarySerial[i + 6]) begin
                $error("EXECUTING_PRELOAD_INST_FAILED");
                $finish;
            end
        end 
        /*
            Test SCAN IN Instruction
        */
        tms = 1;     // select-DR 
        #2;
        tms = 1;     // select-IR 
        #2;
        tms = 0;     // capture-IR
        #2;
        tms = 0;     // Shift-IR 
        #2

        // shift new instruction on tdi line
        for (i = 0; i < 4; i = i + 1) begin
            tdi = scanIn[i];
            if(i == 3) begin
                tms = 1;     // exit-ir
            end
            #2;
        end
        tms = 1;     // update-ir 
        #2;
        tms = 0;     // run test-idle
        #6;
        
        tms = 1;     // select-DR
        #2;
        tms = 0;     // capture-DR
        #2;
        tms = 0;     // shift-DR
        #2;

        for (i = 0; i < 3; i = i + 1) begin
            tdi = scanInSerializable[i];
            #2;
        end

        for (i = 0; i < 3; i = i + 1) begin
            scanInSerial[i] = tdo;
            if(i == 2)
                tms = 1;     // exit-dr
            #2;
        end
        if(scanInSerial != scanInSerializable) begin
            $error("EXECUTING_SCANIN_INST_FAILED");
            $finish;
        end
        tms = 1;     // update-DR
        #2;
        tms = 0;     // run-test idle
        #2;

        /*
            Test BYPASS Instruction 
        */
        tms = 1;     // select-DR 
        #2;
        tms = 1;     // select-IR 
        #2;
        tms = 0;     // capture-IR
        #2;
        tms = 0;     // Shift-IR 
        #2
        // shift new instruction on tdi line
        for (i = 0; i < 4; i = i + 1) begin
            tdi = bypass[i];
            if(i == 3) begin
                tms = 1;     // exit-ir
            end
            #2;
        end
        tms = 1;     // update-ir 
        #2;
        tms = 0;     // run test-idle
        #6;
        
        tms = 1;     // select-DR
        #2;
        tms = 0;     // capture-DR
        #2;
        tms = 0;     // shift-DR
        #2;
        for (i = 0; i < 10; i = i + 1) begin
            tdi = 1;
            #2;
            if (tdo != 1) begin
                $error("ERROR_EXECUTING_BYPASS_INST");
            end
            if(i == 9) begin
                tms = 1;     // exit-ir
            end
        end
        
        tms = 1;     // update-ir 
        #2;
        tms = 0;     // run test-idle
        #2;
        $display("SUCCESS_STRING");
        $finish;
    end
endmodule
