import Foundation
import Defile
import PythonKit

class TFSimulator {

    static func simulate(
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String> = [],
        behavior: [Simulator.Behavior] = [],
        outputs: [Port],
        initialVectorCount: Int,
        incrementingBy increment: Int,
        minimumCoverage: Float,
        ceiling: Int,
        randomGenerator: String,
        sampleRun: Bool,
        using iverilogExecutable: String,
        with vvpExecutable: String
    ) throws -> (coverageList: [TFCPair], coverage: Float) {
        var testVectorHash: Set<TestVector> = []

        var vectorsList: [vectorCovers] = []
        var coverageList: [TFCPair] = []
        var coverage: Float = 0.0

        var st0Covered: Set<String> = []
        st0Covered.reserveCapacity(faultPoints.count)
        var st1Covered: Set<String> = []
        st1Covered.reserveCapacity(faultPoints.count)

        var totalTVAttempts = 0
        var tvAttempts = (initialVectorCount < ceiling) ? initialVectorCount : ceiling
        
        let rng: URNG = URNGFactory.get(name: randomGenerator)!

        var faultMatches : [String:(TestVector, TestVector)] = [:]
        for fault in faultPoints {
            faultMatches[fault] = ([],[])
        }

        while coverage < minimumCoverage && totalTVAttempts < ceiling {
            if totalTVAttempts > 0 {
                print("Minimum coverage not met (\(coverage * 100)%/\(minimumCoverage * 100)%,) incrementing to \(totalTVAttempts + tvAttempts)…")
            }

            var futureList: [Future] = []
            var testVectors: [TestVector] = []

            for _ in 0..<tvAttempts {
                var testVector: TestVector = []
                for input in inputs {
                    testVector.append(rng.generate(bits: input.width))
                }
                if testVectorHash.contains(testVector) {
                    continue
                }
                testVectorHash.insert(testVector)
                testVectors.append(testVector)
            }

            if testVectors.count < tvAttempts {
                print("Skipped \(tvAttempts - testVectors.count) duplicate generated test vectors.")
            }

            let tempDir = "\(NSTemporaryDirectory())"
            for vector in testVectors {
                let future = Future {
                    do {
                        let (sa0, _) =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: cells,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 0,
                                delayFault: true,
                                cleanUp: !sampleRun,
                                goldenOutput: false,
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        let (sa1, _) =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: cells,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 1,
                                delayFault: true,
                                cleanUp: !sampleRun,
                                goldenOutput: false,
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        let zeroInit = sa0.filter {$0.starts(with: "v1: ")}.map{ String($0.dropFirst(4))}
                        let oneInit = sa1.filter {$0.starts(with: "v1: ")}.map{ String($0.dropFirst(4))}
                        let stuckAt0 = sa0.filter{!$0.starts(with: "v1: ")}
                        let stuckAt1 = sa1.filter{!$0.starts(with: "v1: ")}

                        return (
                            Covers: Coverage(sa0: stuckAt0, sa1: stuckAt1) ,
                            init: (zeroInit, oneInit)
                        )
                    } catch {
                        print("IO Error @ vector \(vector)")
                        return (Covers: Coverage(sa0: [], sa1: []) , Output: "")
                    }
                }
                futureList.append(future)
                if sampleRun {
                    break
                }
            }

            for future in futureList {
                let (coverLists, (zeroInit, oneInit)) = future.value as! (Coverage, ([String], [String]))
                vectorsList.append(
                    vectorCovers(
                        sa0: coverLists.sa0,
                        sa1: coverLists.sa1,
                        zeroInit: zeroInit,
                        oneInit: oneInit
                    )
                ) 
            }

            let skipped = 
                (vectorsList.count > testVectors.count ) ? vectorsList.count - testVectors.count : 0
            for currIndex in 0..<vectorsList.count-skipped {
                  for i in currIndex+skipped..<vectorsList.count {
                    let (first, second) = vectorCovers.match(v1Covers: vectorsList[currIndex], v2Covers: vectorsList[i])
                    let st0Faults = first.st0 + second.st0
                    let st1Faults = first.st1 + second.st0
                    for fault in st0Faults {
                        st0Covered.insert(fault)
                    }
                    for fault in st1Faults {
                        st1Covered.insert(fault)
                    }
                    if first.st0.count > 0 || first.st1.count > 0 {
                        coverageList.append(
                            TFCPair(
                                initVector: testVectors[currIndex],
                                faultVector: testVectors[i-skipped],
                                coverage: TFCoverage(st0: first.st0, st1: first.st1)
                            )
                        )
                    } 
                    if second.st0.count > 0 || second.st1.count > 0 {
                        coverageList.append(
                            TFCPair(
                                initVector: testVectors[i-skipped],
                                faultVector: testVectors[currIndex],
                                coverage: TFCoverage(st0: second.st0, st1: second.st1)
                            )
                        )
                    }    
                }
            }
          
            coverage =
                Float(st0Covered.count + st1Covered.count) /
                Float(2 * faultPoints.count)
            
            totalTVAttempts += tvAttempts
            let remainingTV = ceiling - totalTVAttempts
            tvAttempts = (remainingTV < increment) ? remainingTV : increment
        }
        
        if coverage < minimumCoverage {
            print("Hit ceiling. Settling for current coverage.")
        }

        return (coverageList: coverageList, coverage: coverage)
    }
}