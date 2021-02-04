import Foundation
import CommandLineKit
import PythonKit
import Defile

func cut(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let dffOpt = StringOption(
        shortFlag: "d",
        longFlag: "dff",
        helpMessage: "Flip-flop cell names ,comma,speerated (Default: DFF)."
    )
    cli.addOptions(dffOpt)

    let blackbox = StringOption(
        longFlag: "blackbox",
        helpMessage: "Blackbox module definitions (.v) seperated by commas. (Default: none)"
    )
    cli.addOptions(blackbox)

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Hard module inputs to ignore when cutting seperated by commas. (Defautl: none)"
    )
    cli.addOptions(ignored)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .chained.v)"
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
        Stderr.print("File '\(file)' not found.")
        return EX_NOINPUT
    }

    let dffNames: Set<String>
        = Set<String>(dffOpt.value?.components(separatedBy: ",").filter {$0 != ""} ?? ["DFFSR", "DFFNEGX1", "DFFPOSX1"])

    let output = filePath.value ?? "\(file).cut.v"

    // MARK: Importing Python and Pyverilog
    
    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

    var isolatedOptional: PythonObject?
    var isolatedName: String?
    if let isolatedFile = blackbox.value {
        let ast = parse([isolatedFile])[0]
        let description = ast[dynamicMember: "description"]
        for definition in description.definitions {
            let type = Python.type(definition).__name__
            if type == "ModuleDef" {
                isolatedOptional = definition
                isolatedName = String(describing: definition.name)
                break
            }
        }
    }

    var definitionOptional: PythonObject?
    let ast = parse([file])[0]
    let description = ast[dynamicMember: "description"]

    for definition in description.definitions {
        let type = Python.type(definition).__name__
        if type == "ModuleDef" {
            definitionOptional = definition
            break
        }
    }
    
    guard let definition = definitionOptional else {
        Stderr.print("No module found.")
        exit(EX_DATAERR)
    }

    let hardIgnoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",").filter {$0 != ""} ?? [])

    do {
        let ports = Python.list(definition.portlist.ports)
        var declarations: [PythonObject] = []
        var items: [PythonObject] = []

        for item in definition.items {
            var include = true

            let type = Python.type(item).__name__
            // Process gates
            if type == "InstanceList" {
                let instance = item.instances[0]
                let instanceName = String(describing: instance.module)
                if dffNames.contains(instanceName) {
                    let instanceName = String(describing: instance.name)
                    let outputName = "\\" + instanceName + ".q"

                    let inputIdentifier = Node.Identifier(instanceName)
                    let outputIdentifier = Node.Identifier(outputName)

                    include = false
                    var dArg: PythonObject?
                    var qArg: PythonObject?

                    for hook in instance.portlist {
                        if hook.portname == "D" {
                            dArg = hook.argname
                        }
                        if hook.portname == "Q" {
                            qArg = hook.argname
                        }
                    }

                    guard let d = dArg, let q = qArg else {
                        Stderr.print(
                            "Cell \(instanceName) missing either a 'D' or 'Q' port."
                        )
                        return EX_DATAERR
                    }

                    ports.append(Node.Port(instanceName, Python.None, Python.None, Python.None))
                    ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))

                    declarations.append(Node.Input(instanceName))
                    declarations.append(Node.Output(outputName))

                    let inputAssignment = Node.Assign(
                        Node.Lvalue(q),
                        Node.Rvalue(inputIdentifier)
                    )
                    let outputAssignment = Node.Assign(
                        Node.Lvalue(outputIdentifier),
                        Node.Rvalue(d)
                    )

                    items.append(inputAssignment)
                    items.append(outputAssignment)
                    
                } else if let blakcboxName = isolatedName, blakcboxName == instanceName {
                    include = false
                    
                    guard let isolatedDefinition = isolatedOptional  else {
                        Stderr.print("No module definition for blackbox \(blakcboxName)")
                        exit(EX_DATAERR)
                    }

                    let (_, inputs, _) = try Port.extract(from: isolatedDefinition)
                    let bbInputNames = inputs.map { $0.name }

                    for hook in instance.portlist {
                        let portName = String(describing: hook.portname)
                        let hookType = Python.type(hook.argname).__name__
                        let input = bbInputNames.contains(portName)
                        
                        if hookType == "Concat" {
                            let list = hook.argname.list
                            for (i, element) in list.enumerated() {
                                var name = ""
                                var statement: PythonObject
                                var assignStatement: PythonObject
                                if input {
                                    name = "\\" + instanceName + "_\(portName)_\(i).q"
                                    statement = Node.Output(name)
                                    assignStatement = Node.Assign(
                                        Node.Lvalue(Node.Identifier(name)),
                                        Node.Rvalue(element)
                                    )
                                    
                                }
                                else {
                                    name =  instanceName + "_\(portName)_\(i)"
                                    statement = Node.Input(name)
                                    assignStatement = Node.Assign(
                                        Node.Lvalue(element),
                                        Node.Rvalue(Node.Identifier(name))
                                    )
                                    
                                }
                                items.append(assignStatement)
                                declarations.append(statement)
                                ports.append(Node.Port(name, Python.None, Python.None, Python.None))
                            }
                        } else {
                            let argName = String(describing: hook.argname)
                            if hardIgnoredInputs.contains(argName) {
                                continue
                            }

                            var name = ""
                            var statement: PythonObject
                            var assignStatement: PythonObject
                            if input {
                                name = "\\" + instanceName + "_\(portName).q" 
                                statement = Node.Output(name) 
                                assignStatement = Node.Assign(
                                    Node.Lvalue(Node.Identifier(name)),
                                    Node.Rvalue(hook.argname)
                                )
                            } else {
                                name = instanceName + ".\(portName)"
                                statement = Node.Input(name)
                                assignStatement = Node.Assign(
                                    Node.Lvalue(hook.argname),
                                    Node.Rvalue(Node.Identifier(name))
                                )
                            }
                            items.append(assignStatement)
                            declarations.append(statement)
                            ports.append(Node.Port(name, Python.None, Python.None, Python.None))
                        } 
                    }
                }
            }
            
            if include {
                items.append(item)
            }
        }

        if declarations.count == 0 {
            print("[Warning]: Failed to detect flip-flop cells named: \(dffNames).")
        }
        
        definition.portlist.ports = ports
        definition.items = Python.tuple(declarations + items)

        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print(Generator.visit(definition))
        }
    } catch {
        Stderr.print("An internal software error has occurred.")
        return EX_SOFTWARE
    }   
    
    return EX_OK
}