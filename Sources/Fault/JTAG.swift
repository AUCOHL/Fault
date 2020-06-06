import Foundation
import PythonKit
import BigInt

class JTAGCreator {
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
        jtagInfo: JTAGInfo,
        tms: String,
        tck: String,
        tdi: String,
        tdo: String,
        trst: String
    )-> ( tapModule: PythonObject, wires: [PythonObject]) {
        let tapPads = jtagInfo.pads
        let tapStates = jtagInfo.tapStates
        let selectSignals = jtagInfo.selectSignals 
        let tdiSignals = jtagInfo.tdiSignals
        
        let wireDeclarations: [PythonObject] = [ 
            Node.Wire(tapPads.tdo),
            Node.Wire(tapPads.tdoEn),
            Node.Wire(tapStates.shift),
            Node.Wire(tapStates.pause),
            Node.Wire(tapStates.update),
            Node.Wire(tapStates.capture),
            Node.Wire(selectSignals.extest),
            Node.Wire(selectSignals.samplePreload),
            Node.Wire(selectSignals.mbist),
            Node.Wire(selectSignals.debug),
            Node.Wire(selectSignals.scanIn),
            Node.Wire(jtagInfo.tdoSignal),
            Node.Wire(tdiSignals.debug),
            Node.Wire(tdiSignals.bsChain),
            Node.Wire(tdiSignals.mbist),
            Node.Wire(tdiSignals.scanIn)
        ]

        let portArguments = [
            // JTAG Pads
            Node.PortArg(
                tapPads.tms,
                Node.Identifier(tms)
            ),
            Node.PortArg(
                tapPads.tck,
                Node.Identifier(tck)
            ),
            Node.PortArg(
                tapPads.trst,
                Node.Identifier(trst)
            ),
            Node.PortArg(
                tapPads.tdi,
                Node.Identifier(tdi)
            ),
            Node.PortArg(
                tapPads.tdo,
                Node.Identifier(tapPads.tdo)
            ),
            Node.PortArg(
                tapPads.tdoEn,
                Node.Identifier(tapPads.tdoEn)
            ),
            // TAP States
            Node.PortArg(
                tapStates.shift,
                Node.Identifier(tapStates.shift)
            ),
            Node.PortArg(
                tapStates.pause,
                Node.Identifier(tapStates.pause)
            ),
            Node.PortArg(
                tapStates.update,
                Node.Identifier(tapStates.update)
            ),
            Node.PortArg(
                tapStates.capture,
                Node.Identifier(tapStates.capture)
            ),
            // Select signals for boundary scan or mbist
            Node.PortArg(
                selectSignals.extest,
                Node.Identifier(selectSignals.extest)
            ),
            Node.PortArg(
                selectSignals.samplePreload,
                Node.Identifier(selectSignals.samplePreload)
            ),
            Node.PortArg(
                selectSignals.mbist,
                Node.Identifier(selectSignals.mbist)
            ),
            Node.PortArg(
                selectSignals.debug,
                Node.Identifier(selectSignals.debug)
            ),
            Node.PortArg(
                selectSignals.scanIn,
                Node.Identifier(selectSignals.scanIn)
            ),
            //  TDO signal that is connected to TDI of sub-modules.
            Node.PortArg(
                jtagInfo.tdoSignal,
                Node.Identifier(jtagInfo.tdoSignal)
            ),
            // TDI signals from sub-modules
            Node.PortArg(
                tdiSignals.debug,
                Node.Identifier(tdiSignals.debug)
            ),
            Node.PortArg(
                tdiSignals.bsChain,
                Node.Identifier(tdiSignals.bsChain)
            ),
            Node.PortArg(
                tdiSignals.mbist,
                Node.Identifier(tdiSignals.mbist)
            ),
            Node.PortArg(
                tdiSignals.scanIn,
                Node.Identifier(tdiSignals.scanIn)
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

struct JTAGInfo: Codable {
    var pads: JTAGPad; 
    var tapStates : JTAGState;
    var selectSignals : selectSignals;
    var tdoSignal : String;
    var tdiSignals : tdiSignals;

    init(
        pads: JTAGPad,
        tapStates: JTAGState, 
        selectSignals: selectSignals,
        tdoSignal : String,
        tdiSignals: tdiSignals
    ) {
        self.pads = pads
        self.tapStates = tapStates
        self.selectSignals = selectSignals
        self.tdoSignal = tdoSignal
        self.tdiSignals = tdiSignals
    }
}


struct JTAGPad: Codable {
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

struct JTAGState: Codable {
    var shift: String
    var pause: String
    var update: String
    var capture: String

    init(
       shift: String,
       pause: String,
       update: String,
       capture: String 
    ) {
        self.shift = shift
        self.pause = pause
        self.update = update
        self.capture = capture
    }
}

struct selectSignals: Codable {
    var extest: String
    var samplePreload: String
    var mbist: String
    var debug: String
    var scanIn: String
    init (
        extest: String,
        samplePreload: String,
        mbist: String,
        debug: String,
        scanIn: String
    ) {
        self.extest = extest
        self.samplePreload = samplePreload
        self.mbist =  mbist
        self.debug = debug
        self.scanIn = scanIn
    }
}

struct tdiSignals: Codable {
    var debug: String
    var bsChain: String
    var mbist: String
    var scanIn: String
    
    init (
        debug: String,
        bsChain: String,
        mbist: String,
        scanIn: String
    ) {
        self.debug = debug
        self.bsChain = bsChain
        self.mbist = mbist
        self.scanIn = scanIn
    }
}


class SerialVectorCreator {

    static func create(
        tvInfo: TVInfo
    ) throws -> String {
        var positions: [Int] = []
        let dffCount: Int = {
            var count = 0
            for (index, input) in tvInfo.inputs.enumerated() {
                if(input.name.hasPrefix("_")){
                    count += 1
                    positions.append(index)
                }
            }
            return count
        }()
        var scanStatements = ""
        for tvcPair in tvInfo.coverageList {
            var tdi = ""
            let testVector = positions.map {tvcPair.vector[$0]}
            for port in testVector {
                tdi += String(port, radix: 16) 
            }
            if let tdiInt = BigUInt(tdi, radix: 2) {
                let tdiHex = String(tdiInt, radix: 16)
                let mask = String(repeating: "f", count: tdiHex.count)

                let offset = tvcPair.goldenOutput.count - dffCount
                let start = tvcPair.goldenOutput.index(tvcPair.goldenOutput.startIndex, offsetBy: offset) 
                let range = start..<tvcPair.goldenOutput.endIndex
                if let output = BigUInt(tvcPair.goldenOutput[range], radix: 2) {
                    let hexOutput = String(output, radix: 16) 
                    scanStatements += "SDR \(dffCount) TDI (\(tdiHex)) MASK (\(mask)) TDO (\(hexOutput)); \n"
                } else {
                    print("TV \(tvcPair.vector) is invalid.")
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
            ! SCANIN Instruction
            SIR 4 TDI (4);
            ! San Test Vectors
            \(scanStatements)
            """
        }
        return svf;
    }
}