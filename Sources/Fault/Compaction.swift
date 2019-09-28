struct chartRow {
    var sa0 : [String: UInt]
    var sa1 : [String: UInt]

    init(sa0: [String: UInt], sa1: [String: UInt]){
        self.sa0 = sa0
        self.sa1 = sa1
    }

    func getFaults() -> (sa0: [String], sa1: [String]) {

        let sa0Covered = self.sa0.filter { $0.value == 1 }
        let sa1Covered = self.sa1.filter { $0.value == 1 }

        return (
            sa0: Array(sa0Covered.keys),
            sa1: Array(sa1Covered.keys)
        )
    }
}

class Compactor {

    static func compact(
        coverageList: [TVCPair]
    ) -> [TVCPair] {

        var sa0 = Set<String>()
        var sa1 = Set<String>()

        var row  = chartRow(sa0: [String: UInt](), sa1: [String: UInt]())
        var chart: [TestVector: chartRow] = [TestVector: chartRow]()

        // Construct Set of all Faults
        for tvPair in coverageList{
            sa0.formUnion(tvPair.coverage.sa0)
            sa1.formUnion(tvPair.coverage.sa1)
        }

        for fault in sa0 {
            row.sa0[fault] = 0
        }
        for fault in sa1 {
            row.sa1[fault] = 0
        }

        // Init TV Coverage Chart
        for tvPair in coverageList {
            chart[tvPair.vector] = row
            for sa0 in tvPair.coverage.sa0 {
                chart[tvPair.vector]!.sa0[sa0] = 1
            }
            for sa1 in tvPair.coverage.sa1 {
                chart[tvPair.vector]!.sa1[sa1] = 1
            }
        }

        // Find Essential Faults
        let result = Compactor.findEssentials(chart: chart, sa0: sa0, sa1: sa1)

        // Remove Essential Fault columns
        for fault in result.faultSA0 {
            for key in chart.keys{
                chart[key]!.sa0.removeValue(forKey: fault)
            }
        }

        for fault in result.faultSA1 {
            for key in chart.keys{
                chart[key]!.sa1.removeValue(forKey: fault)
            }
        }
        
        var rowCount: [TestVector:UInt] = [TestVector:UInt]();

        for key in chart.keys {
            rowCount[key] = 0
            for keyJ in chart[key]!.sa0.keys {
                if (chart[key]!.sa0[keyJ]! == 1){
                    rowCount[key] = rowCount[key]! + 1
                }
            } 
            for keyJ in chart[key]!.sa1.keys {
                if (chart[key]!.sa1[keyJ]! == 1){
                    rowCount[key] = rowCount[key]! + 1
                }
            } 
        }

        let sortedCount = rowCount.sorted { $0.1 > $1.1 }
        var indx = 0
        var vectors = result.vectors
        
        repeat {
            // Remove dominating rows iteratively till faults no more
            let faults = chart[sortedCount[indx].key]!.getFaults()              // remove first row faults
            vectors.insert(sortedCount[indx].key)

            for fault in faults.sa0 {
                for key in chart.keys{
                    chart[key]!.sa0.removeValue(forKey: fault)
                }
            }
            for fault in faults.sa1 {
                for key in chart.keys{
                    chart[key]!.sa1.removeValue(forKey: fault)
                }
            }
            indx = indx + 1
        } while ((chart[Array(chart.keys)[0]]!.sa0.count != 0) || (chart[Array(chart.keys)[0]]!.sa1.count != 0))  

        let filtered = coverageList.filter { vectors.contains($0.vector) }
        
        // Verify that Compaction didn't reduce the coverage
        var sa0Final = Set<String>()
        var sa1Final = Set<String>()

        for tvPair in filtered{
            sa0Final.formUnion(tvPair.coverage.sa0)
            sa1Final.formUnion(tvPair.coverage.sa1)
        }
        if sa0 == sa0Final && sa1 == sa1Final {
            let ratio = (1 - (Float(filtered.count) / Float(chart.count))) * 100 
            print("Compaction is successfuly concluded with a reduction percentage of : \(String(format: "%.2f", ratio))% .\n")
        }
        else {
            print("Error: All faults aren't covered after compaction .\n")
        }
        return filtered
    }   

    private static func findEssentials(
        chart: [TestVector: chartRow] ,
        sa0: Set<String>,
        sa1: Set<String>
    ) -> ( vectors: Set<TestVector> , faultSA0: [String], faultSA1: [String]) {

        var vectors = Set<TestVector>()
        var faultSA0 : [String] = []
        var faultSA1 : [String] = []

        var faultColumn : String = ""
        var tvRow : TestVector = []
        var count = 0

        for j in 0..<sa0.count {
            count = 0
            for i in 0..<chart.count{
                var currRow = chart[Array(chart.keys)[i]]!
                faultColumn = Array(currRow.sa0.keys)[j]
                if (currRow.sa0[faultColumn] == 1){
                    count = count + 1
                    tvRow = Array(chart.keys)[i]
                }
            }
            if (count == 1){
                faultSA0.append(faultColumn)
                vectors.insert(tvRow)
            }
        }

        for j in 0..<sa1.count {
            count = 0
            for i in 0..<chart.count{
                var currRow = chart[Array(chart.keys)[i]]!
                faultColumn = Array(currRow.sa1.keys)[j]
                if (currRow.sa1[faultColumn] == 1){
                    count = count + 1
                    tvRow = Array(chart.keys)[i]
                }
            }
            if (count == 1){
                faultSA1.append(faultColumn)
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