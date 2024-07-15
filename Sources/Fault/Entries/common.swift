// Copyright (C) 2019-2024 The American University in Cairo
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
import Collections

struct Reset {
    let name: String
    let active: Simulator.Active
}

struct BypassOptions: ParsableArguments {
    @Option(name: [.long], help: "Inputs to bypass when performing operations. May be specified multiple times to bypass multiple inputs. Will be held high during simulations by default, unless =0 is appended to the option.")
    var bypassing: [String] = []
    
    @Option(help: "Clock name. In addition to being bypassed for certain manipulation operations, during simulations it will always be held high.")
    var clock: String
    
    @Option(name: [.customLong("reset")], help: "Reset name. In addition to being bypassed for certain manipulation operations, during simulations it will always be held low.")
    var resetName: String

    @Flag(name: [.long, .customLong("activeLow")], help: "The reset signal is considered active-low insted, and will be held high during simulations.")
    var resetActiveLow: Bool = false
    
    lazy var reset: Reset = {
        return Reset(name: resetName, active: resetActiveLow ? .low : .high)
    }()
    
    lazy var simulationValues: OrderedDictionary<String, Simulator.Behavior>  = {
        var result: OrderedDictionary<String, Simulator.Behavior> = [:]
        result[clock] = .holdHigh
        result[reset.name] = reset.active == .low ? .holdHigh : .holdLow
        for bypassed in bypassing {
            let split = bypassed.components(separatedBy: "=")
            if split.count == 1 {
                result[bypassed] = .holdHigh
            } else if split.count == 2 {
                result[bypassed] = split[1] == "0" ? .holdLow : .holdHigh
            }
        }
        return result
    }()
    
    lazy var bypassedInputs: Set<String> = {
        return Set<String>(simulationValues.keys)
    }()
    
} 
