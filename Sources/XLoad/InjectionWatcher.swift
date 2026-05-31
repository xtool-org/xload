import Foundation

struct InjectionWatcher: Observable, Sendable {
    private let registrar = ObservationRegistrar()

    static let shared = InjectionWatcher()

    private init() {
        Task { [self] in await watch() }
    }

    private func watch() async {
        for await _ in NotificationCenter.default.notifications(named: .init("INJECTION_BUNDLE_NOTIFICATION")) {
            notify()
        }
    }

    private func notify() {
        registrar.withMutation(of: self, keyPath: \.self) {}
    }

    func subscribe() {
        registrar.access(self, keyPath: \.self)
    }
}
