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
        self.inputName = "\(name)_input"
        self.outputName = "\(name)_output"

        self.clock = clock
        self.clockIdentifier = Node.Identifier(clock)

        self.reset = reset
        self.resetIdentifier = Node.Identifier(reset)

        self.resetActive = resetActive

        self.testing = testing
        self.testingIdentifier = Node.Identifier(testing)

        self.shift = shift
        self.shiftIdentifier = Node.Identifier(shift)

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
        let dinArg = (max == 0) ? dinIdentifier: Node.Pointer(dinIdentifier, ordinalConstant)
        let doutArg = (max == 0) ?  doutIdentifier: Node.Pointer(doutIdentifier, ordinalConstant)

        let portArguments = [
            Node.PortArg("din", dinArg),
            Node.PortArg("dout", doutArg),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("sout", soutIdentifier),
            Node.PortArg("clock", clockIdentifier),
            Node.PortArg("reset", resetIdentifier),
            Node.PortArg("testing", testingIdentifier),
            Node.PortArg("shift", shiftIdentifier)
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
        return """
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