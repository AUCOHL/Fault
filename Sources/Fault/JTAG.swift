import Foundation
import PythonKit
import BigInt

class jtagCreator {
    var name: String
    private var Node: PythonObject
    init(
        name: String,
        using Node: PythonObject
    ) {
        self.name = name
        self.Node = Node
    }

    func create(
        jtagInfo: jtagInfo,
        tms: String,
        tck: String,
        tdi: String,
        tdo: String,
        trst: String
    )-> ( tapModule: PythonObject, wires: [PythonObject]) {
        let pads = jtagInfo.pads
        let states = jtagInfo.states
        let selects = jtagInfo.selects 
        let inputTdi = jtagInfo.inputTdi
        
        let wireDeclarations: [PythonObject] = [ 
            Node.Wire(pads.tdo),
            Node.Wire(pads.tdoEn),
            Node.Wire(states.shift),
            Node.Wire(states.pause),
            Node.Wire(states.update),
            Node.Wire(states.capture),
            Node.Wire(states.idle),
            Node.Wire(states.reset),
            Node.Wire(states.exit1),
            Node.Wire(states.exit2),
            Node.Wire(selects.extest),
            Node.Wire(selects.samplePreload),
            Node.Wire(selects.mbist),
            Node.Wire(selects.debug),
            Node.Wire(selects.preloadChain),
            Node.Wire(jtagInfo.tdoSignal),
            Node.Wire(inputTdi.debug),
            Node.Wire(inputTdi.bsChain),
            Node.Wire(inputTdi.mbist),
            Node.Wire(inputTdi.chain)
        ]

        let portArguments = [
            // JTAG Pads
            Node.PortArg(
                pads.tms,
                Node.Identifier(tms)
            ),
            Node.PortArg(
                pads.tck,
                Node.Identifier(tck)
            ),
            Node.PortArg(
                pads.trst,
                Node.Identifier(trst)
            ),
            Node.PortArg(
                pads.tdi,
                Node.Identifier(tdi)
            ),
            Node.PortArg(
                pads.tdo,
                Node.Identifier(pads.tdo)
            ),
            Node.PortArg(
                pads.tdoEn,
                Node.Identifier(pads.tdoEn)
            ),
            // TAP States
            Node.PortArg(
                states.shift,
                Node.Identifier(states.shift)
            ),
            Node.PortArg(
                states.pause,
                Node.Identifier(states.pause)
            ),
            Node.PortArg(
                states.update,
                Node.Identifier(states.update)
            ),
            Node.PortArg(
                states.capture,
                Node.Identifier(states.capture)
            ),
            Node.PortArg(
                states.idle,
                Node.Identifier(states.idle)
            ),
            Node.PortArg(
                states.reset,
                Node.Identifier(states.reset)
            ),
            Node.PortArg(
                states.exit1,
                Node.Identifier(states.exit1)
            ),
            Node.PortArg(
                states.exit2,
                Node.Identifier(states.exit2)
            ),
            // Select signals for boundary scan or mbist
            Node.PortArg(
                selects.extest,
                Node.Identifier(selects.extest)
            ),
            Node.PortArg(
                selects.samplePreload,
                Node.Identifier(selects.samplePreload)
            ),
            Node.PortArg(
                selects.mbist,
                Node.Identifier(selects.mbist)
            ),
            Node.PortArg(
                selects.debug,
                Node.Identifier(selects.debug)
            ),
            Node.PortArg(
                selects.preloadChain,
                Node.Identifier(selects.preloadChain)
            ),
            //  TDO signal that is connected to TDI of sub-modules.
            Node.PortArg(
                jtagInfo.tdoSignal, 
                Node.Identifier(jtagInfo.tdoSignal)
            ),
            // TDI signals from sub-modules
            Node.PortArg(
                inputTdi.debug,
                Node.Identifier(inputTdi.debug)
            ),
            Node.PortArg(
                inputTdi.bsChain,
                Node.Identifier(inputTdi.bsChain)
            ),
            Node.PortArg(
                inputTdi.mbist,
                Node.Identifier(inputTdi.mbist)
            ),
            Node.PortArg(
                inputTdi.chain,
                Node.Identifier(inputTdi.chain)
            )
        ]

        let submoduleInstance = Node.Instance(
            self.name,
            "__" + self.name + "__",
            Python.tuple(portArguments),
            Python.tuple()
        )

        let tapModule = Node.InstanceList(
            self.name,
            Python.tuple(),
            Python.tuple([submoduleInstance])
        )
        return (tapModule: tapModule, wires: wireDeclarations)
    }
}

struct jtagInfo: Codable {
    var pads: Pad
    var states: State
    var selects: Select
    var tdoSignal: String
    var inputTdi: InputTdi

    init(
        pads: Pad,
        states: State, 
        selects: Select,
        tdoSignal: String,
        inputTdi: InputTdi
    ) {
        self.pads = pads
        self.states = states
        self.selects = selects
        self.tdoSignal = tdoSignal
        self.inputTdi = inputTdi
    }
}


struct Pad: Codable {
    var tms: String
    var tdi: String
    var tdo: String
    var trst: String
    var tck: String
    var tdoEn: String
    init(
        tms: String,
        tdi: String,
        tdo: String,
        trst: String,
        tck: String,
        tdoEn: String
    ) {
        self.tms = tms
        self.tdi = tdi
        self.tdo = tdo
        self.trst = trst
        self.tck = tck
        self.tdoEn = tdoEn
    }
}

struct State: Codable {
    var shift: String
    var pause: String
    var update: String
    var capture: String
    var idle: String
    var reset: String
    var exit1: String
    var exit2: String
    init(
       shift: String,
       pause: String,
       update: String,
       capture: String,
       idle: String,
       reset: String,
       exit1: String,
       exit2: String
    ) {
        self.shift = shift
        self.pause = pause
        self.update = update
        self.capture = capture
        self.idle = idle
        self.reset = reset
        self.exit1 = exit1
        self.exit2 = exit2
    }
}

struct Select: Codable {
    var extest: String
    var samplePreload: String
    var mbist: String
    var debug: String
    var preloadChain: String
    init (
        extest: String,
        samplePreload: String,
        mbist: String,
        debug: String,
        preloadChain: String
    ) {
        self.extest = extest
        self.samplePreload = samplePreload
        self.mbist =  mbist
        self.debug = debug
        self.preloadChain = preloadChain
    }
}

struct InputTdi: Codable {
    var debug: String
    var bsChain: String
    var mbist: String
    var chain: String
    init (
        debug: String,
        bsChain: String,
        mbist: String,
        chain: String
    ) {
        self.debug = debug
        self.bsChain = bsChain
        self.mbist = mbist
        self.chain = chain
    }
}

class SerialVectorCreator {

    static func create(
        tvInfo: TVInfo
    ) throws -> String {

        var scanStatements = ""

        let chainLength: Int = {
            var count = 0
            for input in tvInfo.inputs {
                count += input.width
            }
            return count
        }()
       
        for tvcPair in tvInfo.coverageList {
            var tdi = ""
            let testVector = tvcPair.vector
            for (index, port) in testVector.enumerated() {
                let portVector = String(port, radix: 2)
                let offset = tvInfo.inputs[index].width - portVector.count
                tdi = String(repeating: "0", count: offset) + portVector + tdi
            }

            if let tdiInt = BigUInt(tdi, radix: 2) {
                let tdiHex = String(tdiInt, radix: 16)
                
                let mask = String(repeating: "f", count: tdiHex.count)
                if let output = BigUInt(tvcPair.goldenOutput, radix: 2) {
                    let hexOutput = String(output, radix: 16) 
                    scanStatements += "SDR \(chainLength) TDI (\(tdiHex)) MASK (\(mask)) TDO (\(hexOutput)); \n"
                } else {
                    print("TV golden output \(tvcPair.goldenOutput) is invalid.")
                }
            } else {
                print("TV \(tvcPair.vector) is invalid.")
            }
        }

        var svf: String {
            return """
            ! Begin Test Program
            ! Disable Test Reset line
            TRST OFF;
            ! Initialize UUT
            STATE RESET; 
            ! End IR scans in DRPAUSE
            ENDIR DRPAUSE; 
            ! Trailer & Headers for IR & DR
            HIR 0;
            TIR 0;
            HDR 0;
            TDR 0;
            ! INTEST Instruction
            SIR 4 TDI (4);
            ! San Test Vectors through the scan chain with length:  \(chainLength)
            \(scanStatements)
            """
        }
        return svf;
    }
}