import Foundation
import PythonKit
import BigInt

class TapCreator {
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
        tapInfo: TapInfo,
        tms: String,
        tck: String,
        tdi: String,
        tdo: String,
        tdoEnable_n: String,
        trst: String,
        sin: String,
        sout: String,
        shift: String,
        test: String
    )-> ( tapModule: PythonObject, wires: [PythonObject]) {
        let pads = tapInfo.tap
        let chain = tapInfo.chain

        let wireDeclarations: [PythonObject] = [ 
            Node.Wire(pads.tdo),
            Node.Wire(pads.tdoEnable_n),
            Node.Wire(pads.tms),
            Node.Wire(pads.tdi),
            Node.Wire(pads.trst),
            Node.Wire(chain.sin),
            Node.Wire(chain.sout),
            Node.Wire(chain.shift),
            Node.Wire(chain.test)
        ]

        let portArguments = [
            // Tap Top Module Interface
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
                Node.Identifier(tdo)
            ),
            Node.PortArg(
                pads.tdoEnable_n,
                Node.Identifier(tdoEnable_n)
            ),
            // Chain Interface
            Node.PortArg(
                chain.sin,
                Node.Identifier(sin)
            ),
            Node.PortArg(
                chain.sout,
                Node.Identifier(sout)
            ),
            Node.PortArg(
                chain.test,
                Node.Identifier(test)
            ),
            Node.PortArg(
                chain.shift,
                Node.Identifier(shift)
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

// Tap top module Interface
struct Tap: Codable {
    var tms: String
    var tdi: String
    var tdo: String
    var trst: String
    var tck: String
    var tdoEnable_n: String
    init(
        tms: String,
        tdi: String,
        tdo: String,
        trst: String,
        tck: String,
        tdoEnable_n: String
    ) {
        self.tms = tms
        self.tdi = tdi
        self.tdo = tdo
        self.trst = trst
        self.tck = tck
        self.tdoEnable_n = tdoEnable_n
    }
}

// Internal Chain Interface
struct Chain: Codable {
    var sin: String
    var sout: String
    var shift: String
    var test: String

    init(
       sin: String,
       sout: String,
       shift: String,
       test: String
    ) {
        self.sin = sin
        self.sout = sout
        self.shift = shift
        self.test = test
    }
}

// Aggregate
struct TapInfo: Codable {
    var tap: Tap
    var chain: Chain
    
    init(
        tap: Tap,
        chain: Chain
    ) {
        self.tap = tap
        self.chain = chain
    }

    static let `default`: TapInfo = try! JSONDecoder().decode(TapInfo.self, from: Data(TapCreator.info.utf8))
}