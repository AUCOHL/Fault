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

            reg store;

            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    store <= sin;
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