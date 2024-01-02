import class Foundation.Bundle
import XCTest

var env = ProcessInfo.processInfo.environment

extension Process {
    func startAndBlock() throws {
        log("$ \(self.executableURL!.path()) \((self.arguments ?? []).joined(separator: " "))")
        launch()
        waitUntilExit()
        print("Exited with: \(self.terminationStatus)")
    }
}

extension String {
    func shOutput() -> (terminationStatus: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", self]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            print("Could not launch task `\(self)': \(error)")
            exit(EX_UNAVAILABLE)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8)

        return (terminationStatus: task.terminationStatus, output: output!)
    }
}

func log(_ string: String) {
    print(string)
    fflush(stdout)
}

final class FaultTests: XCTestCase {
    func testFull() throws {
        guard #available(macOS 10.13, *) else {
            return
        }

        // Dependencies
        let venvPath = "\(env["PWD"]!)/venv"

        let venv = "python3 -m venv \(venvPath)".shOutput()
        XCTAssertEqual(venv.terminationStatus, 0)

        let reqs = "./venv/bin/python3 -m pip install -r ./requirements.txt".shOutput()
        XCTAssertEqual(reqs.terminationStatus, 0)

        let fileManager = FileManager()
        let venvLibPath = "\(venvPath)/lib"
        let venvLibVersions = try! fileManager.contentsOfDirectory(atPath: venvLibPath)
        let venvLibVersion = "\(venvLibPath)/\(venvLibVersions[0])/site-packages"

        // Fault Tests
        let binary = productsDirectory.appendingPathComponent("Fault")

        let newProcess = { () -> Process in
            let new = Process()
            new.executableURL = binary
            new.environment = ProcessInfo.processInfo.environment
            new.environment!["PYTHONPATH"] = venvLibVersion
            return new
        }

        let liberty = "Tech/osu035/osu035_stdcells.lib"
        let models = "Tech/osu035/osu035_stdcells.v"

        let fileName = "Tests/RTL/spm.v"
        let topModule = "spm"
        let clock = "clk"
        let reset = "rst"
        let ignoredInputs = "\(reset)"

        let fileSynth = "Netlists/" + fileName + ".netlist.v"
        let fileCut = fileSynth + ".cut.v"
        let fileJson = fileCut + ".tv.json"
        let fileChained = fileSynth + ".chained.v"
        let fileAsmVec = fileJson + ".vec.bin"
        let fileAsmOut = fileJson + ".out.bin"

        // 0. Synth
        var process = newProcess()
        process.arguments = ["synth", "-l", liberty, "-t", topModule, "-o", fileSynth, fileName]
        try process.startAndBlock()

        XCTAssertEqual(process.terminationStatus, 0)
        log("1/6")
        // 1. Cut
        process = newProcess()
        process.arguments = ["cut", "-o", fileCut, fileSynth]
        try process.startAndBlock()

        XCTAssertEqual(process.terminationStatus, 0)

        // 2. Simulate
        process = newProcess()
        process.arguments = ["-c", models, "-i", ignoredInputs, "--clock", clock, "-o", fileJson, fileCut]
        try process.startAndBlock()
        log("2/6")

        XCTAssertEqual(process.terminationStatus, 0)

        // 3. Chain
        process = newProcess()
        process.arguments = ["chain", "-c", models, "-l", liberty, "-o", fileChained, "--clock", clock, "--reset", reset, "-i", ignoredInputs, fileSynth]
        try process.startAndBlock()
        log("3/6")

        XCTAssertEqual(process.terminationStatus, 0)

        // 4. Assemble
        process = newProcess()
        process.arguments = ["asm", fileJson, fileChained]
        try process.startAndBlock()
        log("4/6")

        XCTAssertEqual(process.terminationStatus, 0)

        // 5. Compact
        process = newProcess()
        process.arguments = ["compact", "-o", "/dev/null", fileJson]
        try process.startAndBlock()
        log("5/6")

        // 6. Tap
        process = newProcess()
        process.arguments = ["tap", fileChained, "-c", models, "--clock", clock, "--reset", reset, "-l", liberty, "-t", fileAsmVec, "-g", fileAsmOut, "-i", ignoredInputs,]
        try process.startAndBlock()
        log("6/6")

        XCTAssertEqual(process.terminationStatus, 0)
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
        #if os(macOS)
            for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
                return bundle.bundleURL.deletingLastPathComponent()
            }
            fatalError("couldn't find the products directory")
        #else
            return Bundle.main.bundleURL
        #endif
    }

    static var allTests = [
        ("testFull", testFull),
    ]
}
