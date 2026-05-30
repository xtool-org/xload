import Foundation
import InjectionImpl
import System

actor FileReloader {
    private var loader = Reloader()

    func watch(directory: String) async throws {
        let changes = try watchDirectory(directory)
        var loadedLibraries: Set<String> = []
        for try await _ in changes {
            let contentsArr = try FileManager.default.contentsOfDirectory(atPath: directory)
                .filter { $0.hasSuffix(".dylib") }
                .map { "\(directory)/\($0)" }
            let contents = Set(contentsArr)
            let newLibraries = contents.subtracting(loadedLibraries)
            loadedLibraries.formUnion(newLibraries)
            for library in newLibraries {
                reload(library)
            }
        }
    }

    private func reload(_ dylib: String) {
        guard let (image, classes) = loader.loadAndPatch(in: dylib) else {
            print("[XLoad] Failed to load image: \(dylib)")
            return
        }
        loader.sweeper.sweepAndRunTests(image: image, classes: classes)
    }

    private func watchDirectory(_ path: String) throws -> AsyncStream<Void> {
        let file = try FileDescriptor.open(path, .init(rawValue: O_EVTONLY))
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: file.rawValue,
            eventMask: .all
        )
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        source.setEventHandler { continuation.yield() }
        source.setCancelHandler { try? file.close() }
        continuation.onTermination = { _ in source.cancel() }
        source.resume()
        return stream
    }
}
