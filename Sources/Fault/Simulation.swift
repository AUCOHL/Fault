protocol Simulation {
    func simulate(
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        outputs: [Port],
        tvAttempts: Int
    ) throws -> (json: String, coverage: Float)
}