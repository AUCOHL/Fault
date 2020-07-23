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

    let vectorOutput = filePath.value ?? json + ".vec.bin"
    let goldenOutput = filePath.value ?? json + ".out.bin"

    guard let jsonString = File.read(json) else {
        fputs("Could not read file '\(json)'\n", stderr)
        return EX_NOINPUT
    }

    let decoder = JSONDecoder()
    guard let tvinfo = try? decoder.decode(TVInfo.self, from: jsonString.data(using: .utf8)!) else {
        fputs("Test vector json file is invalid.\n", stderr)
        return EX_DATAERR
    }

    let (chain, _, _) = ChainMetadata.extract(file: netlist)

    let order = chain.filter{ $0.kind != .output }
    let orderSorted = order.sorted(by: { $0.ordinal < $1.ordinal})

    let orderOutput = chain.filter{ $0.kind != .input }
    let outputSorted = orderOutput.sorted(by: { $0.ordinal < $1.ordinal })

    let jsInputOrder = tvinfo.inputs.filter{ $0.polarity != .output }
    let jsOutputOrder = tvinfo.inputs.filter{ $0.polarity != .input }

    var inputMap: [String: Int] = [:]
    var outputMap: [String: Int] = [:]

    // Check input order 
    let chainOrder = orderSorted.filter{ $0.kind != .bypassInput }

    if chainOrder.count != jsInputOrder.count {
        print("[Error]: Ordinal mismatch between TV and scan-chains.")
        return EX_DATAERR
    }

    for (i, input) in jsInputOrder.enumerated() {
        inputMap[input.name] = i
        if chainOrder[i].name != input.name {
            print("[Error]: Ordinal mismatch between TV input \(input.name) and scan-chain register \(chainOrder[i].name).")
            return EX_DATAERR
        }
    }

    for (i, output) in jsOutputOrder.enumerated() {
        var name = (output.name.hasPrefix("\\")) ? String(output.name.dropFirst(1)): output.name
        name = name.hasSuffix(".q") ? String(name.dropLast(2)): name
        outputMap[name] = i
    }

    var outputDecimal: [[BigUInt]] = []
    for tvcPair in tvinfo.coverageList {
        var pointer = 0
        var list: [BigUInt] = []
        let outputBinary = tvcPair.goldenOutput.reversed()
        for (i, output) in jsOutputOrder.enumerated() {
            let start = outputBinary.index(outputBinary.startIndex, offsetBy: pointer)
            let end = outputBinary.index(start, offsetBy: output.width)
            let value = String(outputBinary[start..<end])
            list.append(BigUInt(value, radix: 2)!)
            pointer += output.width
        }
        outputDecimal.append(list)
    }

    var outputLength: Int = 0 
    for (i, output) in outputSorted.enumerated() {
        if output.kind == .bypassOutput {
            print("Bypassing \(outputSorted[i].name)")
        } 
        outputLength += output.width
    }

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

    var binFileVec = "// test-vector \n"
    var binFileOut = "// fault-free-response \n"
    for (i, tvcPair) in tvinfo.coverageList.enumerated() {
        var binaryString = ""
        for element in orderSorted {
            var value: BigUInt = 0
            if let locus = inputMap[element.name] {
                value = tvcPair.vector[locus]
            } else {
                if element.kind == .bypassInput {
                    print("Padded with zeros: ", element.name)
                    value = 0 
                } else {
                    print("Chain register \(element.name) not found in the TVs.")
                    return EX_DATAERR
                }
            }
            binaryString += pad(value, digits: element.width, radix: 2).reversed()
        } 
        var outputBinary = ""
        for (j, element) in orderOutput.enumerated() {
            var value: BigUInt = 0
            if let locus = outputMap[element.name] {  
                value = outputDecimal[i][locus]
                outputBinary += pad(value, digits: element.width, radix: 2)
            } else {
                if element.kind == .bypassOutput {
                    // guard let vectorLocus = inputMap[element.name] else {
                    //     print("[Error]: Blackbox module outptut port \(element.name) not found in .json. ")
                    //     return EX_DATAERR
                    // }
                    // value = tvcPair.vector[vectorLocus]
                    outputBinary += String(repeating: "x", count: element.width)
                    print("Output is same as the loaded TV")
                } else {
                    print("[Error]: Mismatch between output port \(element.name) and chained netlist. ")
                    return EX_DATAERR
                }
            }
        }
        binFileVec += binaryString + "\n"
        binFileOut += outputBinary + " \n"
    }

    let vectorCount = tvinfo.coverageList.count
    let vectorLength = order.map{ $0.width }.reduce(0, +)

    let vecMetadata = binMetadata(count: vectorCount, length: vectorLength)
    let outMetadata = binMetadata(count: vectorCount, length: outputLength)

    guard let vecMetadataString = vecMetadata.toJSON() else {
        fputs("Could not generate metadata string.", stderr)
        return EX_SOFTWARE
    }
    guard let outMetadataString = outMetadata.toJSON() else {
        fputs("Could not generate metadata string.", stderr)
        return EX_SOFTWARE
    }
    do {
        try File.open(vectorOutput, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print("/* FAULT METADATA: '\(vecMetadataString)' END FAULT METADATA */")
            try $0.print(binFileVec, terminator: "")
        }  
        try File.open(goldenOutput, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print("/* FAULT METADATA: '\(outMetadataString)' END FAULT METADATA */")
            try $0.print(binFileOut, terminator: "")
        } 
    } catch {
        fputs("Could not access file \(vectorOutput) or \(goldenOutput)", stderr)
        return EX_CANTCREAT
    }

    return EX_OK
}