import Foundation
import CommandLineKit

func compactTestVectors(arguments: [String]) -> Int32 {
    let env = ProcessInfo.processInfo.environment
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
        helpMessage: "Path to the output file. (Default: input + .compacted.json)"
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
      //  fputs("File '\(fileJson)' not found.\n", stderr)
       // return EX_NOINPUT
    }

    let output = filePath.value ?? "\(file).compacted.v"
    print(output)
    print(file)
    // Read JSON File
     do {
         if let url = NSURL(string: file){
//Bundle.main.url(forResource: "c17", withExtension: "json", subdirectory:"Netlists/RTL/ISCAS_Comb" ) {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let object = json as? [String: Any] {
                // json is a dictionary
                print(object)
            } else if let object = json as? [Any] {
                // json is an array
                print(object)
            } else {
                fputs("File '\(file)' is invalid.\n", stderr)
                return EX_NOINPUT
            }
        } else {
            fputs("File '\(file)' not found.\n", stderr)
            return EX_NOINPUT
        }
    } catch {
        print(error.localizedDescription)
    }

    
    return EX_OK
}