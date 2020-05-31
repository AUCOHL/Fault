import Foundation
import PythonKit

struct BenchCircuit: Codable {
    var cells: [BenchCell]

    init(cells: [BenchCell]){
        self.cells = cells
    }

    static func extract(definitions: PythonObject) throws -> [BenchCell] {

        var cells: [BenchCell] = []
        for definition in definitions {

            let type = Python.type(definition).__name__

            if type == "ModuleDef" {

                let (_, inputs, outputs) = try Port.extract(from: definition)
                let cellName = definition.name

                var cellStatements: [String] = []
               
                var cellOutput: String = ""
                for output in outputs {
                    cellOutput = String(describing: output.name)
                }

                var cellInputs: [String] = []
                for input in inputs {
                    cellInputs.append(String(describing: input.name))
                }

                for item in definition.items {

                    let type = Python.type(item).__name__

                    if type == "InstanceList" {
                        let instance = item.instances[0]

                        let outArgname = String(describing: instance.portlist[0].argname) 
                        let output = (outArgname == cellOutput) ? outArgname : "__\(outArgname)___" 
                          
                        var benchStatement = "("
                        for hook in instance.portlist[1...]{
                            let argname = String(describing: hook.argname)
                            
                            if cellInputs.contains(argname) {
                                benchStatement += "\(hook.argname), "
                            }
                            else {
                                benchStatement += "__\(hook.argname)___, "
                            }
                        }

                        benchStatement = String(benchStatement.dropLast(2))
                        benchStatement += ")"

                        switch instance.module {
                        case "and":
                            cellStatements.append("\(output) = AND" + benchStatement)
                            break
                        case "or":
                            cellStatements.append("\(output) = OR" + benchStatement)
                            break
                        case "xor":
                            let inputA = instance.portlist[1].argname
                            let inputB = instance.portlist[2].argname
                            cellStatements.append(contentsOf: [
                                "__or_out___ = OR(\(inputA), \(inputB))",
                                "__nand_out___ = NAND(\(inputA), \(inputB))",
                                "\(output) = AND(__or_out___, __nand_out___)"
                            ])
                            break
                        case "buf":
                            cellStatements.append("\(output) = BUFF" + benchStatement)
                            break
                        case "not":
                            cellStatements.append("\(output) = NOT" + benchStatement)
                            break
                        default:
                            print("[Warning]: can't expand \(instance.module) in \(cellName) to primitive cells")
                        }
                    }
                }

                let cell = BenchCell(
                    name: String(cellName)!,
                    inputs: cellInputs,
                    output: cellOutput,
                    statements: cellStatements
                )
                cells.append(cell)
            }
        }

        return cells
    }
   
}

struct BenchCell: Codable {
    var name: String
    var inputs: [String]
    var output: String
    var statements: [String]

    init(
        name: String,
        inputs: [String],
        output: String,
        statements: [String]
    ){
        self.name = name
        self.inputs = inputs
        self.output = output
        self.statements = statements
    }

    func extract(name: String, inputs: [String:String], output: [String]) throws -> String {
        do {
            let regexOutput = try NSRegularExpression(pattern: "\(self.output) = ")
            let regexWires = try NSRegularExpression(pattern: "___")
            let outputName = (output[0].hasPrefix("\\")) ? "\\\(output[0])" : "\(output[0])"

            var benchStatements = self.statements
            for (index, _) in statements.enumerated() {
                
                var range = NSRange(benchStatements[index].startIndex..., in: benchStatements[index])
                benchStatements[index] = regexOutput.stringByReplacingMatches(
                    in: benchStatements[index],
                    options: [],
                    range: range,
                    withTemplate: "\(outputName) = ")

                range = NSRange(benchStatements[index].startIndex..., in:  benchStatements[index]) 
                benchStatements[index] = regexWires.stringByReplacingMatches(
                    in: benchStatements[index],
                    options: [],
                    range: range,
                    withTemplate: "__\(name)")

                for input in self.inputs {
                    let regexInput = try NSRegularExpression(pattern: "\(input)(?=\\s*,|\\s*\\))")
                    let name = (inputs[input]!.hasPrefix("\\")) ? "\\\(inputs[input]!)" : "\(inputs[input]!)"

                    range = NSRange(benchStatements[index].startIndex..., in:  benchStatements[index])
                    benchStatements[index] = regexInput.stringByReplacingMatches(
                        in: benchStatements[index],
                        options: [],
                        range: NSRange(benchStatements[index].startIndex..., in: benchStatements[index]),
                        withTemplate: name )
                }
            }

            var cellDefinition = ""
            for statement in benchStatements {
                cellDefinition += "\(statement) \n"
            }
            cellDefinition = String(cellDefinition.dropLast(1))

            return cellDefinition
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return ""
        }
    }
}