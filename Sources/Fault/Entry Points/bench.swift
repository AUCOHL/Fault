import Foundation
import CoreFoundation
import CommandLineKit
import PythonKit
import Defile
import OrderedDictionary

func bench(arguments: [String]) -> Int32 {
    // MARK: CommandLine Processing
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

    let output = filePath.value ?? "\(file).json"

    do {
        let cellModels =
            "grep -E -- \"module|endmodule|and|*or|not |buf|^input|^output\" \(file)".shOutput();
    
        let folderName = "./thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        let result = "mkdir -p \(folderName)".sh()
        defer {
            let _ = "rm -rf \(folderName)".sh()
        }
        let cellFile = "\(folderName)/cells.v"
        print(cellModels.output)
        try File.open(cellFile, mode: .write) {
            try $0.print(cellModels.output)
        }

        // MARK: Importing Python and Pyverilog
    
        let parse = Python.import("pyverilog.vparser.parser").parse

        let Node = Python.import("pyverilog.vparser.ast")

        let Generator =
            Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

        var cellsDict: [String: [String]] = [:]

        // // MARK: Parse
        let ast = parse([cellFile])[0]
        let description = ast[dynamicMember: "description"]
        var definitionOptional: PythonObject?
        var template: String = ""
        var cells: [BenchCell] = []
        for definition in description.definitions {
            let type = Python.type(definition).__name__
            if type == "ModuleDef" {
                definitionOptional = definition
                // process the definition for each cell
                let (_, inputs, outputs) = try Port.extract(from: definition)
                let cellName = definition.name
                var benchStatements: String = ""
                var cellOutput: String = ""
                var cellInputs: [String] = []
                var cellStatements: [String] = []
                for output in outputs {
                    cellOutput = String(describing: output.name)
                }
                for input in inputs {
                    cellInputs.append(String(describing: input.name))
                }
                for item in definition.items {
                    let type = Python.type(item).__name__
                    if type == "InstanceList" {
                        let instance = item.instances[0]
                        var benchStatement = "("
                        let output = String(describing: instance.portlist[0].argname)
                        for hook in instance.portlist[1...]{
                            benchStatement += "\(hook.argname), "
                        }
                        benchStatement = String(benchStatement.dropLast(2))
                        benchStatement += ")"
                        switch instance.module {
                        case "and":
                            cellStatements.append("\(output) = AND" + benchStatement)
                            break
                        case "or":
                            cellStatements.append("\(output) = OR" + benchStatement)
                            break
                        case "xor":
                            let inputA = instance.portlist[1].argname
                            let inputB = instance.portlist[2].argname
                            cellStatements.append(contentsOf: [
                                "or_out = OR(\(inputA), \(inputB))",
                                "nand_out = NAND(\(inputA), \(inputB))",
                                "\(output) = AND(or_out, nand_out)"
                            ])
                            print(cellStatements)
                            break
                        case "buf":
                            cellStatements.append("\(output) = BUFF" + benchStatement)
                            break
                        case "not":
                            cellStatements.append("\(output) = NOT" + benchStatement)
                            break
                        default:
                            print(instance.module)
                        }
                        benchStatements += """
                        \(benchStatement) \n
                        """ 
                        //cellStatements.append(benchStatement)
                    }
                }
                template += """
                \(cellName):
                \(benchStatements)
                """ 
                let cell = BenchCell(
                    name: String(cellName)!,
                    inputs: cellInputs,
                    output: cellOutput,
                    statements: cellStatements
                )
                cells.append(cell)
            }
          
        }

        guard let definition = definitionOptional else {
            fputs("No module found.\n", stderr)
            exit(EX_DATAERR)
        }
        let circuit = BenchCircuit(cells: cells)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(circuit)
        guard let string = String(data: data, encoding: .utf8)
        else {
            throw "Could not create utf8 string."
        }

        try File.open(output, mode: .write) {
            try $0.print(string)
        }
        try File.open("\(output).bench", mode: .write) {
            try $0.print(template)
        }
    } catch {
        fputs("Internal error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    

    return EX_OK
}

struct BenchCircuit: Codable {
    var cells: [BenchCell]
    init(
        cells: [BenchCell]
    ){
        self.cells = cells
    }
}

struct BenchCell: Codable {
    var name: String
    var inputs: [String]
    var output: String
    var statements: [String]
    init(
        name: String,
        inputs: [String],
        output: String,
        statements: [String]
    ){
        self.name = name
        self.inputs = inputs
        self.output = output
        self.statements = statements
    }
}