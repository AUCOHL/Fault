import BigInt

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
                if let output = BigUInt(tvcPair.goldenOutput, radix: 16) {
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