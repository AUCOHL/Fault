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
import PythonKit

class DFFMatch: Codable, CustomStringConvertible {
  var name: String
  var clk: String
  var d: String
  var q: String

  init(name: String, clk: String, d: String, q: String) {
    self.name = name
    self.clk = clk
    self.d = d
    self.q = q
  }

  var description: String {
    "<DFFMatch \(name): @\(clk) \(d) -> \(q)>"
  }
}

func getMatchingDFFInfo(from list: [DFFMatch], for cell: String, fnmatch: PythonObject) -> DFFMatch?
{
  for dffinfo in list {
    for name in dffinfo.name.components(separatedBy: ",") {
      if Bool(fnmatch.fnmatch(cell, name))! {
        return dffinfo
      }
    }
  }
  return nil
}

class MuxInfo: Codable {
  var name: String
  var a: String
  var b: String
  var y: String
  var s: String
  var invertedOutput: Bool = false

  init(name: String, a: String, b: String, y: String, s: String, invertedOutput: Bool = false) {
    self.name = name
    self.a = a
    self.b = b
    self.y = y
    self.s = s
    self.invertedOutput = invertedOutput
  }
}

class SCLConfiguration: Codable {
  var dffMatches: [DFFMatch]
  var muxInfo: MuxInfo?

  init(dffMatches: [DFFMatch], muxInfo: MuxInfo? = nil) {
    self.dffMatches = dffMatches
    self.muxInfo = muxInfo
  }
}
