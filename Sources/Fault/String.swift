import Foundation

extension String {
    func sh() -> Int {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["sh", "-c", self]
        task.launch()
        task.waitUntilExit()
        return Int(task.terminationStatus)
    }
}