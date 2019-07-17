import Foundation
import PythonKit

class BoundaryScanRegisterCreator {
    var name: String
    var counter: Int = 0
    
    var rstBar: String
    var shiftBR: String
    var clockBR: String
    var updateBR: String
    var modeControl: String

    private var rstBarIdentifier: PythonObject
    private var shiftBRIdentifier: PythonObject
    private var clockBRIdentifier: PythonObject
    private var updateBRIdentifier: PythonObject
    private var modeControlIdentifier: PythonObject

    private var Node: PythonObject

    init(
        name: String,
        rstBar: String,
        shiftBR: String,
        clockBR: String,
        updateBR: String,
        modeControl: String,
        using Node: PythonObject
    ) {
        self.name = name

        self.rstBar = rstBar
        self.rstBarIdentifier = Node.Identifier(rstBar)

        self.shiftBR = shiftBR
        self.shiftBRIdentifier = Node.Identifier(shiftBR)
        
        self.clockBR = clockBR
        self.clockBRIdentifier = Node.Identifier(clockBR)

        self.updateBR = updateBR
        self.updateBRIdentifier = Node.Identifier(updateBR)

        self.modeControl = modeControl
        self.modeControlIdentifier = Node.Identifier(modeControl)

        self.Node = Node
    }

    func create(
        ordinal: Int,
        din: String,
        dout: String,
        sin: String,
        sout: String
    ) -> PythonObject {
        let dinIdentifier = Node.Identifier(din)
        let doutIdentifier = Node.Identifier(dout)
        let sinIdentifier = Node.Identifier(sin)
        let soutIdentifier = Node.Identifier(sout)
        let ordinalConstant = Node.Constant(ordinal)
        
        let portArguments = [
            Node.PortArg("din", Node.Pointer(dinIdentifier, ordinalConstant)),
            Node.PortArg("dout", Node.Pointer(doutIdentifier, ordinalConstant)),
            Node.PortArg("sin", sinIdentifier),
            Node.PortArg("sout", soutIdentifier),
            Node.PortArg("rstBar", rstBarIdentifier),
            Node.PortArg("shiftBR", shiftBRIdentifier),
            Node.PortArg("updateBR", updateBRIdentifier),
            Node.PortArg("modeControl", modeControlIdentifier)
        ]

        let submoduleInstance = Node.Instance(
            name,
            "__" + name + "_" + String(describing: counter) + "__",
            Python.tuple(portArguments),
            Python.tuple()
        );

        counter += 1

        return Node.InstanceList(
            name,
            Python.tuple(),
            Python.tuple([submoduleInstance])
        )
    }

    var definition: String {
        return """
        module \(name)(
            rstBar,
            din,
            dout,
            sin,
            sout,
            shiftBR,
            clockBR,
            updateBR,
            modeControl
        );
            input rstBar;
            input din; output dout;
            input sin; output sout;
            input shiftBR, clockBR, updateBR, modeControl;

            reg shift;

            always @ (posedge clockBR or negedge rstBar) begin
                if (!rstBar) begin
                    shift <= 1'b0;
                end else begin
                    shift <= (shiftBR) ? sin : din;
                end
            end

            assign sout = shift;

            reg update;

            always @ (posedge updateBR or negedge rstBar) begin
                if (!rstBar) begin
                    update <= 1'b0;
                end else begin
                    update <= shift;
                end
            end

            assign dout = modeControl ? shift : update;

        endmodule
            
        """
    }
}