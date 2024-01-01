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

class BoundaryScanRegisterCreator {
    var name: String
    private var inputName: String
    private var outputName: String
    var counter: Int = 0

    var clock: String
    var reset: String
    var resetActive: Simulator.Active
    var testing: String
    var shift: String

    private var clockIdentifier: PythonObject
    private var resetIdentifier: PythonObject
    private var testingIdentifier: PythonObject
    private var shiftIdentifier: PythonObject

    private var Node: PythonObject

    init(
        name: String,
        clock: String,
        reset: String,
        resetActive: Simulator.Active,
        testing: String,
        shift: String,
        using Node: PythonObject
    ) {
        self.name = name
        inputName = "\(name)_input"
        outputName = "\(name)_output"

        self.clock = clock
        clockIdentifier = Node.Identifier(clock)

        self.reset = reset
        resetIdentifier = Node.Identifier(reset)

        self.resetActive = resetActive

        self.testing = testing
        testingIdentifier = Node.Identifier(testing)

        self.shift = shift
        shiftIdentifier = Node.Identifier(shift)

        self.Node = Node
    }

    func create(
        ordinal: Int,
        max: Int,
        din: String,
        dout: String,
        sin: String,
        sout: String,
        input: Bool
    ) -> PythonObject {
        let dinIdentifier = Node.Identifier(din)
        let doutIdentifier = Node.Identifier(dout)
        let sinIdentifier = Node.Identifier(sin)
        let soutIdentifier = Node.Identifier(sout)
        let ordinalConstant = Node.Constant(ordinal)

        let name = input ? inputName : outputName
        let dinArg = (max == 0) ? dinIdentifier : Node.Pointer(dinIdentifier, ordinalConstant)
        let doutArg = (max == 0) ? doutIdentifier : Node.Pointer(doutIdentifier, ordinalConstant)

        let portArguments = [
            Node.PortArg("din", dinArg),
            Node.PortArg("dout", doutArg),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("sout", soutIdentifier),
            Node.PortArg("clock", clockIdentifier),
            Node.PortArg("reset", resetIdentifier),
            Node.PortArg("testing", testingIdentifier),
            Node.PortArg("shift", shiftIdentifier),
        ]

        let submoduleInstance = Node.Instance(
            name,
            "__" + name + "_" + String(describing: counter) + "__",
            Python.tuple(portArguments),
            Python.tuple()
        )

        counter += 1

        return Node.InstanceList(
            name,
            Python.tuple(),
            Python.tuple([submoduleInstance])
        )
    }

    var inputDefinition: String {
        """
        module \(inputName) (
            din,
            dout,
            sin,
            sout,
            clock,
            reset,
            testing,
            shift
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, testing, shift;

            reg store;
            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    store <= shift ? sin: dout;
                end
            end
            assign sout = store;
            assign dout = testing ? store : din;
        endmodule

        """
    }

    var outputDefinition: String {
        """
        module \(outputName) (
            din,
            dout,
            sin,
            sout,
            clock,
            reset,
            testing,
            shift
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, testing, shift;
            reg store;
            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    store <= shift ? sin: dout;
                end
            end
            assign sout = store;
            assign dout = din;
        endmodule

        """
    }
}
