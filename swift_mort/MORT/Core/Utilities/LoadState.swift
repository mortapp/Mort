import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

@MainActor
func mortMessage(_ error: Error) -> String {
    BackendErrorTranslator.translate(error).localizedDescription
}
