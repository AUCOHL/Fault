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
        helpMessage: "Path to the output vector file. (Default: <json input> + .vec.bin)"
    )
    cli.addOptions(filePath)


    let goldenFilePath = StringOption(
        shortFlag: "O",
        longFlag: "goldenOutput",
        helpMessage: "Path to the golden output file. (Default: <json input> + .out.bin)"
    )
    cli.addOptions(goldenFilePath)

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
    let jsonArgs = args.filter { $0.hasSuffix(".json") }
    let vArgs = args.filter { $0.hasSuffix(".v") }

    if jsonArgs.count != 1 || vArgs.count != 1 {
        Stderr.print("fault asm requires exactly one .json argument and one .v argument.")
        Stderr.print("Invoke fault asm --help for more info.")
        return EX_USAGE        
    }

    let json = jsonArgs[0]
    let netlist = vArgs[0]

    let vectorOutput = filePath.value ?? "\(json).vec.bin"
    let goldenOutput = goldenFilePath.value ?? "\(json).out.bin"

    guard let jsonString = File.read(json) else {
        Stderr.print("Could not read file '\(json)'")
        return EX_NOINPUT
    }

    let decoder = JSONDecoder()
    guard let tvinfo = try? decoder.decode(TVInfo.self, from: jsonString.data(using: .utf8)!) else {
        Stderr.print("Test vector json file is invalid.")
        return EX_DATAERR
    }

    let (chain, _, _) = ChainMetadata.extract(file: netlist)

    let order = chain.filter{ $0.kind != .output }
    let orderSorted = order.sorted(by: { $0.ordinal < $1.ordinal})

    let orderOutput = chain.filter{ $0.kind != .input }
    let outputSorted = orderOutput.sorted(by: { $0.ordinal < $1.ordinal })

    let jsInputOrder = tvinfo.inputs
    let jsOutputOrder = tvinfo.outputs

    var inputMap: [String: Int] = [:]
    var outputMap: [String: Int] = [:]

    // Check input order 
    let chainOrder = orderSorted.filter{ $0.kind != .bypassInput }

    if chainOrder.count != jsInputOrder.count {
        print("[Error]: number of inputs in the json \(jsInputOrder.count) doesn't equal to the scan-chain registers \(chainOrder.count).")
        print("Make sure you ignored clock & reset signals in the TV generation.")
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

    var jsOutputLength = 0
    for output in jsOutputOrder {
        jsOutputLength += output.width
    }

    var outputDecimal: [[BigUInt]] = []
    for tvcPair in tvinfo.coverageList {
        guard let hex = BigUInt(tvcPair.goldenOutput, radix: 16) else {
            print("Invalid json. Golden output must be in hex format.")
            return EX_DATAERR
        }
        var pointer = 0
        var list: [BigUInt] = []
        let binFromhex =  String(hex, radix: 2)
        let padLength = jsOutputLength - binFromhex.count
        let outputBinary = (String(repeating: "0", count: padLength) + binFromhex).reversed()
        for output in jsOutputOrder{
            let start = outputBinary.index(outputBinary.startIndex, offsetBy: pointer)
            let end = outputBinary.index(start, offsetBy: output.width)
            let value = String(outputBinary[start..<end])
            list.append(BigUInt(value, radix: 2)!)
            pointer += output.width
        }
        outputDecimal.append(list)
    }

    var outputLength: Int = 0 
    for output in outputSorted {
        outputLength += output.width
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
                    value = 0 
                } else {
                    print("Chain register \(element.name) not found in the TVs.")
                    return EX_DATAERR
                }
            }
            binaryString += pad(value, digits: element.width, radix: 2).reversed()
        } 
        var outputBinary = ""
        for element in orderOutput {
            var value: BigUInt = 0
            if let locus = outputMap[element.name] {  
                value = outputDecimal[i][locus]
                outputBinary += pad(value, digits: element.width, radix: 2)
            } else {
                if element.kind == .bypassOutput {
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
        Stderr.print("Could not generate metadata string.")
        return EX_SOFTWARE
    }
    guard let outMetadataString = outMetadata.toJSON() else {
        Stderr.print("Could not generate metadata string.")
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
        Stderr.print("Could not access file \(vectorOutput) or \(goldenOutput)")
        return EX_CANTCREAT
    }

    return EX_OK
}