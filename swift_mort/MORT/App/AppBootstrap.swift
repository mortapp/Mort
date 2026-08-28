import Foundation
import Observation

@MainActor
@Observable
final class AppBootstrap {
    private(set) var container: DependencyContainer?
    private(set) var errorMessage: String?

    init() {
        do { container = DependencyContainer(configuration: try AppConfiguration.load()) }
        catch { errorMessage = error.localizedDescription }
    }
}

