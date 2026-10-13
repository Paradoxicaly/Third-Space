import Foundation
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(String)
    case cached(Value, asOf: Date)
    case offline(cached: Value?, asOf: Date?)
    var isColdOffline: Bool {
        if case .offline(let cached, _) = self { return cached == nil }
        return false
    }
}
