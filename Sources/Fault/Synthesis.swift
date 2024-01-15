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

enum Synthesis {
    static func script(
        for module: String,
        in files: [String],
        cutting: Bool = false,
        checkHierarchy: Bool = true,
        liberty libertyFile: String,
        blackboxing blackboxedModules: [String] = [],
        output: String,
        optimize: Bool = true
    ) -> String {
        let opt = optimize ? "opt" : ""
        return """
        # read liberty
        read_liberty -lib -ignore_miss_dir -setattr blackbox \(libertyFile)

        # read black boxes
        read_verilog -sv -lib \(blackboxedModules.map { "'\($0)'" }.joined(separator: " "))

        # read design
        read_verilog -sv \(files.map { "'\($0)'" }.joined(separator: " "))

        # check design hierarchy
        hierarchy \(checkHierarchy ? "-check" : "") -top \(module)

        # translate processes (always blocks)
        proc; \(opt)

        # detect and optimize FSM encodings
        fsm; \(opt)

        # implement memories (arrays)
        memory; \(opt)

        # convert to gate logic
        techmap; \(opt)

        # flatten
        flatten; \(opt)

        # mapping flip-flops to mycells.lib
        dfflibmap -liberty \(libertyFile)

        # expose dff
        \(cutting ? "expose -cut -evert-dff; \(opt)" : "")

        # mapping logic to mycells.lib
        abc -liberty \(libertyFile)

        # print gate count
        stat

        # cleanup
        opt_clean -purge

        # names
        # autoname

        write_verilog -noexpr \(output)+attrs
        write_verilog -noexpr -noattr \(output)
        """
    }
}
