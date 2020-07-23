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

    private var clockIdentifier: PythonObject
    private var resetIdentifier: PythonObject
    private var testingIdentifier: PythonObject

    private var Node: PythonObject

    init(
        name: String,
        clock: String,
        reset: String,
        resetActive: Simulator.Active,
        testing: String,
        using Node: PythonObject
    ) {
        self.name = name
        self.inputName = "\(name)_input"
        self.outputName = "\(name)_output"

        self.clock = clock
        self.clockIdentifier = Node.Identifier(clock)

        self.reset = reset
        self.resetIdentifier = Node.Identifier(reset)

        self.resetActive = resetActive

        self.testing = testing
        self.testingIdentifier = Node.Identifier(testing)

        self.Node = Node
    }

    func create(
        ordinal: Int,
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
        
        let portArguments = [
            Node.PortArg("din", Node.Pointer(dinIdentifier, ordinalConstant)),
            Node.PortArg("dout", Node.Pointer(doutIdentifier, ordinalConstant)),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("sout", soutIdentifier),
            Node.PortArg("clock", clockIdentifier),
            Node.PortArg("reset", resetIdentifier),
            Node.PortArg("testing", testingIdentifier)
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
        return """
        module \(inputName) (
            din,
            dout,
            sin,
            sout,
            clock,
            reset,
            testing
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, testing;

            wire testMode = 1;
            reg store;
            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    store <= testing ? sin: dout;
                end
            end
            assign sout = store;
            assign dout = testMode ? store : din;
        endmodule
            
        """
    }

    var outputDefinition: String {
        return """
        module \(outputName) (
            din,
            dout,
            sin,
            sout,
            clock,
            reset,
            testing
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, testing;
            reg store;
            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    store <= testing ? sin: din;
                end
            end
            assign sout = store;
            assign dout = din;
        endmodule
            
        """
    }
}


class scanCellCreator {

    var name: String
    var counter: Int = 0
    
    var clock: String
    var shift: String
    private var Node: PythonObject

    private var clockIdentifier: PythonObject
    private var shiftIdentifier: PythonObject

    init(
        name: String,
        clock: String,
        shift: String,
        using Node: PythonObject
    ) {
        self.name = name
        self.clock = clock
        self.clockIdentifier = Node.Identifier(clock)

        self.shift = shift
        self.shiftIdentifier = Node.Identifier(shift)

        self.Node = Node
    }

    func create(
        din: String,
        sin: String,
        out: String
    ) -> PythonObject {
        let dinIdentifier = Node.Identifier(din)
        let sinIdentifier = Node.Identifier(sin)
        let outIdentifier = Node.Identifier(out)

        let portArguments = [
            Node.PortArg("din", dinIdentifier),
            Node.PortArg("out", outIdentifier),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("shift", shiftIdentifier),
            Node.PortArg("clock", clockIdentifier),
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

    var cellDefinition: String {
        return """
         module \(name) (
            din,     
            out,   
            sin, 
            shift, 
            clock
        );
            input din, sin, shift;
            output out;
            input clock;

            reg flip_flop;  
        
            always @ (posedge clock) begin
                flip_flop <= sin;
            end
            
            assign out = shift ? flip_flop : din;
            
        endmodule

        """
    }
}

class ScanChain {
    enum ChainKind: String, Codable{
        case posedge
        case negedge
        case boundary
    }
    var sin: String
    var sinIdentifier: PythonObject

    var sout: String
    var soutIdentifier: PythonObject

    var shift: String
    var shiftIdentifier: PythonObject

    var capture: String
    var captureIdentifier: PythonObject

    var clock: String
    var clockIdentifier: PythonObject

    var kind: ChainKind

    var length: Int = 0
    var order: [ChainRegister] = []

    var previousOutput: PythonObject
    private var Node: PythonObject

    init(
        sin:String,
        sout: String,
        shift: String,
        capture: String = "capture", 
        clock: String,
        kind: ChainKind,
        using Node: PythonObject
    ) {
        self.sin = sin
        self.sinIdentifier = Node.Identifier(sin)

        self.sout = sout
        self.soutIdentifier = Node.Identifier(sout)

        self.shift = shift
        self.shiftIdentifier = Node.Identifier(shift)

        self.clock = clock
        self.clockIdentifier = Node.Identifier(clock)

        self.capture = capture
        self.captureIdentifier = Node.Identifier(capture)

        self.kind = kind
        self.Node = Node

        previousOutput = self.sinIdentifier
    }

    func add (
        name: String,
        kind: ChainRegister.Kind,
        width: Int = 1
    ) {
        self.order.append( 
            ChainRegister(
                name: name,
                kind: kind,
                width: width
            )
        )
        self.length += width
    }

    func order (
        start: Int
    ) -> Int {
        var count: Int = start
        for (i, _) in self.order.enumerated() {
            self.order[i].ordinal = count
            count += 1
        }
        return count
    }
}