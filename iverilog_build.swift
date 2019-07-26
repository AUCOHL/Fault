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
        let _ = "sudo apt-get install -y autoconf make gperf flex bison".sh()
    }

    let env = ProcessInfo.processInfo.environment
    let execPrefix = env["EXEC_PREFIX"] ?? "/usr/local"

    let previousCWD = env["PWD"]!

    defer {
        chdir(previousCWD)
    }

    let downloadAndExtract = "curl -sL https://github.com/steveicarus/iverilog/archive/v10_2.tar.gz | tar -xzf -".sh()
    if downloadAndExtract != 0 {
        return downloadAndExtract
    }

    chdir("iverilog-10_2")

    let autoconf = "autoconf".sh()
    if autoconf != 0 {
        return autoconf
    }

    let configure = "./configure".sh()
    if configure != 0 {
        return configure
    }

    let make = "make -j$(nproc)".sh()
    if make != 0 {
        return make
    }

    let install = "sudo make install exec_prefix=\(execPrefix)".sh()
    if install != 0 {
        return install
    }

    return EX_OK
}
exit(main())