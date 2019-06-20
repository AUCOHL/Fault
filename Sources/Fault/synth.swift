import Foundation
import CommandLineKit
import PythonKit
import Defile

enum Gate: String {
    case and = "AND"
    case nand = "NAND"
    case or = "OR"
    case nor = "NOR"
    case xnor = "XNOR"
    case andnot = "ANDNOT"
    case ornot = "ORNOT"
    case mux = "MUX"
    case aoi3 = "AOI3"
    case oai3 = "OAI3"
    case aoi4 = "AOI4"
    case oai4 = "OAI4"
}

fileprivate func createScript(for module: String, in file: String, cutting: Bool = false, liberty libertyFile: String, output: String, optimize: Bool = true) -> String {
    let opt = optimize ? "opt" : ""
    return """
    read_verilog \(file)

    # check design hierarchy
    hierarchy -top \(module)

    # translate processes (always blocks)
    proc; \(opt)

    # detect and optimize FSM encodings
    fsm; \(opt)

    # implement memories (arrays)
    memory; \(opt)

    # convert to gate logic
    techmap; \(opt)

    # expose dff
    \(cutting ? "expose -cut -evert-dff; \(opt)" : "")

    # flatten
    flatten; \(opt)

    # mapping flip-flops to mycells.lib
    dfflibmap -liberty \(libertyFile)

    # mapping logic to mycells.lib
    abc -liberty \(libertyFile)

    # cleanup
    opt_clean -purge

    write_verilog -noattr -noexpr \(output)
    """
}

func synth(arguments: [String]) {
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    cli.addOptions(help)

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output file. (Default: Netlists/ + input + .netlist.v)")
    cli.addOptions(filePath)
    
    let cut = BoolOption(shortFlag: "c", longFlag: "cut", helpMessage: "Cut away flipflops to turn them into inputs. This makes ATPG faster but changes the structure of the circuit decidedly.")
    cli.addOptions(cut)
    let liberty = StringOption(shortFlag: "l", longFlag: "liberty", required: !defaultLiberty, helpMessage: "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")")
    cli.addOptions(liberty)

    let module = StringOption(shortFlag: "t", longFlag: "top", required: !defaultLiberty, helpMessage: "Top module (Required.)")
    cli.addOptions(module)

    let registerChain = BoolOption(longFlag: "registerChain", helpMessage: "Chain together D flip-flops.")
    cli.addOptions(registerChain)
    
    let resynthesize = StringOption(longFlag: "resynthWith", helpMessage: "Liberty file to resynthesize with after register chaining. Has no effect unless registerChain is selected.")
    cli.addOptions(resynthesize)

    let resynthesizeWithOSU035 = BoolOption(longFlag: "osu035resyn", helpMessage: "Resynthesize after register chaining with a cut down version of osu035.")
    if defaultLiberty {
        cli.addOptions(resynthesizeWithOSU035)
    }

    
    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        exit(EX_USAGE)
    }

    if help.value {
        cli.printUsage()
        exit(EX_OK)
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        exit(EX_USAGE)
    }
    

    let file = args[0]
    let output = filePath.value ?? "Netlists/\(file).netlist.v"
    let intermediate0 = "\(output).intermediate0.v"
    let intermediate1 = "\(output).intermediate1.v"
    let intermediate2 = "\(output).intermediate2.v"
    
    // I am so sorry.
    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" :
        liberty.value!

    let script = createScript(for: module.value!, in: file, cutting: cut.value, liberty: libertyFile, output: registerChain.value ? intermediate0: output)

    let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
    let result = "echo '\(script)' | yosys".sh()

    if result != EX_OK {
        exit(Int32(result))
    }

    if !registerChain.value {
        exit(EX_OK)
    }

    // MARK: Importing Python and Pyverilog
    let sys = Python.import("sys")
    sys.path.append(FileManager().currentDirectoryPath + "/Submodules/Pyverilog")
    
    if let installPath = env["FAULT_INSTALL_PATH"] {
        sys.path.append(installPath + "/FaultInstall/Pyverilog")
    }

    let pyverilogVersion = Python.import("pyverilog.utils.version")
    print("Using Pyverilog v\(pyverilogVersion.VERSION)")

    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator = Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

    // MARK: Process ast
    let ast = parse([intermediate0])[0]
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
        exit(EX_DATAERR)
    }
    
    // MARK: Register Chain Serialization
    
    let testingName = "__testing__"
    let testingIdentifier = Node.Identifier(testingName)
    let inputName = "__input__"
    let inputIdentifier = Node.Identifier(inputName)
    let outputName = "__output__"
    let outputIdentifier = Node.Identifier(outputName)

    var previousOutput = inputIdentifier

    let ports = Python.list(definition.portlist.ports)
    ports.append(Node.Port(testingName, Python.None, Python.None))
    ports.append(Node.Port(inputName, Python.None, Python.None))
    ports.append(Node.Port(outputName, Python.None, Python.None))
    definition.portlist.ports = Python.tuple(ports)

    var counter = 0

    for itemDeclaration in definition.items {
        let type = Python.type(itemDeclaration).__name__

        // Process gates
        if type == "InstanceList" {
            let instance = itemDeclaration.instances[0]
            if "\(instance.module)".starts(with: "DFF") {
                counter += 1
                for hook in instance.portlist {
                    if hook.portname == "D" {
                        let ternary = Node.Cond(testingIdentifier, previousOutput, hook.argname)
                        hook.argname = ternary
                    }
                    if hook.portname == "Q" {
                        previousOutput = hook.argname
                    }
                }
            }
        }
    }

    let statements = Python.list()
    statements.append(Node.Input(inputName))
    statements.append(Node.Output(outputName))
    statements.append(Node.Input(testingName))
    statements.extend(Python.list(definition.items))

    let finalAssignment = Node.Assign(
        Node.Lvalue(outputIdentifier),
        Node.Rvalue(previousOutput)
    )
    statements.append(finalAssignment)
    definition.items = Python.tuple(statements)

    let metadata = Metadata(dffCount: counter, testEnableIdentifier: testingName, testInputIdentifier: inputName, testOutputIdentifier: outputName)
    guard let metadataString = metadata.toJSON() else {
        print("Could not generate metadata string.")
        exit(EX_SOFTWARE)
    }
    
    do {
        let resynthesisLiberty = resynthesizeWithOSU035.value ? "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" : resynthesize.value
        if let secondLiberty = resynthesisLiberty  {
            try File.open(intermediate1, mode: .write) {
                try $0.print(Generator.visit(ast))
            }

            let script = createScript(for: module.value!, in: intermediate1, liberty: secondLiberty, output: intermediate2, optimize: false)

            let result = "echo '\(script)' | yosys".sh()

            if result != EX_OK {
                exit(Int32(result))
            }

            try File.open(intermediate2, mode: .read) { intermediate in
                try File.open(output, mode: .write) {
                    try $0.print(String.boilerplate)
                    try $0.print("/* FAULT METADATA: \(metadataString) */")
                    try $0.print(intermediate.string!)
                    exit(EX_OK)
                }
            }

        } else {
            
            try File.open(output, mode: .write) {
                try $0.print(String.boilerplate)
                try $0.print("/* FAULT METADATA: \(metadataString) */")
                try $0.print(Generator.visit(ast))
            }

            exit(EX_OK)
        }
    } catch {
        print("Internal software error: \(error)")
        exit(EX_SOFTWARE)
    }
}