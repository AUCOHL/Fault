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
        let jsonData = try encoder.encode(
            TVInfo(
                inputs: tvInfo.inputs,
                coverageList: compactedTV
            )
        )

        guard let string = String(data: jsonData, encoding: .utf8)
        else {
            throw "Could not create utf8 string."
        }

        try File.open(output, mode: .write) {
            try $0.print(string)
        }

    } catch {
        fputs(error.localizedDescription, stderr)
        return EX_NOINPUT
    }

    return EX_OK
}