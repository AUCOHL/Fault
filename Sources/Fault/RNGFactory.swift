// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BigInt
import Foundation

protocol URNG {
    init(allBits: Int)
    func generate(bits: Int) -> BigUInt
}

enum URNGFactory {
    private static var registry: [String: URNG.Type] = [:]

    static func register<T: URNG>(name: String, type: T.Type) -> Bool {
        registry[name] = type
        return true
    }

    static func get(name: String) -> URNG.Type? {
        guard let metaType = registry[name] else {
            return nil
        }
        return metaType
    }

    static var validNames: [String] {
        [String](registry.keys)
    }
}
