// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArgumentParser
import BigInt
import Collections
import CoreFoundation  // Not automatically imported on Linux
import Defile
import Foundation
import PythonKit
import Yams

extension Fault {
  struct Synth: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Synthesize Verilog designs using Yosys."
    )

    @Option(
      name: [.customShort("o"), .long],
      help: "Path to the output netlist. (Default: Netlists/ + input + .netlist.v)"
    )
    var output: String?

    @Option(name: [.customShort("l"), .long], help: "Liberty file. (Required.)")
    var liberty: String

    @Option(name: [.customShort("t"), .long], help: "Top module. (Required.)")
    var top: String

    @Option(
      name: [.customShort("B"), .long, .customLong("blackboxModel")],
      help: "Blackbox model verilog files. Specify multiple times to specify multiple models."
    )
    var blackboxModels: [String] = []

    @Argument(help: "Verilog files to synthesize.")
    var files: [String]

    mutating func run() throws {
      let fileManager = FileManager.default

      for file in files {
        guard fileManager.fileExists(atPath: file) else {
          throw ValidationError("File '\(file)' not found.")
        }
      }

      if !fileManager.fileExists(atPath: liberty) {
        print("Liberty file '\(liberty)' not found.")
        return
      }

      if !liberty.hasSuffix(".lib") {
        print("Warning: Liberty file provided does not end with .lib.")
      }

      let output = output ?? "Netlists/\(top).nl.v"

      let script = Synthesis.script(
        for: top, in: files, cutting: false, liberty: liberty, blackboxing: blackboxModels,
        output: output
      )

      let outputDirectory = URL(fileURLWithPath: output).deletingLastPathComponent().path
      try fileManager.createDirectory(
        atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil
      )

      let result = "echo '\(script)' | '\(yosysExecutable)'".sh()

      if result != EX_OK {
        print("A yosys error has occurred.")
        throw ValidationError("Yosys error occurred.")
      }
    }
  }
}
