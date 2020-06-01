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
        let _ = "sudo apt-get install -y make flex bison libreadline-dev libncurses5-dev libncursesw5-dev ".sh()
    }

    let env = ProcessInfo.processInfo.environment

    let execPrefix = env["EXEC_PREFIX"] ?? "/usr/local/bin"
        
    let previousCWD = env["PWD"]!

    let atalanta = installAtalanta(execPrefix: execPrefix, previousCWD: previousCWD)
    if atalanta != 0 {
        let _ = "echo Failed to install Atalanta".sh()
        return atalanta
    }
    
    let podem = installPodem(execPrefix: execPrefix, previousCWD: previousCWD)

    if podem != 0 {
        let _ = "echo Failed to install PODEM".sh()
        return podem
    }

    return EX_OK
}

func installAtalanta(execPrefix: String, previousCWD: String) -> Int32 {
    
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

func installPodem(execPrefix: String, previousCWD: String) -> Int32 {

    defer {
        chdir(previousCWD)
    }

    let downloadAndExtract = "curl -sL http://tiger.ee.nctu.edu.tw/course/Testing2018/assignments/hw0/podem.tgz  | tar -xzf -".sh()
    if downloadAndExtract != 0 {
        return downloadAndExtract
    }

    chdir("podem")

    let make = "make".sh()
    if make !=  0 {
        return make
    }

    let copy = "sudo cp atpg \(execPrefix)".sh()
    if copy != 0 {
        return copy
    }
    return EX_OK
}
exit(main())