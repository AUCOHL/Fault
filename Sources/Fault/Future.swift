import Foundation

public class Future<Type> {
    private var store: Type?

    private var mutex: pthread_mutex_t

    init(executor: @escaping () -> Type) {
        mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)

        pthread_mutex_lock(&mutex)
        DispatchQueue.global(qos: .utility).async {
            self.store = executor()
            pthread_mutex_unlock(&self.mutex)
        }
    }

    public var value: Type {
        pthread_mutex_lock(&mutex)
        let value = store!
        pthread_mutex_unlock(&mutex)
        return value
    }
}