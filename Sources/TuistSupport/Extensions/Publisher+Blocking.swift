import Combine
import Foundation

extension Publisher {
    /// It blocks the current thread until the publisher finishes.
    /// - Parameter timeout: Timeout
    /// - Throws: Error thrown by the publisher or as a result of a time out caused by the publishing not finishing in time.
    /// - Returns: List of events sent through the publisher.
    public func toBlocking(timeout: DispatchTime = .now() + .seconds(10)) throws -> [Output] {
        // swiftlint:disable identifier_name
        let semaphore = DispatchSemaphore(value: 0)
        var cancellables: Set<AnyCancellable> = Set()
        var values: [Output] = []
        var error: Error?
        let synchronizationQueue = DispatchQueue(label: "io.tuist.support.blocking-publisher")

        sink { completion in
            switch completion {
            case let .failure(_error):
                synchronizationQueue.async {
                    error = _error
                    semaphore.signal()
                }
            default:
                synchronizationQueue.async {
                    semaphore.signal()
                }
            }
        } receiveValue: { value in
            synchronizationQueue.async {
                values.append(value)
            }
        }
        .store(in: &cancellables)

        _ = semaphore.wait(timeout: timeout)
        return try synchronizationQueue.sync { () throws -> [Output] in
            if let error = error { throw error }
            return values
        }
    }
}
