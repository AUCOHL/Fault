import Foundation
import CommandLineKit
import PythonKit
import Defile

func synth(arguments: [String]) -> Int32 {
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    cli.addOptions(help)

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output netlist. (Default: Netlists/ + input + .netlist.v)")
    cli.addOptions(filePath)

    let liberty = StringOption(shortFlag: "l", longFlag: "liberty", required: !defaultLiberty, helpMessage: "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")")
    cli.addOptions(liberty)

    let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Top module. (Default: first module found.)")
    cli.addOptions(topModule)
    
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
    let output = filePath.value ?? "Netlists/\(file).netlist.v"

    if let libertyTest = liberty.value {
        if !fileManager.fileExists(atPath: libertyTest) {
            fputs("Liberty file '\(file)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !libertyTest.hasSuffix(".lib") {
            fputs(
                "Warning: Liberty file provided does not end with .lib.",
                stderr
            )
        }
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

    // Get topModule name
    let ast = parse([args[0]])[0]
    let description = ast[dynamicMember: "description"]
    var definitionOptional: PythonObject?
    for definition in description.definitions {
        let type = Python.type(definition).__name__
        if type == "ModuleDef" {
            if let value = topModule.value {
                if "\(definition.name)" == value {
                    definitionOptional = definition
                    break
                }
            } else {
                definitionOptional = definition
                break
            }
        }
    }
    
    guard let definition = definitionOptional else {
        if let value = topModule.value {
            fputs("The top module '\(value)' was not found.\n", stderr)
            exit(EX_DATAERR)
        }
        fputs("No module found.\n", stderr)
        exit(EX_DATAERR)
    }

    let module = "\(definition.name)"
    
    // I am so sorry.
    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" :
        liberty.value!

    let script = Synthesis.script(for: module, in: file, cutting: false, liberty: libertyFile, output: output)

    let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
    let result = "echo '\(script)' | yosys".sh()

    if result != EX_OK {
        fputs("A yosys error has occurred.\n", stderr);
        return Int32(result)
    }

    return EX_OK
}
