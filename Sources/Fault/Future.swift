import Foundation

public class Future<Type> {
    private var semaphore: DispatchSemaphore
    private var store: Type?

    init(executor: @escaping () -> Type) {
        semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .utility).async {
            self.store = executor()
            self.semaphore.signal()
        }
    }

    public var value: Type {
        semaphore.wait()
        let value = store!
        return value
    }
}