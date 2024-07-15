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
import Collections
import ArgumentParser
import CoreFoundation // Not automatically imported on Linux
import Defile
import Foundation
import PythonKit
import Yams


extension Fault {
    struct ATPG: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate/import test vectors for a particular circuit and calculate coverage."
        )
        
        @Option(name: [.short, .long], help: "Path to the output JSON file. (Default: input + .tv.json)")
        var output: String?
        
        @Option(help: "Path to the output SVF file. (Default: input + .tv.svf)")
        var outputSvf: String?
        
        @Option(name: [.long, .customLong("output-faultPoints")], help: "Path to the output yml file listing all generated fault points. (Default: nil)")
        var outputFaultPoints: String?
        
        @Option(name: [.long, .customLong("output-covered")], help: "Path to the output yml file listing coverage metadata, i.e., ratio and fault points covered. (Default: nil)")
        var outputCoverageMetadata: String?
        
        @Option(name: [.short, .long, .customLong("cellModel")], help: "A Verilog model with which standard cells can be simulated.")
        var cellModel: String
        
        @Option(name: [.customShort("v"), .long], help: "Number of test vectors to generate in the first batch.")
        var tvCount: Int = 100
        
        @Option(name: [.customShort("r"), .long], help: "Increment in test vector count in subsequent batches should sufficient coverage not be reached.")
        var increment: Int = 50
        
        @Option(name: [.short, .long], help: "The minimum coverage to reach before ceasing increments. If set to 0, only the initial batch is run.")
        var minCoverage: Float = 80
        
        @Option(help: "Ceiling for Test Vector increments: if this number is reached, no more increments will occur regardless the coverage.")
        var ceiling: Int?
        
        @Option(help: "Type of the pseudo-random internal test-vector-generator.")
        var tvGen: String = "swift"
        
        @Option(help: "A \(MemoryLayout<UInt>.size)-byte value to use as an RNG seed for test vector generators, provided as a hexadecimal string (without 0x).")
        var rngSeed: String = "DEADCAFEDEADF00D"
        
        @Option(name: [.customShort("g"), .long], help: "Use an external TV Generator: Atalanta or PODEM.")
        var etvGen: String?
        
        @Option(name: [.short, .long], help: "Netlist in bench format. (Required iff generator is set to Atalanta or PODEM.)")
        var bench: String?
    
        @Flag(help: "Generate only one testbench for inspection, and do not delete it.")
        var sampleRun: Bool = false
        
        @OptionGroup
        var bypass: BypassOptions
        
        @Option(help: "If provided, this JSON file's test vectors are simulated and no generation is attempted.")
        var externalTVSet: String?
        
        @Option(help: "If provided, this JSON file's test vector are used as the initial set of test vectors, with iterations taking place with them in mind.")
        var iteratingUpon: String?
        
        @Option(name: [.customShort("D"), .customLong("define")], help: "Define statements to include during simulations.")
        var defines: [String] = []
        
        @Option(name: [.customShort("I"), .customLong("include")], help: "Extra verilog models to include during simulations.")
        var includes: [String] = []
        
        @Argument(help: "The cutaway netlist to generate patterns for.")
        var file: String
        
        mutating func run() throws {
            
            if !TVGeneratorFactory.validNames.contains(tvGen) {
                throw ValidationError("Invalid test-vector generator \(tvGen).")
            }
            
            let fileManager = FileManager()
            guard fileManager.fileExists(atPath: file) else {
                throw ValidationError("File '\(file)' not found.")
            }
            
            guard fileManager.fileExists(atPath: cellModel) else {
                throw ValidationError("Cell model file '\(cellModel)' not found.")
            }
            
            if !cellModel.hasSuffix(".v"), !cellModel.hasSuffix(".sv") {
                Stderr.print(
                    "Warning: Cell model file provided does not end with .v or .sv."
                )
            }

            let jsonOutput = output ?? file.replacingExtension(".cut.v", with: ".tv.json")
            let svfOutput = outputSvf ?? file.replacingExtension(".cut.v", with: ".tv.svf")
            
            // MARK: Importing Python and Pyverilog

            let parse = Python.import("pyverilog.vparser.parser").parse

            // MARK: Parsing and Processing

            let parseResult = parse([file])
            let ast = parseResult[0]
            let description = ast[dynamicMember: "description"]
            var definitionOptional: PythonObject?

            for definition in description.definitions {
                let type = Python.type(definition).__name__
                if type == "ModuleDef" {
                    definitionOptional = definition
                    break
                }
            }

            guard let definition = definitionOptional else {
                Stderr.print("No module found.")
                Foundation.exit(EX_DATAERR)
            }

            print("Processing module \(definition.name)…")

            // MARK: TV Generation Mode Selection

            var etvSetVectors: [TestVector] = []
            var etvSetInputs: [Port] = []

            if let tvSetTest = externalTVSet {
                if !fileManager.fileExists(atPath: tvSetTest) {
                    throw ValidationError("TVs JSON file '\(tvSetTest)' not found.")
                }
                if tvSetTest.hasSuffix(".json") {
                    (etvSetVectors, etvSetInputs) = try TVSet.readFromJson(file: tvSetTest)
                } else {
                    (etvSetVectors, etvSetInputs) = try TVSet.readFromText(file: tvSetTest)
                }
                print("Read \(etvSetVectors.count) externally-generated vectors to verify.")
            }

            if let tvGenerator = etvGen, ETVGFactory.validNames.contains(tvGenerator) {
                let etvgen = ETVGFactory.get(name: tvGenerator)!
                let benchUnwrapped = bench! // Program exits if etvGen.value isn't nil and bench.value is or vice versa

                if !fileManager.fileExists(atPath: benchUnwrapped) {
                    throw ValidationError("Bench file '\(benchUnwrapped)' not found.")
                }
                (etvSetVectors, etvSetInputs) = etvgen.generate(file: benchUnwrapped, module: "\(definition.name)")

                if etvSetVectors.count == 0 {
                    Stderr.print("Bench netlist appears invalid (no vectors generated). Are you sure there are no floating nets/outputs?")
                    Foundation.exit(EX_DATAERR)
                } else {
                    print("Generated \(etvSetVectors.count) test vectors using external utilties to verify.")
                }
            }

            let tvMinimumCoverage = minCoverage / 100
            let finalTvCeiling: Int = ceiling ?? (
                    etvSetVectors.count == 0 ?
                        1000 :
                        etvSetVectors.count
            )
            
            let finalRNGSeed = UInt(rngSeed, radix: 16)!

            do {
                let (ports, inputs, outputs) = try Port.extract(from: definition)

                if inputs.count == 0 {
                    print("Module has no inputs.")
                    Foundation.exit(EX_OK)
                }
                if outputs.count == 0 {
                    print("Module has no outputs.")
                    Foundation.exit(EX_OK)
                }

                // MARK: Discover fault points

                var faultPoints: Set<String> = []
                var gateCount = 0
                var inputsMinusIgnored: [Port] = []
                if etvSetVectors.count == 0 {
                    inputsMinusIgnored = inputs.filter {
                        !bypass.bypassedInputs.contains($0.name)
                    }
                } else {
                    etvSetInputs.sort { $0.ordinal < $1.ordinal }
                    inputsMinusIgnored = etvSetInputs.filter {
                        !bypass.bypassedInputs.contains($0.name)
                    }
                }

                for (_, port) in ports {
                    if bypass.bypassedInputs.contains(port.name) {
                        continue
                    }
                    if port.width == 1 {
                        faultPoints.insert(port.name)
                    } else {
                        let minimum = min(port.from, port.to)
                        let maximum = max(port.from, port.to)
                        for i in minimum ... maximum {
                            faultPoints.insert("\(port.name) [\(i)]")
                        }
                    }
                }

                var warnAboutDFF = false

                for itemDeclaration in definition.items {
                    let type = Python.type(itemDeclaration).__name__

                    // Process gates
                    if type == "InstanceList" {
                        gateCount += 1
                        let instance = itemDeclaration.instances[0]
                        if String(describing: instance.module).starts(with: "DFF") {
                            warnAboutDFF = true
                        }
                        for hook in instance.portlist {
                            faultPoints.insert("\(instance.name).\(hook.portname)")
                        }
                    }
                }

                if warnAboutDFF {
                    print("Warning: D-flipflops were found in this netlist. Are you sure you ran it through 'fault cut'?")
                }

                print("Found \(faultPoints.count) fault sites in \(gateCount) gates and \(ports.count) ports.")

                // MARK: Load Initial Set

                var initialTVInfo: TVInfo? = nil
                if let startingTVSet = iteratingUpon {
                    let loadedInitialTVInfo = try TVInfo.fromJSON(file: startingTVSet)
                    print("Loaded \(loadedInitialTVInfo.coverageList.count) initial test vectors.")
                    initialTVInfo = loadedInitialTVInfo
                }

                // MARK: Simulation

                let startTime = CFAbsoluteTimeGetCurrent()

                let models = [cellModel] + includes

                print("Performing simulations…")
                let result = try Simulator.simulate(
                    for: faultPoints,
                    in: file,
                    module: "\(definition.name)",
                    with: models,
                    ports: ports,
                    inputs: inputsMinusIgnored,
                    bypassingWithBehavior: bypass.simulationValues,
                    outputs: outputs,
                    initialVectorCount: tvCount,
                    incrementingBy: increment,
                    minimumCoverage: tvMinimumCoverage,
                    ceiling: finalTvCeiling,
                    tvGenerator: TVGeneratorFactory.get(name: tvGen)!,
                    rngSeed: finalRNGSeed,
                    initialTVInfo: initialTVInfo,
                    externalTestVectors: etvSetVectors,
                    sampleRun: sampleRun,
                    clock: bypass.clock,
                    defines: Set(defines),
                    using: iverilogExecutable,
                    with: vvpExecutable
                )

                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("Time elapsed: \(String(format: "%.2f", timeElapsed))s.")

                print("Simulations concluded: Coverage \(result.coverageMeta.ratio * 100)%")

                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let rawTVInfo = TVInfo(
                    inputs: inputsMinusIgnored,
                    outputs: outputs,
                    coverageList: result.coverageList
                )
                let jsonRawOutput = jsonOutput.replacingExtension(".tv.json", with: ".raw_tv.json")
                
                print("Writing raw generated test vectors in Fault JSON format to \(jsonOutput)…")
                try encoder.encode(rawTVInfo).write(to: URL(fileURLWithPath: jsonRawOutput))
                
                let tvInfo = TVInfo(
                    inputs: inputsMinusIgnored,
                    outputs: outputs,
                    coverageList: Compactor.compact(coverageList: result.coverageList)
                )
                print("Writing compacted generated test vectors in Fault JSON format to \(jsonOutput)…")
                try encoder.encode(tvInfo).write(to: URL(fileURLWithPath: jsonOutput))

                // try File.open(svfOutput, mode: .write) {
                //     print("Writing generated test vectors in SVF format to \(svfOutput)…")
                //     try $0.print(try SerialVectorCreator.create(tvInfo: tvInfo))
                // }

                if let coverageMetaFilePath = outputCoverageMetadata {
                    print("Writing YAML file of final coverage metadata to \(coverageMetaFilePath)…")
                    try File.open(coverageMetaFilePath, mode: .write) {
                        try $0.write(string: YAMLEncoder().encode(result.coverageMeta))
                    }
                }

            } catch {
                Stderr.print("Internal error: \(error)")
                Foundation.exit(EX_SOFTWARE)
            }
        }
    }
}
