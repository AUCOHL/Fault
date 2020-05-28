#!/usr/bin/env swift
import Foundation

extension String {
    func sh() -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["sh", "-c", self]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}

func main() -> Int32 {

    let apt = "which apt-get".sh()
    if apt == 0 {
        let _ = "sudo apt-get install -y make ".sh()
    }

    let env = ProcessInfo.processInfo.environment

    let execPrefix = env["EXEC_PREFIX"] ?? "/usr/local"
        
    let previousCWD = env["PWD"]!

    defer {
        chdir(previousCWD)
    }

    let downloadAndExtract = "curl -sL https://github.com/hsluoyz/Atalanta/archive/master.tar.gz | tar -xzf -".sh()
    if downloadAndExtract != 0 {
        return downloadAndExtract
    }

    chdir("Atalanta-master")

    let make = "make".sh()
    if make != 0 {
        return make
    }

    let copy = "sudo cp atalanta \(execPrefix)".sh()
    if copy != 0 {
        return copy
    }
    return EX_OK
}
exit(main())