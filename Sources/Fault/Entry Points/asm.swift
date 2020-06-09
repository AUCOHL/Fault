import Foundation
import CommandLineKit
import PythonKit
import Defile
import BigInt

func assemble(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let usage = {
        print("Arguments: <.json> <.v> (any order).")
        cli.printUsage()
    }

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: <json input> + .bin)"
    )
    cli.addOptions(filePath)

    do {
        try cli.parse()
    } catch {
        usage()
        return EX_USAGE
    }

    if help.value {
        usage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 2 {
        usage()
        return EX_USAGE
    }

    let jsonArgs = args.filter { $0.hasSuffix(".json") }
    let vArgs = args.filter { $0.hasSuffix(".v") }

    if jsonArgs.count != 1 || vArgs.count != 1 {
        usage()
        return EX_USAGE        
    }

    let json = jsonArgs[0]
    let netlist = vArgs[0]

    let output = filePath.value ?? json + ".bin"

    guard let jsonString = File.read(json) else {
        fputs("Could not read file '\(json)'\n", stderr)
        return EX_NOINPUT
    }

    let decoder = JSONDecoder()
    guard let tvinfo = try? decoder.decode(TVInfo.self, from: jsonString.data(using: .utf8)!) else {
        fputs("Test vector json file is invalid.\n", stderr)
        return EX_DATAERR
    }

    guard let netlistString = File.read(netlist) else {
        fputs("Could not read file '\(netlist)'\n", stderr)
        return EX_NOINPUT
    }

    if !netlistString.contains("/* FAULT METADATA: '") {
        fputs("Netlist does not contain fault metadata.\n", stderr)
        return EX_NOINPUT
    }
    let slice = netlistString.components(separatedBy: "/* FAULT METADATA: '")[1]
    if !slice.contains("' END FAULT METADATA */") {
        fputs("Fault metadata not terminated.\n", stderr)
        return EX_NOINPUT
    }

    let metadataString = slice.components(separatedBy: "' END FAULT METADATA */")[0]
    guard let metadata = try? decoder.decode(Metadata.self, from: metadataString.data(using: .utf8)!) else {
        fputs("Metadata json is invalid.\n", stderr)
        return EX_DATAERR
    }

    let order = metadata.order 
    let inputOrder = tvinfo.inputs
    var inputMap: [String: Int] = [:]

    for (i, input) in inputOrder.enumerated() {
        inputMap[input.name] = i
    }

    let vectors = tvinfo.coverageList.map { $0.vector }

    func pad(_ number: BigUInt, digits: Int, radix: Int) -> String {
        var padded = String(number, radix: radix)
        let length = padded.count
        if digits > length {
            for _ in 0..<(digits - length) {
                padded = "0" + padded
            }
        }
        return padded
    }

    var binFile = ""

    for vector in vectors {
        var binaryString = ""
        for element in order {
            var value: BigUInt = 0
            if let locus = inputMap[element.name] {
                value = vector[locus]
            }
            binaryString += pad(value, digits: element.width, radix: 2)
        }
        binFile += binaryString + "\n"
    }

    do {
        try File.open(output, mode: .write) {
            try $0.print(binFile, terminator: "")
        }   
    } catch {
        fputs("Could not access file \(output)", stderr)
        return EX_CANTCREAT
    }
    return EX_OK
}