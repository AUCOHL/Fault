import Foundation
import CommandLineKit
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

    let topModule = StringOption(shortFlag: "t", longFlag: "top", required: true, helpMessage: "Top module. (Required.)")
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
    if args.count < 1 {
        cli.printUsage()
        return EX_USAGE
    }      

    let fileManager = FileManager()
    let files = args

    for file in files {
        if !fileManager.fileExists(atPath: file) {
            fputs("File '\(file)' not found.\n", stderr)
            return EX_NOINPUT
        }
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

    let module = "\(topModule.value!)"

    let output = filePath.value ?? "Netlists/\(module).netlist.v"
    
    // I am so sorry.
    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" :
        liberty.value!

    let script = Synthesis.script(for: module, in: args, cutting: false, liberty: libertyFile, output: output)

    let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
    let result = "echo '\(script)' | '\(yosysExecutable)'".sh()

    if result != EX_OK {
        fputs("A yosys error has occurred.\n", stderr);
        return Int32(result)
    }

    return EX_OK
}
