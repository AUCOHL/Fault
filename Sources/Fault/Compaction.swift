
class Compactor {

    static func compact(
        coverageList: [TVCPair]
    ) -> [TVCPair] {

        var sa0 = Set<String>()
        var sa1 = Set<String>()

        var sa0Covered = Set<String>()
        var sa1Covered = Set<String>()
        
        let tvCount = coverageList.count

        // Construct Set of all Faults
        for tvPair in coverageList{
            sa0.formUnion(tvPair.coverage.sa0)
            sa1.formUnion(tvPair.coverage.sa1)
        }

        // Find Essential Faults
        let result = Compactor.findEssentials(coverageList: coverageList, sa0: sa0, sa1: sa1)

        // Essential Fault columns
        for fault in result.faultSA0 {
            sa0Covered.insert(fault)
        }

        for fault in result.faultSA1 {
            sa1Covered.insert(fault)
        }
        
        var rowCount: [TestVector:UInt] = [TestVector:UInt]();

        for tvPair in coverageList {
            rowCount[tvPair.vector] = UInt(tvPair.coverage.sa0.count + tvPair.coverage.sa1.count)
        }

        var vectors = result.vectors

        repeat {
            let sortedCount = rowCount.sorted { $0.1 > $1.1 }
            let tvPairDominant = coverageList.filter({$0.vector == sortedCount[0].key})[0]
            
            for fault in tvPairDominant.coverage.sa0 {
                sa0Covered.insert(fault)
            }
            for fault in tvPairDominant.coverage.sa1 {
                sa1Covered.insert(fault)
            }

            // Update  Row Count
            for tvPair in coverageList {
                var sa0: [String] = []
                 if(tvPair.coverage.sa0.count != 0){
                     sa0 = tvPair.coverage.sa0.filter {
                         !sa0Covered.contains($0)
                     }
                 }
                var sa1: [String] = []
                if (tvPair.coverage.sa1.count != 0){
                    sa1 = tvPair.coverage.sa1.filter {
                        !sa1Covered.contains($0)
                    }    
                }
                rowCount[tvPair.vector] = UInt(sa0.count + sa1.count)
            }

            vectors.insert(sortedCount[0].key)
        } while ((sa0Covered.count != sa0.count) || (sa1Covered.count != sa1.count))  

        let filtered = coverageList.filter { vectors.contains($0.vector) }
        
        // Verify that Compaction didn't reduce the coverage
        var sa0Final = Set<String>()
        var sa1Final = Set<String>()

        for tvPair in filtered {
            sa0Final.formUnion(tvPair.coverage.sa0)
            sa1Final.formUnion(tvPair.coverage.sa1)
        }
        if sa0 == sa0Final && sa1 == sa1Final {
            let ratio = (1 - (Float(filtered.count) / Float(tvCount))) * 100 
            print("Initial TV Count: \(tvCount). Compacted TV Count: \(filtered.count). ")
            print("Compaction is successfuly concluded with a reduction percentage of : \(String(format: "%.2f", ratio))% .\n")
        }
        else {
            print("Error: All faults aren't covered after compaction .\n")
        }
        return filtered
    }   
    
    private static func findEssentials(
        coverageList: [TVCPair] ,
        sa0: Set<String>,
        sa1: Set<String>
    ) -> ( vectors: Set<TestVector> , faultSA0: [String], faultSA1: [String]) {

        var vectors = Set<TestVector>()
        var faultSA0 : [String] = []
        var faultSA1 : [String] = []

        var tvRow : TestVector = []
        var count = 0

        for fault in sa0 {
            count = 0
            for tvPair in coverageList{
                if (tvPair.coverage.sa0.contains(fault)){
                    count = count + 1
                    tvRow = tvPair.vector
                }
            }
            if (count == 1){
                faultSA0.append(fault)
                vectors.insert(tvRow)
            }
        }

        for fault in sa1 {
            count = 0
            for tvPair in coverageList{
                if (tvPair.coverage.sa1.contains(fault)){
                    count = count + 1
                    tvRow = tvPair.vector
                }
            }
            if (count == 1){
                faultSA1.append(fault)
                vectors.insert(tvRow)
            }
        }

        return (
            vectors: vectors,
            faultSA0: faultSA0,
            faultSA1: faultSA1
        )
    }
}