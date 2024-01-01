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

import Foundation
import PythonKit

class MuxCreator {
    var Node: PythonObject
    var muxInfo: MuxInfo
    init(using Node: PythonObject, muxInfo: MuxInfo) {
        self.Node = Node
        self.muxInfo = muxInfo
    }

    func create(
        for instance: String,
        selection: PythonObject,
        a: PythonObject,
        b: PythonObject
    ) -> (cellDeclarations: [PythonObject], wireDeclarations: [PythonObject], replacementHook: PythonObject) {
        let muxName = instance + "__scanchain_mux"
        let outputWireName = "\(muxName)_\(muxInfo.y)"
        let outputWireDecl = Node.Wire(outputWireName)
        let outputWire = Node.Identifier(outputWireName)

        // Cell
        let portArguments = [
            Node.PortArg(muxInfo.a, a),
            Node.PortArg(muxInfo.b, b),
            Node.PortArg(muxInfo.s, selection),
            Node.PortArg(muxInfo.y, outputWire),
        ]
        let instance = Node.Instance(
            muxInfo.name,
            muxName,
            Python.tuple(portArguments),
            Python.tuple()
        )
        let instanceDecl = Node.InstanceList(
            muxInfo.name,
            Python.tuple(),
            Python.tuple([instance])
        )
        let pragma = Node.Pragma(
            Node.PragmaEntry(
                "keep"
            )
        )
        
        // Hook
        var hook = outputWire
        if muxInfo.invertedOutput {
            hook = Node.Unot(hook)
        }
        return ([
            pragma,
            instanceDecl,
        ], [
            outputWireDecl,
        ], hook)
    }
}
