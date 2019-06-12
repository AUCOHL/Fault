import XCTest
import class Foundation.Bundle

final class FaultTests: XCTestCase {
    func ensureEX_OK(moduleName: String, fileName: String, cells: String, perFault: Bool = false) throws {
        guard #available(macOS 10.13, *) else {
            return
        }

        let fooBinary = productsDirectory.appendingPathComponent("Fault")

        let process = Process()
        process.executableURL = fooBinary
        process.arguments = ["-c", cells, "-t", moduleName, "-o", "/dev/null", fileName]

        if perFault {
          process.arguments!.append("--perFault")
        }

        // let pipe = Pipe()
        // process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        // let data = pipe.fileHandleForReading.readDataToEndOfFile()
        // let _ = String(data: data, encoding: .utf8)

        XCTAssertEqual(process.terminationStatus, 0)
    }

    func testCombinational() throws {
      try ensureEX_OK(moduleName: "PlusOne", fileName: "Netlists/RTL/PlusOne.v.netlist.v", cells: "Tech/osu035/osu035_stdcells.v")
    }

    func testSequential() throws {
      try ensureEX_OK(moduleName: "SuccessiveApproximationControl", fileName: "Netlists/RTL/SAR.v.netlist.v", cells: "Tech/osu035/osu035_stdcells.v")
    }

    func testCombinationalPF() throws {
      try ensureEX_OK(moduleName: "PlusOne", fileName: "Netlists/RTL/PlusOne.v.netlist.v", cells: "Tech/osu035/osu035_stdcells.v", perFault: true)
    }

    func testSequentialPF() throws {
      try ensureEX_OK(moduleName: "SuccessiveApproximationControl", fileName: "Netlists/RTL/SAR.v.netlist.v", cells: "Tech/osu035/osu035_stdcells.v", perFault: true)
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
        ("testCombinational", testCombinational),
        ("testSequential", testSequential),
        ("testCombinationalPF", testCombinationalPF),
        ("testSequentialPF", testSequentialPF)
    ]
}
