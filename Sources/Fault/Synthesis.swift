struct Synthesis {
    enum Gate: String {
        case and = "AND"
        case nand = "NAND"
        case or = "OR"
        case nor = "NOR"
        case xnor = "XNOR"
        case andnot = "ANDNOT"
        case ornot = "ORNOT"
        case mux = "MUX"
        case aoi3 = "AOI3"
        case oai3 = "OAI3"
        case aoi4 = "AOI4"
        case oai4 = "OAI4"
    }

    static func script(
        for module: String,
        in file: String,
        cutting: Bool = false,
        checkHierarchy: Bool = true,
        liberty libertyFile: String,
        output: String,
        optimize: Bool = true
    ) -> String {
        let opt = optimize ? "opt" : ""
        return """
        read_verilog \(file)

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

        # expose dff
        \(cutting ? "expose -cut -evert-dff; \(opt)" : "")

        # flatten
        flatten; \(opt)

        # mapping flip-flops to mycells.lib
        dfflibmap -liberty \(libertyFile)

        # mapping logic to mycells.lib
        abc -liberty \(libertyFile)

        # print gate count
        stat

        # cleanup
        opt_clean -purge

        write_verilog -noattr -noexpr \(output)
        """
    }
}