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
    loadEraser()
    loadInterceptor()
    try await loadWatcher()
}

private func loadEraser() {
    // for views that have an availability of iOS 26+, SwiftUI will erase them with
    // DebugReplaceableView instead of AnyView. This type erases the type statically
    // but the view has to maintain the same type at runtime. So if e.g. you add a modifier
    // to the view, it changes the runtime type which causes DebugReplaceableView to crash.
    // We can work around this with a hook that effectively transforms calls to
    // `DebugReplaceableView($0)` into `DebugReplaceableView(AnyView($0))`
    guard #available(iOS 26, *), ProcessInfo.processInfo.environment["XLOAD_ERASER"] != "0" else { return }
    print("[XLoad] Loading eraser...")
    ViewEraser.install()
}

private func loadInterceptor() {
    // each time FileReloader replaces symbols, we still need something to nudge SwiftUI
    // to re-render the entire view tree. this is where SwiftUIInterceptor comes in.
    // high level, we can piggyback off the Observable machinery for re-renders.
    // observable values read during a view render are tracked by the Swift runtime,
    // so that any time such a value is modified (even if it's completely outside of SwiftUI's
    // lifecycle), it causes SwiftUI to dirty the view that read that value, and re-render it.
    // so we hook into a function that's frequently called during view renders (AGGraphGetValue)
    // and always "read" from an observable token. then when we need to re-render, we tell Swift
    // that we modified that token.

    // it's tempting to say "screw AGGraphGetValue, why not subscribe to reloads in the
    // ViewEraser-wrapped view?" but unfortunately, even if we're running on an iOS 26 system,
    // the compiler will only use DebugReplaceableView for views that are lexically known to
    // have iOS 26+ availability *at compile time*. So we can only make that optimization if
    // the *deployment target* is iOS 26+.
    guard ProcessInfo.processInfo.environment["XLOAD_INTERCEPT"] == "1" else { return }
    print("[XLoad] Loading interceptor...")
    SwiftUIInterceptor.install()
}

private func loadWatcher() async throws {
    guard let watchPath = ProcessInfo.processInfo.environment["XLOAD_WATCH_DIR"]
        else { return }

    print("[XLoad] Watching for changes...")

    let reloader = FileReloader()
    try await reloader.watch(directory: watchPath)
}
