import Foundation
import CommandLineKit
import PythonKit
import Defile

func simulate(arguments: [String]) -> Int32{
    let env = ProcessInfo.processInfo.environment

    let cli = CommandLineKit.CommandLine(arguments: arguments)
    print(arguments)
    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .sv)"
    )
    cli.addOptions(filePath)

    let verifyOpt = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: "Verify JTAG port using given cell model."
    )
    cli.addOptions(verifyOpt)

    let clockOpt = StringOption(
        longFlag: "clock",
        helpMessage: "Clock signal of core logic to use in simulation"
    )
    cli.addOptions(clockOpt)

    let resetOpt = StringOption(
        longFlag: "reset",
        helpMessage: "Reset signal of core logic to use in simulation."
    )
    cli.addOptions(resetOpt)

    let resetActiveLow = BoolOption(
        longFlag: "activeLow",
        helpMessage: "Reset signal of core logic is active low instead of active high."
    )
    cli.addOptions(resetActiveLow)

    let testvectors = StringOption(
        shortFlag: "t",
        longFlag: "testVectors",
        helpMessage: 
            " .bin file for test vectors."
    )
    cli.addOptions(testvectors)

    let goldenOutput = StringOption(
        shortFlag: "g",
        longFlag: "goldenOutput",
        helpMessage: 
            " .bin file for golden output."
    )
    cli.addOptions(goldenOutput)

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs,to,ignore,separated,by,commas. (Default: none)"
    )
    cli.addOptions(ignored)

    var names: [String: (default: String, option: StringOption)] = [:]
    for (name, value) in [
        ("tms", "JTAG test mode select"),
        ("tck", "JTAG test clock"),
        ("tdi", "JTAG test data input"),
        ("tdo", "JTAG test data output"),
        ("trst", "JTAG test reset (active low)")
    ] {
        let option = StringOption(
            longFlag: name,
            helpMessage: "Name for \(value) signal. (Default: \(name).)"
        )
        cli.addOptions(option)
        names[name] = (default: name, option: option)
    }

    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        return EX_USAGE
    }

    if help.value {
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        fputs("File '\(file)' not found.\n", stderr)
        return EX_NOINPUT
    }
    print("here")
    let (type, chains) = ChainMetadata.extract(file: file)  

    let ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])
    let behavior
        = Array<Simulator.Behavior>(
            repeating: .holdHigh,
            count: ignoredInputs.count
        )

    var ignoredCount = ignoredInputs.count
    if let _ = clockOpt.value {
        ignoredCount += 1
    }
    if let _ = resetOpt.value {
        ignoredCount += 1
    }

    if let modelTest = verifyOpt.value {
        if !fileManager.fileExists(atPath: modelTest) {
            fputs("Cell model file '\(modelTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !modelTest.hasSuffix(".v") && !modelTest.hasSuffix(".sv") {
            fputs(
                "Warning: Cell model file provided does not end with .v or .sv.\n",
                stderr
            )
        }
    }

    if let tvTest = testvectors.value {
        if !fileManager.fileExists(atPath: tvTest) {
            fputs("Test vectors file '\(tvTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !tvTest.hasSuffix(".bin") {
            fputs(
                "Warning: Test vectors file provided does not end with .bin. \n",
                stderr
            )
        }
        guard let _ = goldenOutput.value else {
            fputs("Using goldenOutput (-g) option is required '\(tvTest)'.\n", stderr)
            return EX_NOINPUT
        }
    }

    let output = filePath.value ?? "\(file).sv"

      let tmsName = names["tms"]!.option.value 
        ?? names["tms"]!.default
    let tdiName = names["tdi"]!.option.value 
        ?? names["tdi"]!.default
    let tdoName = names["tdo"]!.option.value 
        ?? names["tdo"]!.default
    let tckName = names["tck"]!.option.value 
        ?? names["tck"]!.default
    let trstName = names["trst"]!.option.value 
        ?? names["trst"]!.default
    
    let clockName = clockOpt.value ?? ""
    let resetName = resetOpt.value ?? ""
    let model = verifyOpt.value!
    let tvFile = testvectors.value!

    // MARK: Importing Python and Pyverilog
    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    // MARK: Parse
    let ast = parse([args[0]])[0]
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
        fputs("No module found.\n", stderr)
        return EX_DATAERR
    }
    let definitionName = String(describing: definition.name)

    do {
        print("Generating testbench for test vectors...")
        let (vectorCount, vectorLength) = binMetadata.extract(file: tvFile)
        let (_, outputLength) = binMetadata.extract(file: goldenOutput.value!)
        let testbecnh = (filePath.value ?? file) + ".tb.sv"
        let (ports, inputs, outputs) = try Port.extract(from: definition)

        let verified = try Simulator.simulate(
            verifying: definitionName,
            in: output, // DEBUG
            with: model,
            ports: ports,
            inputs: inputs,
            ignoring: ignoredInputs,
            behavior: behavior,
            outputs: outputs,
            clock: clockName,
            reset: resetName,
            resetActive: resetActiveLow.value ? .low : .high,
            tms: tmsName,
            tdi: tdiName,
            tck: tckName,
            tdo: tdoName,
            trst: trstName,
            output: testbecnh,
            chains: chains, 
            vecbinFile: testvectors.value!,
            outbinFile: goldenOutput.value!,
            vectorCount: vectorCount,
            vectorLength: vectorLength,
            outputLength: outputLength,
            using: iverilogExecutable,
            with: vvpExecutable
        )
        print("Done.")
        if (verified) {
            print("Test vectors verified successfully.")
        } else {
            print("Test vector simulation failed.")
        }  
    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    return EX_OK

}