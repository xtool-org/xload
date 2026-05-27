import Foundation
import CXLoad
import Synchronization
import ellekit

enum SwiftUIInterceptor {
    fileprivate typealias CGetValue = @convention(c) (UInt32, UInt32, UnsafeRawPointer?) -> AGValue

    static func install() {
        let target = dlsym(dlopen(nil, 0), "AGGraphGetValue")!
        let hooked = unsafeBitCast(hookedGetValue as CGetValue, to: UnsafeMutableRawPointer.self)

        _orig.withLock {
            // we have to hook inside the lock otherwise there's
            // a brief period between when we install the hook and
            // when we set orig. if someone calls AGGraphGetValue during that time,
            // we'll crash.
            let res = ellekit::hook(target, hooked)
            $0 = unsafeBitCast(res, to: CGetValue.self)
        }
    }

    fileprivate static let _orig = Mutex<CGetValue?>(nil)
    // "upgrades" the mutex to an atomic. safe because we never read it before it's set.
    fileprivate static let orig = SwiftUIInterceptor._orig.withLock(\.self)!
}

@c private func hookedGetValue(
    _ attribute: UInt32,
    _ options: UInt32,
    _ type: UnsafeRawPointer?,
) -> AGValue {
    // AGGraphGetValue is called on basically every view render (afaict; I hope).
    // by registering an Observation access in this method, we make it so any time
    // we call bump(), it triggers an update on every SwiftUI view in the app.
    InjectionWatcher.shared.subscribe()
    let origFunc = SwiftUIInterceptor.orig
    return origFunc(attribute, options, type)
}

private struct InjectionWatcher: Observable, Sendable {
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
