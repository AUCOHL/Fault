import Foundation
import PythonKit

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
        
        var wireDeclarations: [PythonObject] = [ 
            Node.Wire(tapPads.tdoEn),
            Node.Wire(tapStates.shiftDataReg),
            Node.Wire(tapStates.pauseDataReg),
            Node.Wire(tapStates.updateDataReg),
            Node.Wire(tapStates.captureDataReg),

            Node.Wire(selectSignals.extest),
            Node.Wire(selectSignals.samplePreload),
            Node.Wire(selectSignals.mbist),
            Node.Wire(selectSignals.debug),

            Node.Wire(jtagInfo.tdoSignal),

            Node.Wire(tdiSignals.debug),
            Node.Wire(tdiSignals.bsChain),
            Node.Wire(tdiSignals.mbist)
        ]

        let portArguments = [
            // JTAG Pads
            Node.PortArg(tapPads.tms, Node.Identifier(tms)),
            Node.PortArg(tapPads.tck, Node.Identifier(tck)),
            Node.PortArg(tapPads.trst, Node.Identifier(trst)),
            Node.PortArg(tapPads.tdi, Node.Identifier(tdi)),
            Node.PortArg(tapPads.tdo, Node.Identifier(tdo)),
            Node.PortArg(tapPads.tdoEn, Node.Identifier("tdo_padoe_o")),
            // TAP States
            Node.PortArg(tapStates.shiftDataReg, Node.Identifier("shift_dr_o")),
            Node.PortArg(tapStates.pauseDataReg, Node.Identifier("pause_dr_o")),
            Node.PortArg(tapStates.updateDataReg, Node.Identifier("update_dr_o")),
            Node.PortArg(tapStates.captureDataReg, Node.Identifier("capture_dr_o")),
            // Select signals for boundary scan or mbist
            Node.PortArg(selectSignals.extest, Node.Identifier("extest_select_o")),
            Node.PortArg(selectSignals.samplePreload, Node.Identifier("sample_preload_select_o")),
            Node.PortArg(selectSignals.mbist, Node.Identifier("mbist_select_o")),
            Node.PortArg(selectSignals.debug, Node.Identifier("debug_select_o")),
            //  TDO signal that is connected to TDI of sub-modules.
            Node.PortArg(jtagInfo.tdoSignal, Node.Identifier("tdo_o")),
            // TDI signals from sub-modules
            Node.PortArg(tdiSignals.debug, Node.Identifier("debug_tdi_i")),
            Node.PortArg(tdiSignals.bsChain, Node.Identifier("bs_chain_tdi_i")),
            Node.PortArg(tdiSignals.mbist, Node.Identifier("mbist_tdi_i"))
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


    //var tapDefinition: String
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
    ){
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
    ){
        self.tms = tms
        self.tdi = tdi
        self.tdo = tdo
        self.trst = trst
        self.tck = tck
        self.tdoEn = tdoEn
    }
}

struct JTAGState: Codable {
    var shiftDataReg: String
    var pauseDataReg: String
    var updateDataReg: String
    var captureDataReg: String

    init(
       shiftDataReg: String,
       pauseDataReg: String,
       updateDataReg: String,
       captureDataReg: String 
    ){
        self.shiftDataReg = shiftDataReg
        self.pauseDataReg = pauseDataReg
        self.updateDataReg = updateDataReg
        self.captureDataReg = captureDataReg
    }
}

struct selectSignals: Codable {
    var extest: String
    var samplePreload: String
    var mbist: String
    var debug: String

    init (
        extest: String,
        samplePreload: String,
        mbist: String,
        debug: String
    ){
        self.extest = extest
        self.samplePreload = samplePreload
        self.mbist =  mbist
        self.debug = debug
    }
}

struct tdiSignals: Codable {
    var debug: String
    var bsChain: String
    var mbist: String

    init (
        debug: String,
        bsChain: String,
        mbist: String
    ){
        self.debug = debug
        self.bsChain = bsChain
        self.mbist = mbist
    }
}