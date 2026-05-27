import CXLoad
import InjectionImpl
import Foundation
import System

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

    let changes = try await watchDirectory(watchPath)

    let reloader = FileReloader()

    var loadedLibraries: Set<String> = []
    for try await _ in changes {
        let contentsArr = try FileManager.default.contentsOfDirectory(atPath: watchPath)
            .filter { $0.hasSuffix(".dylib") }
            .map { "\(watchPath)/\($0)" }
        let contents = Set(contentsArr)
        let newLibraries = contents.subtracting(loadedLibraries)
        loadedLibraries.formUnion(newLibraries)
        for library in newLibraries {
            await reloader.reload(library)
        }
    }
}

private func watchDirectory(_ path: String) async throws -> AsyncStream<Void> {
    let file = try FileDescriptor.open(path, .init(rawValue: O_EVTONLY))
    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: file.rawValue,
        eventMask: .all
    )
    let (stream, continuation) = AsyncStream<Void>.makeStream()
    source.setEventHandler { continuation.yield() }
    continuation.onTermination = { _ in source.cancel() }
    source.resume()
    return stream
}

actor FileReloader {
    private var loader = Reloader()

    func reload(_ dylib: String) {
        guard let (image, classes) = loader.loadAndPatch(in: dylib) else {
            print("[XLoad] Failed to load image: \(dylib)")
            return
        }
        loader.sweeper.sweepAndRunTests(image: image, classes: classes)
    }
}

struct StringError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
