import Foundation
import CommandLineKit
import Defile
import PythonKit

func compactTestVectors(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .compacted.json)"
    )
    cli.addOptions(filePath)

    let verifyOpt = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: "Verify compaction using given cell model."
    )
    cli.addOptions(verifyOpt)

    let netlistOpt = StringOption(
        shortFlag: "n",
        longFlag: "netlist",
        helpMessage: "Verify compaction for the given netlist. "
    )
    cli.addOptions(netlistOpt)

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
        guard let _ = netlistOpt.value else {
            fputs("Error: The netlist must be provided to verify compaciton \n",stderr)
            return EX_NOINPUT
        }
    }

    if let netlistTest = netlistOpt.value {
        if !fileManager.fileExists(atPath: netlistTest) {
            fputs("Netlist file '\(netlistTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        guard let _ = verifyOpt.value else {
            fputs("Error: The cell models file  must be provided to verify compaciton \n",stderr)
            return EX_NOINPUT
        }
    }

    let output = filePath.value ?? "\(file).compacted.json"
    // Parse JSON File
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        guard let tvInfo = try? JSONDecoder().decode(TVInfo.self, from: data) else {
            fputs("File '\(file)' is invalid.\n", stderr)
            return EX_DATAERR
        }

        let compactedTV = Compactor.compact(coverageList: tvInfo.coverageList)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(
            TVInfo(
                inputs: tvInfo.inputs,
                coverageList: compactedTV
            )
        )

        guard let string = String(data: jsonData, encoding: .utf8) else {
            throw "Could not create utf8 string."
        }

        try File.open(output, mode: .write) {
            try $0.print(string)
        }
        
        if let modelTest = verifyOpt.value {
            print("Running simulations using the compacted set...")
            let netlist = "Netlists/s27.netlist.v.cut.v" //String(file.dropLast(8))
            let verifiedOutput = "\(output).verified.json"
            let mainArguments: [String] = [
                arguments[0].components(separatedBy: " ")[0],
                "-c", modelTest,
                "-r", "10",
                "-v", "10",
                "--tvSet", output,
                "-o", verifiedOutput,
                netlist
            ]
            exit(main(arguments: mainArguments))
        } 
    } catch {
        fputs(error.localizedDescription, stderr)
        return EX_NOINPUT
    }

    return EX_OK
}