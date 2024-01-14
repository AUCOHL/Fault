// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BigInt
import Defile
import Foundation
import PythonKit

class CoverageMeta: Codable {
    let ratio: Float
    let sa0Covered: [String]
    let sa1Covered: [String]

    init(ratio: Float, sa0Covered: [String], sa1Covered: [String]) {
        self.ratio = ratio
        self.sa0Covered = sa0Covered
        self.sa1Covered = sa1Covered
    }
}

enum Simulator {
    enum Behavior: Int {
        case holdHigh = 1
        case holdLow = 0
    }

    static func pseudoRandomVerilogGeneration(
        using testVector: TestVector,
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with models: [String],
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String>,
        behavior: [Behavior],
        outputs: [Port],
        stuckAt: Int,
        cleanUp: Bool,
        goldenOutput: Bool,
        clock: String?,
        filePrefix: String = ".",
        defines: Set<String> = [],
        using _: String,
        with _: String
    ) throws -> (faults: [String], goldenOutput: String) {
        var portWires = ""
        var portHooks = ""
        var portHooksGM = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name).gm ;\n"
            portHooks += ".\(name) ( \(name) ) , "
            portHooksGM += ".\(name) ( \(name).gm ) , "
        }

        let folderName = "\(filePrefix)/thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        _ = "mkdir -p \(folderName)".sh()

        var inputAssignment = ""
        var fmtString = ""
        var inputList = ""

        for (i, input) in inputs.enumerated() {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"

            inputAssignment += "        \(name) = \(testVector[i]) ;\n"
            inputAssignment += "        \(name).gm = \(name) ;\n"

            fmtString += "%d "
            inputList += "\(name) , "
        }

        for (i, rawName) in ignoredInputs.enumerated() {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"

            inputAssignment += "        \(name) = \(behavior[i].rawValue) ;\n"
            inputAssignment += "        \(name).gm = \(behavior[i].rawValue) ;\n"
        }

        fmtString = String(fmtString.dropLast(1))
        inputList = String(inputList.dropLast(2))

        var defineStatements = ""
        for def in defines {
            defineStatements += "-D\(def) "
        }

        var outputCount = 0
        var outputComparison = ""
        var outputAssignment = ""
        for output in outputs {
            let name = (output.name.hasPrefix("\\")) ? output.name : "\\\(output.name)"
            outputComparison += " ( \(name) != \(name).gm ) || "
            if output.width > 1 {
                for i in 0 ..< output.width {
                    outputAssignment += "   assign goldenOutput[\(outputCount)] = gm.\(output.name) [\(i)] ; \n"
                    outputCount += 1
                }
            } else {
                outputAssignment += "   assign goldenOutput[\(outputCount)] = gm.\(name) ; \n"
                outputCount += 1
            }
        }
        outputComparison = String(outputComparison.dropLast(3))

        var faultForces = ""
        for fault in faultPoints {
            faultForces += "        force uut.\(fault) = \(stuckAt) ; \n"
            faultForces += "        #1 ; \n"
            faultForces += "        if (difference) $display(\"\(fault)\") ; \n"
            faultForces += "        #1 ; \n"
            faultForces += "        release uut.\(fault) ;\n"
            faultForces += "        #1 ; \n"
        }

        var clockCreator = ""
        if let clockName = clock {
            clockCreator = "always #1 \(clockName) = ~\(clockName);"
        }

        var includes = ""
        for model in models {
            includes += "`include \"\(model)\"\n"
        }
        includes += "`include \"\(file)\"\n"

        let bench = """
        \(String.boilerplate)

        \(includes)

        module FaultTestbench;

        \(portWires)
            \(clockCreator)
            \(module) uut(
                \(portHooks.dropLast(2))
            );
            \(module) gm(
                \(portHooksGM.dropLast(2))
            );

            \(goldenOutput ?
            "wire [\(outputCount - 1):0] goldenOutput; \n \(outputAssignment)" : "")

            wire difference ;
            assign difference = (\(outputComparison));

            integer counter;

            initial begin
        \(inputAssignment)
        \(faultForces)
        \(goldenOutput ? "        $displayb(\"%b\", goldenOutput);" : "")
                $finish;
            end

        endmodule
        """

        let tbName = "\(folderName)/tb.sv"
        try File.open(tbName, mode: .write) {
            try $0.print(bench)
        }

        let aoutName = "\(folderName)/a.out"
        let intermediate = "\(folderName)/intermediate"
        let env = ProcessInfo.processInfo.environment
        let iverilogExecutable = env["FAULT_IVERILOG"] ?? "iverilog"
        let vvpExecutable = env["FAULT_VVP"] ?? "vvp"

        let iverilogResult =
            "'\(iverilogExecutable)' -B '\(iverilogBase)' -Ttyp \(defineStatements) -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogResult))
        }

        let vvpTask = "'\(vvpExecutable)' \(aoutName) > \(intermediate)".sh()
        if vvpTask != EX_OK {
            exit(vvpTask)
        }

        let output = File.read(intermediate)!
        defer {
            if cleanUp {
                _ = "rm -rf \(folderName)".sh()
            } else {
                print("Find testbenches at : \(folderName)")
            }
        }
        var faults = output.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.contains("$finish")
        }
        var gmOutput = ""
        if goldenOutput {
            let last = faults.removeLast()
            if let bin = BigUInt(last, radix: 2) {
                gmOutput = String(bin, radix: 16)
            } else {
                print("[Warning]: Golden output was invalid: '\(last)'.")
            }
        }

        return (faults: faults, goldenOutput: gmOutput)
    }

    static func simulate(
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with models: [String],
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String> = [],
        behavior: [Behavior] = [],
        outputs: [Port],
        initialVectorCount: Int,
        incrementingBy increment: Int,
        minimumCoverage: Float,
        ceiling: Int,
        randomGenerator: String,
        TVSet: [TestVector],
        sampleRun: Bool,
        clock: String?,
        defines: Set<String> = [],
        using iverilogExecutable: String,
        with vvpExecutable: String
    ) throws -> (coverageList: [TVCPair], coverageMeta: CoverageMeta) {
        var testVectorHash: Set<TestVector> = []

        var coverageList: [TVCPair] = []
        var coverage: Float = 0.0

        var sa0Covered: Set<String> = []
        sa0Covered.reserveCapacity(faultPoints.count)
        var sa1Covered: Set<String> = []
        sa1Covered.reserveCapacity(faultPoints.count)

        var totalTVAttempts = 0
        var tvAttempts = min(initialVectorCount, ceiling, sampleRun ? 1 : Int.max)

        let simulateOnly = (TVSet.count != 0)
        let rng: URNG = URNGFactory.get(name: randomGenerator)!

        while coverage < minimumCoverage, totalTVAttempts < ceiling {
            if totalTVAttempts > 0 {
                if sampleRun {
                    break
                }
                print("Minimum coverage not met (\(coverage * 100)%/\(minimumCoverage * 100)%,) incrementing to \(totalTVAttempts + tvAttempts)…")
            }

            var futureList: [Future] = []
            var testVectors: [TestVector] = []
            for index in 0 ..< tvAttempts {
                var testVector: TestVector = []
                if simulateOnly {
                    testVector = TVSet[totalTVAttempts + index]
                } else {
                    for input in inputs {
                        testVector.append(rng.generate(bits: input.width))
                    }
                }
                if testVectorHash.contains(testVector) {
                    continue
                }
                testVectorHash.insert(testVector)
                testVectors.append(testVector)
            }

            if testVectors.count < tvAttempts {
                print("Skipped \(tvAttempts - testVectors.count) duplicate generated test vectors.")
            }
            let tempDir = "."

            for vector in testVectors {
                let future = Future {
                    do {
                        let (sa0, output) =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: models,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 0,
                                cleanUp: !sampleRun,
                                goldenOutput: true,
                                clock: clock,
                                filePrefix: tempDir,
                                defines: defines,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        let (sa1, _) =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: models,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 1,
                                cleanUp: !sampleRun,
                                goldenOutput: false,
                                clock: clock,
                                filePrefix: tempDir,
                                defines: defines,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        return (Covers: Coverage(sa0: sa0, sa1: sa1), Output: output)
                    } catch {
                        print("IO Error @ vector \(vector)")
                        return (Covers: Coverage(sa0: [], sa1: []), Output: "")
                    }
                }
                futureList.append(future)
            }

            for (i, future) in futureList.enumerated() {
                let (coverLists, output) = future.value as! (Coverage, String)
                for cover in coverLists.sa0 {
                    sa0Covered.insert(cover)
                }
                for cover in coverLists.sa1 {
                    sa1Covered.insert(cover)
                }
                coverageList.append(
                    TVCPair(
                        vector: testVectors[i],
                        coverage: coverLists,
                        goldenOutput: output
                    )
                )
            }

            coverage =
                Float(sa0Covered.count + sa1Covered.count) /
                Float(2 * faultPoints.count)

            totalTVAttempts += tvAttempts
            let remainingTV = ceiling - totalTVAttempts
            tvAttempts = (remainingTV < increment) ? remainingTV : increment
        }

        if coverage < minimumCoverage {
            print("Hit ceiling. Settling for current coverage.")
        }

        return (
            coverageList: coverageList,
            coverageMeta: CoverageMeta(
                ratio: coverage,
                sa0Covered: sa0Covered.sorted(),
                sa1Covered: sa1Covered.sorted()
            )
        )
    }

    enum Active {
        case low
        case high
    }

    static func simulate(
        verifying module: String,
        in file: String,
        with models: [String],
        ports: [String: Port],
        inputs: [Port],
        outputs _: [Port],
        chainLength: Int,
        clock: String,
        tck: String,
        reset: String,
        sin: String,
        sout: String,
        resetActive: Active = .low,
        shift: String,
        test: String,
        output: String,
        defines: Set<String> = [],
        using _: String,
        with _: String
    ) throws -> Bool {
        var portWires = ""
        var portHooks = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portHooks += ".\(name) ( \(name) ) , "
        }

        var inputAssignment = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputAssignment += "        \(name) = \(resetActive == .low ? 0 : 1) ;\n"
            } else {
                inputAssignment += "        \(name) = 0 ;\n"
            }
        }

        var serial = "0"
        for _ in 0 ..< chainLength - 1 {
            serial += "\(Int.random(in: 0 ... 1))"
        }

        var clockCreator = ""
        if !clock.isEmpty {
            clockCreator = "        always #(`CLOCK_PERIOD / 2) \(clock) = ~\(clock); \n"
            clockCreator += "        always #(`CLOCK_PERIOD / 2) \(tck) = ~\(tck); \n"
        }

        var includes = ""
        for model in models {
            includes += "`include \"\(model)\"\n"
        }
        includes += "`include \"\(file)\"\n"

        var defineStatements = ""
        for def in defines {
            defineStatements += "-D\(def) "
        }

        let bench = """
        \(String.boilerplate)
        \(includes)

        `ifndef CLOCK_PERIOD
            `define CLOCK_PERIOD 4
        `endif

        module testbench;
        \(portWires)
        \(clockCreator)
            \(module) uut(
                \(portHooks.dropLast(2))
            ); 

            wire[\(chainLength - 1):0] __serializable__ =
                \(chainLength)'b\(serial);
            reg[\(chainLength - 1):0] __serial__;
            integer i;
            initial begin
                `ifdef VCD
                    $dumpfile("chain.vcd");
                    $dumpvars(0, testbench);
                `endif
        \(inputAssignment)
                #(`CLOCK_PERIOD*5);
                \(reset) = ~\(reset);
                \(shift) = 1;
                \(test) = 1;
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(sin) = __serializable__[i];
                    #(`CLOCK_PERIOD);
                end
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    __serial__[i] = \(sout);
                    #(`CLOCK_PERIOD);
                end
                if (__serializable__ === __serial__) begin
                    $display("Success: expected %b got %b", __serializable__, __serial__);
                    $display("SUCCESS_STRING");
                end else begin
                    $display("Failed: expected %b got %b", __serializable__, __serial__);
                end
                $finish;
            end
        endmodule
        """

        return try Simulator.run(
            define: defineStatements,
            bench: bench,
            output: output
        )
    }

    static func simulate(
        verifying module: String,
        in file: String,
        with models: [String],
        ports: [String: Port],
        inputs: [Port],
        outputs _: [Port],
        chainLength: Int,
        clock: String,
        reset: String,
        resetActive: Active = .low,
        tms: String,
        tdi: String,
        tck: String,
        tdo: String,
        trst: String,
        output: String,
        defines: Set<String> = [],
        using _: String,
        with _: String
    ) throws -> Bool {
        var portWires = ""
        var portHooks = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portHooks += ".\(name) ( \(name) ) , "
        }

        var inputInit = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputInit += "        \(name) = \(resetActive == .low ? 0 : 1) ;\n"
            } else {
                inputInit += "        \(name) = 0 ;\n"
            }
        }

        var clockCreator = ""
        if !clock.isEmpty {
            clockCreator = "always #(`CLOCK_PERIOD / 2) \(clock) = ~\(clock);"
        }

        var resetToggler = ""
        if !reset.isEmpty {
            resetToggler = "\(reset) = ~\(reset);"
        }

        var serial = ""
        for _ in 0 ..< chainLength {
            serial += "\(Int.random(in: 0 ... 1))"
        }

        var includes = ""
        for model in models {
            includes += "`include \"\(model)\"\n"
        }
        includes += "`include \"\(file)\"\n"

        var defineStatements = ""
        for def in defines {
            defineStatements += "-D\(def) "
        }

        let bench = """
        \(String.boilerplate)

        \(includes)

        `ifndef CLOCK_PERIOD
            `define CLOCK_PERIOD 4
        `endif

        module testbench;
        \(portWires)

            \(clockCreator)
            always #(`CLOCK_PERIOD / 2) \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );    

            integer i;

            wire[\(chainLength - 1):0] __serializable__ =
                \(chainLength)'b\(serial);
            reg[\(chainLength - 1):0] __serial__;

            wire[7:0] __tmsPattern__ = 8'b 01100110;
            wire[3:0] __preload_chain__ = 4'b0011;

            wire __tdo_pad_out__ = tdo_paden_o ? 1'bz : \(tdo);

            initial begin
                `ifdef VCD
                    $dumpfile("dut.vcd");
                    $dumpvars(0, testbench);
                `endif
        \(inputInit)
                \(tms) = 1;
                #(`CLOCK_PERIOD) ;
                \(resetToggler)
                \(trst) = 1;        
                #(`CLOCK_PERIOD) ;

                /*
                    Test PreloadChain Instruction
                */
                shiftIR(__preload_chain__);
                enterShiftDR();

                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(tdi) = __serializable__[i];
                    #(`CLOCK_PERIOD) ;
                end
                for(i = 0; i< \(chainLength); i = i + 1) begin
                    __serial__[i] = __tdo_pad_out__;
                    #(`CLOCK_PERIOD) ;
                end 

                if(__serial__ !== __serializable__) begin
                    $error("EXECUTING_PRELOAD_CHAIN_INST_FAILED");
                    $finish;
                end
                exitDR();

                $display("SUCCESS_STRING");
                $finish;
            end

        \(Simulator.createTasks(tms: tms, tdi: tdi))
        endmodule
        """

        return try Simulator.run(
            define: defineStatements,
            bench: bench,
            output: output
        )
    }

    static func simulate(
        verifying module: String,
        in file: String,
        with models: [String],
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String>,
        behavior: [Behavior],
        outputs _: [Port],
        clock: String,
        reset: String,
        resetActive: Active = .low,
        tms: String,
        tdi: String,
        tck: String,
        tdo: String,
        trst: String,
        output: String,
        chainLength _: Int,
        vecbinFile: String,
        outbinFile: String,
        vectorCount: Int,
        vectorLength: Int,
        outputLength: Int,
        defines: Set<String> = [],
        using _: String,
        with _: String
    ) throws -> Bool {
        var portWires = ""
        var portHooks = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portHooks += ".\(name) ( \(name) ) , "
        }

        var inputAssignment = ""
        for (i, rawName) in ignoredInputs.enumerated() {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            inputAssignment += "        \(name) = \(behavior[i].rawValue) ;\n"
        }

        let tapPorts = [tck, trst, tdi]
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputAssignment += "        \(name) = \(resetActive == .low ? 0 : 1) ;\n"
            } else if input.name == tms {
                inputAssignment += "        \(name) = 1 ;\n"
            } else {
                inputAssignment += "        \(name) = 0 ;\n"
                if input.name != clock, !tapPorts.contains(input.name) {}
            }
        }

        var clockCreator = ""
        if !clock.isEmpty {
            clockCreator = "always #(`CLOCK_PERIOD / 2) \(clock) = ~\(clock);"
        }
        var resetToggler = ""
        if !reset.isEmpty {
            resetToggler = "\(reset) = ~\(reset);"
        }
        var testStatements = ""
        for i in 0 ..< vectorCount {
            testStatements += "        test(\(i), __vectors__[\(i)], __gmOutput__[\(i)]) ;\n"
        }
        var includes = ""
        for model in models {
            includes += "`include \"\(model)\"\n"
        }
        includes += "`include \"\(file)\"\n"

        var defineStatements = ""
        for def in defines {
            defineStatements += "-D\(def) "
        }

        let bench = """

        \(String.boilerplate)
        \(includes)

        `ifndef CLOCK_PERIOD
            `define CLOCK_PERIOD 4
        `endif

        module testbench;
        \(portWires)

            \(clockCreator)
            always #(`CLOCK_PERIOD / 2) \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );

            integer i, __all_errors__, __error__;

            reg [\(outputLength - 1):0] __scanInSerial__;
            reg [\(vectorLength - 1):0] __vectors__ [0:\(vectorCount - 1)];
            reg [\(outputLength - 1):0] __gmOutput__ [0:\(vectorCount - 1)];

            wire[7:0] __tmsPattern__ = 8'b 01100110;
            wire[3:0] __preloadChain__ = 4'b 0011;

            wire __tdo_pad_out__ = tdo_paden_o ? 1'bz : \(tdo);

            initial begin
                `ifdef VCD
                    $dumpfile("dut.vcd"); // DEBUG
                    $dumpvars(0, testbench);
                `endif
                __all_errors__ = 0;
        \(inputAssignment)
                $readmemb("\(vecbinFile)", __vectors__);
                $readmemb("\(outbinFile)", __gmOutput__);
                #(`CLOCK_PERIOD) ;
                \(resetToggler)
                \(trst) = 1;        
                #(`CLOCK_PERIOD) ;
        \(testStatements)
                if (__all_errors__ > 0) begin
                    $error("SIMULATING_TV_FAILED");
                    $finish;
                end else begin
                    $display("SUCCESS_STRING");
                    $finish;
                end
            end

            task test;
                input [31:0] __ordinal__; // integer
                input [\(vectorLength - 1):0] __vector__;
                input [\(outputLength - 1):0] __goldenOutput__;
                begin
                    $display("Testing vector %0d...", __ordinal__);
                    // Preload Scan-Chain with TV

                    shiftIR(__preloadChain__);
                    enterShiftDR();

                    for (i = 0; i < \(vectorLength); i = i + 1) begin
                        \(tdi) = __vector__[i];
                        if (i == \(vectorLength - 3)) begin
                            \(tms) = 1; // Exit-DR
                        end
                        if (i == \(vectorLength - 2)) begin
                            \(tms) = 0; // Pause-DR
                        end
                        if (i == \(vectorLength - 1)) begin
                            \(tms) = 1; // Exit2-DR
                        end
                        #(`CLOCK_PERIOD) ;
                    end

                    \(tms) = 0; // Shift-DR
                    #(`CLOCK_PERIOD) ;
                    // Shift-out response
                    __error__ = 0;
                    for (i = 0; i< \(outputLength);i = i + 1) begin
                        \(tdi) = 0;
                        __scanInSerial__[i] = __tdo_pad_out__;
                        if (__scanInSerial__[i] !=? __goldenOutput__[i]) begin
                            $display("@%0d:\\t\\tExpected %0b, Got %0b", i, __goldenOutput__[i], __scanInSerial__[i]);
                            __error__ = __error__ + 1;
                        end
                        if(i == \(outputLength - 1)) begin
                            \(tms) = 1; // Exit-DR
                        end
                        #(`CLOCK_PERIOD) ;
                    end
                    __all_errors__ += __error__;
                    \(tms) = 1; // update-DR
                    #(`CLOCK_PERIOD) ;
                    \(tms) = 0; // run-test-idle
                    #(`CLOCK_PERIOD) ;

                    if(__scanInSerial__ !=? __goldenOutput__) begin
                        $display("Test vector simulation failed: %0d bits mismatched", __error__);
                        $display("Expected:\\t%0b", __goldenOutput__);
                        $display("Got:\\t\\t%0b", __scanInSerial__);
                    end else begin
                        $display("Passed vector %0d.", __ordinal__);
                    end
                end
            endtask

           \(Simulator.createTasks(tms: tms, tdi: tdi))
        endmodule
        """

        return try Simulator.run(
            define: defineStatements,
            bench: bench,
            output: output
        )
    }

    private static func run(
        define: String,
        bench: String,
        output: String,
        clean: Bool = true
    ) throws -> Bool {
        try File.open(output, mode: .write) {
            try $0.print(bench)
        }

        let outputLog = "\(output).log"
        print("Starting simulation steps (log: \(outputLog))…")

        guard let outputFile = File.open(outputLog, mode: .write) else {
            throw RuntimeError("Failed to open log file.")
        }

        let aoutName = "\(output).a.out"
        defer {
            if clean {
                let _ = "rm \(aoutName)".sh()
            }
        }
        let iverilogCmd = "'\(iverilogExecutable)' -B '\(iverilogBase)' \(define) -Ttyp -o \(aoutName) \(output) 2>&1"
        try outputFile.write(string: "$ \(iverilogCmd)\n")

        let iverilogResult =
            "'\(iverilogExecutable)' -B '\(iverilogBase)' \(define) -Ttyp -o \(aoutName) \(output) 2>&1".shOutput()
        try outputFile.write(string: iverilogResult.output)

        if iverilogResult.terminationStatus != EX_OK {
            throw RuntimeError("Failed to run iverilog.")
        }

        let vvpCmd = "'\(vvpExecutable)' \(aoutName)"
        try outputFile.write(string: "$ \(vvpCmd)\n")
        let vvpResult = vvpCmd.shOutput()
        try outputFile.write(string: vvpResult.output)

        if iverilogResult.terminationStatus != EX_OK {
            throw RuntimeError("Failed to run vvp.")
        }

        if vvpResult.output.contains("SUCCESS_STRING") {
            return true
        } else {
            return false
        }
    }

    private static func createTasks(tms: String, tdi: String) -> String {
        """
            task shiftIR;
                input[3:0] __instruction__;
                integer i;
                begin
                    for (i = 0; i< 5; i = i + 1) begin
                        \(tms) = __tmsPattern__[i];
                        #(`CLOCK_PERIOD) ;
                    end

                    // At shift-IR: shift new instruction on tdi line
                    for (i = 0; i < 4; i = i + 1) begin
                        \(tdi) = __instruction__[i];
                        if(i == 3) begin
                            \(tms) = __tmsPattern__[5];     // exit-ir
                        end
                        #(`CLOCK_PERIOD) ;
                    end

                    \(tms) = __tmsPattern__[6];     // update-ir 
                    #(`CLOCK_PERIOD) ;
                    \(tms) = __tmsPattern__[7];     // run test-idle
                    #(`CLOCK_PERIOD * 3) ;
                end
            endtask

            task enterShiftDR;
                begin
                    \(tms) = 1;     // select DR
                    #(`CLOCK_PERIOD) ;
                    \(tms) = 0;     // capture DR -- shift DR
                    #(`CLOCK_PERIOD * 2) ;
                end
            endtask

            task exitDR;
                begin
                    \(tms) = 1;     // Exit DR -- update DR
                    #(`CLOCK_PERIOD * 2) ;
                    \(tms) = 0;     // Run test-idle
                    #(`CLOCK_PERIOD) ;
                end
            endtask
        """
    }
}
