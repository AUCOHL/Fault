import Foundation 
import BigInt

protocol URNG {
    init()
    func generate(bits: Int) -> BigUInt
}

class URNGFactory {
    private static var registry: [String: URNG.Type] = [:]

    static func register<T: URNG>(name: String, type: T.Type) -> Bool {
        registry[name] = type
        return true
    }

    static func get(name: String) -> URNG? {
        guard let metaType = registry[name] else {
            return nil
        }
        return metaType.init()
    }

    static var validNames: [String] {
        return [String](registry.keys)
    }
}