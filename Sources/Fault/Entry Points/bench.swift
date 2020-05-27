import Foundation
import CoreFoundation
import CommandLineKit
import PythonKit
import Defile

func bench(arguments: [String]) -> Int32 {
    // MARK: CommandLine Processing
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let cellsOption = StringOption(
        shortFlag: "c",
        longFlag: "cells",
        required: true,
        helpMessage: "Path to cell models file. (.v) files are converted to (.json). If .json is available, it could be supplied directly."
    )
    cli.addOptions(cellsOption)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .bench)"
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

    
    let output = filePath.value ?? "\(file).bench"

    var cellModelsFile: String = cellsOption.value!
    if let modelTest = cellsOption.value {
        if !fileManager.fileExists(atPath: modelTest) {
            fputs("Cell model file '\(modelTest)' not found.\n", stderr)
            return EX_NOINPUT
        }

        if modelTest.hasSuffix(".v") || modelTest.hasSuffix(".sv") {
            print("Creating json for the cell models...")
            cellModelsFile = "\(modelTest).json"

            let cellModels =
            "grep -E -- \"\\bmodule\\b|\\bendmodule\\b|and|xor|or|not(\\s+|\\()|buf|input.*;|output.*;\" \(modelTest)".shOutput();
            let pattern = "(?s)(?:module).*?(?:endmodule)"

            var cellDefinitions = ""
            if let range = cellModels.output.range(of: pattern, options: .regularExpression) {
                cellDefinitions = String(cellModels.output[range])
            }
            do {

            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(cellModels.output.startIndex..., in: cellModels.output)
            let results = regex.matches(in: cellModels.output, range: range)   
            let matches = results.map { String(cellModels.output[Range($0.range, in: cellModels.output)!])}     
            
            cellDefinitions = matches.joined(separator: "\n")

            let folderName = "\(NSTemporaryDirectory())/thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
            let result = "mkdir -p \(folderName)".sh()
            defer {
                let _ = "rm -rf \(folderName)".sh()
            }
            let CellFile = "\(folderName)/cells.v"
        
            try File.open(CellFile, mode: .write) {
                try $0.print(cellDefinitions)
            }

            // MARK: Importing Python and Pyverilog
            let parse = Python.import("pyverilog.vparser.parser").parse

            // MARK: Parse
            let ast = parse([CellFile])[0]
            let description = ast[dynamicMember: "description"]

            let cells = try BenchCircuit.extract(definitions: description.definitions)
            let circuit = BenchCircuit(cells: cells)
            let encoder = JSONEncoder()
            
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(circuit)

            guard let string = String(data: data, encoding: .utf8) else {
                throw "Could not create utf8 string."
            }

            try File.open(output, mode: .write) {
                try $0.print(string)
            }

            } catch {
                fputs("Internal error: \(error)", stderr)
                return EX_SOFTWARE
            }
        }
        else if !modelTest.hasSuffix(".json") {
            fputs(
                "Warning: Cell model file provided does not end with .v or .sv or .json.",
                stderr
            )
        }
    }
    do {
        // MARK: Processing Library Cells
        let data = try Data(contentsOf: URL(fileURLWithPath: cellModelsFile), options: .mappedIfSafe)
        guard let benchCells = try? JSONDecoder().decode(BenchCircuit.self, from: data) else {
            fputs("File '\(cellsOption.value!)' is invalid.\n", stderr)
            return EX_DATAERR
        }

        let cellsDict = benchCells.cells.reduce(into: [String: BenchCell]()) {
            $0[$1.name] = $1
        }

        // MARK: Importing Python and Pyverilog
        let parse = Python.import("pyverilog.vparser.parser").parse

        // MARK: Parse
        let ast = parse([file])[0]
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
            exit(EX_DATAERR)
        }

        let (_, inputs, outputs) = try Port.extract(from: definition)

        var benchStatements: String = ""
        for input in inputs {
            benchStatements += "INPUT(\(input.name)) \n"
        }
        for output in outputs {
            benchStatements += "OUTPUT(\(output.name)) \n"
        }

        for item in definition.items {
            
            let type = Python.type(item).__name__
            // Process gates
            if type == "InstanceList" {
                let instance = item.instances[0]
                let cellName =  String(describing: instance.module)
                let instanceName = String(describing: instance.name)
                let cell = cellsDict[cellName]!

                var inputs: [String:String] = [:]
                var outputs: [String] = []

                for hook in instance.portlist {
                    let portname = String(describing: hook.portname)

                    if  portname == cell.output {
                        outputs.append(String(describing: hook.argname))
                    }
                    else {
                        inputs[portname] = String(describing: hook.argname)
                    }
                }

                let statements = try cell.extract(name: instanceName, inputs: inputs, output: outputs)
                benchStatements += "\(statements) \n"
            }
            else if type == "Assign"{
                let right = String(describing: item.right.var)
                let left = String(describing: item.left.var)
                let statement = "\(left) = BUFF(\(right)) \n"
                benchStatements += statement                
            }
        }

        let boilerplate = """
        #    Bench for \(definition.name)
        #    Automatically generated by Fault.
        #    Don't modify.
        """
        try File.open(output, mode: .write) {
            try $0.print(boilerplate)
            try $0.print(benchStatements)
        }

    } catch {
        fputs("Internal error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    return EX_OK
}