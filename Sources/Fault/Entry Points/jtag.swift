import Foundation
import CommandLineKit
import PythonKit
import Defile


func JTAGCreate(arguments: [String]) -> Int32{
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

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
        helpMessage: "Path to the output file. (Default: input + .jtag.v)"
    )
    cli.addOptions(filePath)

    let verifyOpt = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: "Verify JTAG port using given cell model."
    )
    cli.addOptions(verifyOpt)

    let liberty = StringOption(
        shortFlag: "l",
        longFlag: "liberty",
        required: !defaultLiberty,
        helpMessage:
            "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")"
    )
    cli.addOptions(liberty)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "Serial Data In"),
        ("sout", "Serial Data Out"),
        ("shift", "Shift enable"),
        ("tms", "Test Mode Select"),
        ("tck", "Test Clock Signal"),
        ("tdi", "Test Data Input"),
        ("tdo", "Test Data Output"),
        ("trst", "Test Reset Signal")
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
        print("Usage 11")
        cli.printUsage()
        return EX_USAGE
    }

    if help.value {
        print("Usage 2")
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        print("Usage 1 ")
        cli.printUsage()
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        fputs("File '\(file)' not found.\n", stderr)
        return EX_NOINPUT
    }

     if let libertyTest = liberty.value {
        if !fileManager.fileExists(atPath: libertyTest) {
            fputs("Liberty file '\(libertyTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !libertyTest.hasSuffix(".lib") {
            fputs(
                "Warning: Liberty file provided does not end with .lib.",
                stderr
            )
        }
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

    let output = filePath.value ?? "\(file).jtag.v"
    let intermediate = output + ".outputintermediate_jtag.v"
    let tapLocation = "RTL/JTAG/tap_top.v"

    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_muxonly.lib" :
        liberty.value!

    // MARK: Importing Python and Pyverilog
    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

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

    let tmsName = names["tms"]!.option.value ?? names["tms"]!.default
    let tdiName = names["tdi"]!.option.value ?? names["tdi"]!.default
    let tdoName = names["tdo"]!.option.value ?? names["tdo"]!.default
    let tckName = names["tck"]!.option.value ?? names["tck"]!.default
    let trstName = names["trst"]!.option.value ?? names["trst"]!.default

    let sinName = names["sin"]!.option.value ?? names["sin"]!.default
    let soutName = names["sout"]!.option.value ?? names["sout"]!.default
    let shiftName = names["shift"]!.option.value ?? names["shift"]!.default

    // MARK: Internal signals
    print("Adding JTAG port…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__DESIGN__UNDER__TEST__"
    
    do{
        let (_, inputs, outputs) = try Port.extract(from: definition)

        let TMSIdentifier = Node.Identifier(tmsName)
        let TDIIdentifier = Node.Identifier(tdiName)
        let TDOIdentifier = Node.Identifier(tdoName)
        let TCKIdentifier = Node.Identifier(tckName)
        let TRSTIdentifier = Node.Identifier(trstName)
        
        definition.name = Python.str(alteredName);

        print("Hooking TAP port to boundary flip-flops…")
      
        let ports = Python.list(definition.portlist.ports)

        var topModulePorts = Python.list(ports.filter { String($0.name) != sinName &&
                                            String($0.name) != shiftName &&
                                            String($0.name) != soutName })

        topModulePorts.append(Node.Port(tmsName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(tckName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(tdiName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(tdoName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(trstName, Python.None, Python.None, Python.None))

        var statements = Python.list()
        statements.append(Node.Input(tmsName))
        statements.append(Node.Input(tckName))
        statements.append(Node.Input(tdiName))
        statements.append(Node.Input(trstName))
        statements.append(Node.Output(tdoName))
        
        let portArguments = Python.list()

        for input in inputs {
            if(input.name != sinName && input.name != shiftName){
                statements.append(Node.Input(input.name))
            }
            portArguments.append(Node.PortArg(
                input.name,
                Node.Identifier(input.name)
            ))
        }

        for output in outputs {
            if(output.name != soutName){
                statements.append(Node.Output(output.name))
            }
            portArguments.append(Node.PortArg(
                output.name,
                Node.Identifier(output.name)
            ))
        }
            
    
        let jtagCreator = JTAGCreator(
            name: "TapTop",
            using: Node
        )
        
        // Read Config File
        let file = "RTL/JTAG/tapConfig.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        
        guard let jtagInfo = try? JSONDecoder().decode(JTAGInfo.self, from: data) else {
            fputs("File '\(file)' is invalid.\n", stderr)
            return EX_DATAERR
        }

        
        let jtagModule =  jtagCreator.create(
            jtagInfo: jtagInfo, 
            tms: tmsName,
            tck: tckName,
            tdi: tdiName,
            tdo: tdoName,
            trst: trstName
        )

        let wireDeclarations = jtagModule.wires
        statements.extend(wireDeclarations)

        statements.append(jtagModule.tapModule)
        let submoduleInstance = Node.Instance(
                alteredName,
                "__dut__",
                Python.tuple(portArguments),
                Python.tuple()
        )

        statements.append(Node.InstanceList(
            alteredName,
            Python.tuple(),
            Python.tuple([submoduleInstance])
        ))

        let supermodel = Node.ModuleDef(
            definitionName,
            Python.None,
            Node.Portlist(Python.tuple(topModulePorts)),
            Python.tuple(statements)
        )
        let tapDefinition =
            parse([tapLocation])[0][dynamicMember: "description"].definitions
        let definitions = Python.list(description.definitions)
        definitions.extend(tapDefinition)
        definitions.append(supermodel)
        description.definitions = Python.tuple(definitions)

        try File.open(intermediate, mode: .write) {
            try $0.print(Generator.visit(ast))
        }
       
    } catch{
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    return EX_OK

}