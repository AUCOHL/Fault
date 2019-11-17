import Foundation

public class Future {
    private var semaphore: DispatchSemaphore
    private var store: Any?

    init(executor: @escaping () -> Any) {
        semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            self.store = executor()
            self.semaphore.signal()
        }
    }

    public var value: Any {
        semaphore.wait()
        let value = store!
        return value
    }
}