class Testbench {

    private var portWires: String = ""
    private var portHooks: String = ""
    private var inputInit: String = ""
    private var clockCreator: String = ""
    private var resetToggler: String = ""
    private var header: String = ""

    init(
        ports: [String: Port],
        inputs: [Port],
        clock: String,
        reset: String,
        resetActive: Simulator.Active = .low,
        in file: String,
        with cells: String
    ) {

        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            self.portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            self.portHooks += ".\(name) ( \(name) ) , "
        }

        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                self.inputInit += "        \(name) = \( resetActive == .low ? 0 : 1 ) ;\n"
            } 
            else {
                self.inputInit += "        \(name) = 0 ;\n"
            }
        } 

        if !clock.isEmpty {
            self.clockCreator = "always #1 \(clock) = ~\(clock);"
        }
        if !reset.isEmpty {
            self.resetToggler = "\(reset) = ~\(reset);"
        }   
        self.header = """
            \(String.boilerplate)
            `include "\(cells)"
            `include "\(file)"
            `include "Netlists/sram_1rw1r_32_256_8_sky130.v"
        """
    }

    func createBoundary (
        chainLength: Int,
        outputBoundaryCount: Int,
        inputs: [Port],
        outputs: [Port],
        tdi: String,
        tdo: String,
        tms: String,
        tck: String,
        trst: String,
        clock: String,
        reset: String,
        module: String
    ) -> String {

        let ignoredInputs = [tck, trst, tdi, tms, clock, reset]
        
        var inputAssignment = ""
        var sampleSerializable = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if (!ignoredInputs.contains(input.name)){
                let bits = Int.random(in: 0...input.width)
                let bitString = String(bits, radix: 2)
                let pad = input.width - bitString.count
                inputAssignment += "        \(name) = \(bits) ;\n"
                sampleSerializable +=
                    (String(repeating: "0", count: pad) + bitString).reversed()
            }
            
        }

        var outputAssignment  = ""
        for (index, output) in outputs.enumerated() {
            if output.name != tdo {
                for i in (0...output.width-1).reversed() {
                    outputAssignment +=
                        "        serializable[\(outputBoundaryCount - index - 1)] = \(output.name)[\(i)] ; \n" 
                    sampleSerializable += "x"
                }
            }
        }

        var preloadSerializable = ""
        for _ in 0..<chainLength {
            preloadSerializable += "\(Int.random(in: 0...1))"
        }

        return """
        \(self.header)
        module testbench;
        \(self.portWires)

            \(self.clockCreator)
            always #1 \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );    

            integer i;

            wire[7:0] tmsPattern = 8'b 01100110;
            wire[3:0] extest = 4'b 0000;
            wire[3:0] samplePreload = 4'b 0001;
            wire[3:0] bypass = 4'b 1111;

            reg[\(chainLength - 1):0] serializable =
                \(chainLength)'b\(sampleSerializable);
            reg[\(chainLength - 1):0] serial;

            wire [\(chainLength - 1): 0] preloadSerializable = 
                \(chainLength)'b\(preloadSerializable);
            reg [\(chainLength - 1): 0] stores;

            initial begin
                $dumpfile("dut.vcd");
                $dumpvars(0, testbench);
        \(self.inputInit)
                \(tms) = 1;
                #150;
                \(self.resetToggler)
                \(trst) = 1;        
                #150;

                /*
                    Test Sample/Preload Instruction
                */
                shiftIR(samplePreload);

                // SAMPLE
                \(tms) = 1;     // select-DR 
                #2;
                \(tms) = 0;     // capture-DR 
        \(inputAssignment)
                #2;
                \(tms) = 0;     // shift-DR 
                #2;
        \(outputAssignment)
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(tdi) = 0;
                    serial[i] = \(tdo); 
                    #2;
                end
                if(serial !== serializable) begin
                    $error("EXECUTING_SAMPLE_INST_FAILED");
                    //$finish;
                end
                exitDR();
                #2;

                // PRELOAD
                enterShiftDR();
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(tdi) = preloadSerializable[i];
                    #2;
                end
                for(i = 0; i< \(chainLength); i = i + 1) begin
                    stores[i] = \(tdo);
                    #2;
                end 
                if(stores !== preloadSerializable) begin
                    $error("EXECUTING_PRELOAD_INST_FAILED");
                    $finish;
                end
                exitDR();
                #2;

                /*
                    Test BYPASS Instruction 
                */
                #10;
                shiftIR(bypass);
                enterShiftDR();
                \(tdi) = 1;
                #6;
                for (i = 0; i < 10; i = i + 1) begin
                    if (\(tdo) != 1) begin
                        $error("ERROR_EXECUTING_BYPASS_INST");
                        $finish;
                    end
                    #2;
                end
                exitDR();

                $display("SUCCESS_STRING");
                $finish;
            end

        \(Testbench.createTasks(tms: tms))
        endmodule
        """
    }

    func createInternal(
        chainLength: [Int],
        tdi: String,
        tdo: String,
        tms: String,
        tck: String,
        trst: String,
        clock: String,
        reset: String,
        module: String
    ) -> String {
        var serializables: [String] = ["", ""]
        var serializableDecl: String = ""
        var serialDecl: String = ""
        for (i, length) in chainLength.enumerated() {
            for _ in 0..<length {
                serializables[i] += "\(Int.random(in: 0...1))"
            }
            serializableDecl +=
                "reg[\(length - 1):0] serializable_\(i) = \(length)'b\(serializables[i]) ;   \n"
            serialDecl +=
                "reg[\(length - 1):0] serial_\(i) ; \n"
        }

        return """
        \(self.header)
        module testbench;
        \(self.portWires)

            \(self.clockCreator)
            always #1 \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );    

            integer i;

            wire[7:0] tmsPattern = 8'b 01100110;
            wire[3:0] preload_chain_1 = 4'b 0011;
            wire[3:0] preload_chain_2 = 4'b 0110;

            \(serializableDecl)
            \(serialDecl)

            initial begin
                $dumpfile("dut.vcd");
                $dumpvars(0, testbench);
        \(self.inputInit)
                \(tms) = 1;
                #150;
                \(self.resetToggler)
                \(trst) = 1;        
                #150;

                /*
                    Test Preload Chain_1 Instruction
                */
                shiftIR(preload_chain_1);
                enterShiftDR();

                for (i = 0; i < \(chainLength[0]); i = i + 1) begin
                    \(tdi) = serializable_0[i];
                    #2;
                end
                for(i = 0; i< \(chainLength[0]); i = i + 1) begin
                    serial_0[i] = \(tdo);
                    #2;
                end 

                if(serial_0 !== serializable_0) begin
                    $error("EXECUTING_PRELOAD_CHAIN_1_INST_FAILED");
                    $finish;
                end
                exitDR();
                #2;

                /*
                    Test Preload Chain_2 Instruction
                */
                shiftIR(preload_chain_2);
                enterShiftDR();

                for (i = 0; i < \(chainLength[1]); i = i + 1) begin
                    \(tdi) = serializable_1[i];
                    #2;
                end
                for(i = 0; i< \(chainLength[0]); i = i + 1) begin
                    serial_1[i] = \(tdo);
                    #2;
                end 

                if(serial_1 !== serializable_1) begin
                    $error("EXECUTING_PRELOAD_CHAIN_2_INST_FAILED");
                    $finish;
                end
                exitDR();

                $display("SUCCESS_STRING");
                $finish;
            end

        \(Testbench.createTasks(tms: tms))
        endmodule
        """
    }
    private static func createTasks (tms: String) -> String {
        return """
        task shiftIR;
            input[3:0] instruction;
            integer i;
            begin
                for (i = 0; i< 5; i = i + 1) begin
                    \(tms) = tmsPattern[i];
                    #2;
                end

                // At shift-IR: shift new instruction on tdi line
                for (i = 0; i < 4; i = i + 1) begin
                    tdi = instruction[i];
                    if(i == 3) begin
                        \(tms) = tmsPattern[5];     // exit-ir
                    end
                    #2;
                end

                \(tms) = tmsPattern[6];     // update-ir 
                #2;
                \(tms) = tmsPattern[7];     // run test-idle
                #6;
            end
        endtask

        task enterShiftDR;
            begin
                \(tms) = 1;     // select DR
                #2;
                \(tms) = 0;     // capture DR -- shift DR
                #4;
            end
        endtask

        task exitDR;
            begin
                \(tms) = 1;     // Exit DR -- update DR
                #4;
                \(tms) = 0;     // Run test-idle
                #2;
            end
        endtask
    """
    }

}