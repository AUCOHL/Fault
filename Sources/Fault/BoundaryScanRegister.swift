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
    
    private var captureIdentifier: PythonObject
    private var updateIdentifier: PythonObject
    private var shiftIdentifier: PythonObject
    private var clockIdentifier: PythonObject
    private var resetIdentifier: PythonObject

    private var Node: PythonObject

    init(
        name: String,
        clock: String,
        reset: String,
        resetActive: Simulator.Active,
        capture: String,
        update: String,
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

        self.captureIdentifier = Node.Identifier(capture)
        self.updateIdentifier = Node.Identifier(update)
        self.shiftIdentifier = Node.Identifier(shift)

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
        
        var portArguments = [
            Node.PortArg("din", Node.Pointer(dinIdentifier, ordinalConstant)),
            Node.PortArg("dout", Node.Pointer(doutIdentifier, ordinalConstant)),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("sout", soutIdentifier),
            Node.PortArg("clock", clockIdentifier),
            Node.PortArg("reset", resetIdentifier),
            Node.PortArg("shiftDR", shiftIdentifier),
            Node.PortArg("captureDR", captureIdentifier)
        ]

        if (!input){
            portArguments.append(Node.PortArg("updateDR", updateIdentifier))
        }

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
            shiftDR,
            captureDR
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, shiftDR, captureDR;

            reg store;  
            reg sout;  
            
            wire SelectedInput = captureDR ? din : sin;

            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    if(captureDR | shiftDR) 
                        store <= SelectedInput;
                end
            end

            always @ (negedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                 if (\(resetActive == .high ? "" : "~") reset) begin
                    sout <= 1'b0;
                end else begin
                    sout <= store;
                end
            end
        assign dout = shiftDR ? store : din;

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
            shiftDR,
            captureDR,
            updateDR,
            extest
        );
            input din; output dout;
            input sin; output sout;
            input clock, reset, shiftDR, captureDR, updateDR;
            input extest;

            reg sout; 
            reg store;  
            reg shifted;

            wire SelectedInput = captureDR ? din : sin;

            always @ (posedge clock or \(resetActive == .high ? "posedge" : "negedge") reset) begin
                if (\(resetActive == .high ? "" : "~") reset) begin
                    store <= 1'b0;
                end else begin
                    if (captureDR | shiftDR)
                        store <= SelectedInput;
                end
            end

            always @ (negedge clock) begin
                sout <= store;
            end

            always @ (negedge clock) begin
                if (updateDR)
                    shifted <= sout;
            end

            assign dout = extest? shifted : din;

        endmodule

        """
    }
}