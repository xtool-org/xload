import Foundation
import CXLoad

@c @implementation func xload_load() {
    print("[XLoad] Loading...")

    Task {
        do {
            try await load()
        } catch {
            print("[XLoad] Watcher failed: \(error)")
        }
    }
}

private func load() async throws {
    loadInterceptor()
    try await loadWatcher()
}

private func loadInterceptor() {
    guard ProcessInfo.processInfo.environment["XLOAD_INTERCEPT"] == "1" else { return }
    print("[XLoad] Loading interceptor...")
    SwiftUIInterceptor.install()
}

private func loadWatcher() async throws {
    guard let watchPath = ProcessInfo.processInfo.environment["XLOAD_WATCH_DIR"]
        else { return }

    print("[XLoad] Loading watcher...")

    let reloader = FileReloader()
    try await reloader.watch(directory: watchPath)
}
