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

import Defile
import Foundation

struct ChainRegister: Codable {
  enum Kind: String, Codable {
    case input
    case output
    case dff
    case bypassInput  // bypass when loading the TV (loaded with zeros)
    case bypassOutput  // bypass when shifting out the response ()
  }

  var name: String
  var kind: Kind
  var width: Int
  var ordinal: Int
  init(name: String, kind: Kind, ordinal: Int = 0, width: Int = 1) {
    self.name = name
    self.kind = kind
    self.ordinal = ordinal
    self.width = width
  }
}

struct ChainMetadata: Codable {
  var boundaryCount: Int
  var internalCount: Int
  var order: [ChainRegister]
  var shift: String
  var sin: String
  var sout: String
  init(
    boundaryCount: Int,
    internalCount: Int,
    order: [ChainRegister],
    shift: String,
    sin: String,
    sout: String
  ) {
    self.boundaryCount = boundaryCount
    self.internalCount = internalCount
    self.order = order
    self.shift = shift
    self.sin = sin
    self.sout = sout
  }

  static func extract(file: String) -> ([ChainRegister], Int, Int) {
    guard let string = File.read(file) else {
      Stderr.print("Could not read file '\(file)'")
      exit(EX_NOINPUT)
    }
    let components = string.components(separatedBy: "/* FAULT METADATA: '")
    if components.count == 0 {
      Stderr.print("Fault metadata not provided.")
      exit(EX_NOINPUT)
    }
    let slice = components[1]
    if !slice.contains("' END FAULT METADATA */") {
      Stderr.print("Fault metadata not terminated.")
      exit(EX_NOINPUT)
    }
    let decoder = JSONDecoder()
    let metadataString = slice.components(separatedBy: "' END FAULT METADATA */")[0]
    guard
      let metadata = try? decoder.decode(
        ChainMetadata.self, from: metadataString.data(using: .utf8)!
      )
    else {
      Stderr.print("Metadata json is invalid.")
      exit(EX_DATAERR)
    }
    return (
      order: metadata.order,
      boundaryCount: metadata.boundaryCount,
      internalCount: metadata.internalCount
    )
  }
}

struct binMetadata: Codable {
  var count: Int
  var length: Int
  init(
    count: Int,
    length: Int
  ) {
    self.count = count
    self.length = length
  }

  static func extract(file: String) -> (Int, Int) {
    guard let binString = File.read(file) else {
      Stderr.print("Could not read file '\(file)'")
      exit(EX_NOINPUT)
    }

    let slice = binString.components(separatedBy: "/* FAULT METADATA: '")[1]
    if !slice.contains("' END FAULT METADATA */") {
      Stderr.print("Fault metadata not terminated.")
      exit(EX_NOINPUT)
    }

    let decoder = JSONDecoder()
    let metadataString = slice.components(separatedBy: "' END FAULT METADATA */")[0]
    guard
      let metadata = try? decoder.decode(binMetadata.self, from: metadataString.data(using: .utf8)!)
    else {
      Stderr.print("Metadata json is invalid.")
      exit(EX_DATAERR)
    }
    return (count: metadata.count, length: metadata.length)
  }
}
