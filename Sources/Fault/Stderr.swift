import Foundation

class Stderr {
    public static func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        for (i, item) in items.enumerated() {
            fputs(String(describing: item), stderr)
            if (i != items.count - 1) {
                fputs(separator, stderr)
            }               
        }
        fputs(terminator, stderr)
    }
}