import XCTest
import class Foundation.Bundle

extension Process {
  func startAndBlock() throws {
    try self.launch()
    self.waitUntilExit()
  }
}

final class FaultTests: XCTestCase {
    func testFull() throws {
        guard #available(macOS 10.13, *) else {
            return
        }

        let binary = productsDirectory.appendingPathComponent("Fault")

        let newProcess = { ()-> Process in
          let new = Process()
          new.executableURL = binary
          return new
        }

        let liberty = "Tech/osu035/osu035_stdcells.lib"
        let models = "Tech/osu035/osu035_stdcells.v"

        let fileName = "RTL/Seq/spm.v"
        let topModule = "SPM"
        let clock = "clk"
        let reset = "rst"
        
        let fileSynth = "Netlists/" + fileName + ".netlist.v"
        let fileCut = fileSynth + ".cut.v"
        let fileJson = fileCut + ".tv.json"
        let fileChained = fileSynth + ".chained.v"

        // 0. Synth
        var process = newProcess()
        process.arguments = ["synth", "-l", liberty, "-t", topModule, "-o", fileSynth, fileName]
        try process.startAndBlock()


        XCTAssertEqual(process.terminationStatus, 0)
        print("1/5")
        // 1. Cut
        process = newProcess()
        process.arguments = ["cut", "-o", fileCut, fileSynth]
        try process.startAndBlock()


        XCTAssertEqual(process.terminationStatus, 0)

        // 2. Simulate
        process = newProcess()
        process.arguments = ["-c", models, "-o", fileJson, fileCut]
        try process.startAndBlock()
        print("2/5")


        XCTAssertEqual(process.terminationStatus, 0)

        // 3. Chain
        process = newProcess()
        process.arguments = ["chain", "-c", models, "-l", liberty, "-o", fileChained, "--clock", clock, "--reset", reset, fileSynth]
        print(process.arguments!.joined(separator: " "))
        try process.startAndBlock()
        print("3/5")


        XCTAssertEqual(process.terminationStatus, 0)

        // 4. Assemble
        process = newProcess()
        process.arguments = ["asm", "-o", "/dev/null", fileJson, fileChained]
        try process.startAndBlock()
        print("4/5")


        XCTAssertEqual(process.terminationStatus, 0)

        // 5. Compact
        process = newProcess()
        process.arguments = ["compact", "-o", "/dev/null", fileJson]
        try process.startAndBlock()
        print("5/5")


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
        ("testFull", testFull)
    ]
}
