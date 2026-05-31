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
    // when building with OpaqueTypeErasure, all opaque view bodies are wrapped in
    // [AnyView/DebugReplaceableView].init(erasing:) (the latter iff iOS 26+).
    // this is a perfect point for us to inject custom logic that occurs on every
    // view render. we use this for multiple purposes:
    //
    // 1. When Injection replaces symbols, we need to nudge SwiftUI to re-evaluate the
    //    view body. We achieve this by subscribing to an Observable value in AnyView.init.
    //    on every Injection reload, we trigger an update on the Observable value, which
    //    thus causes all view bodies to re-evaluate.
    //
    // 2. for views that have an availability of iOS 26+, SwiftUI will erase them with
    //    DebugReplaceableView instead of AnyView. This type erases the type statically
    //    but the view has to maintain the same type at runtime. So if e.g. you add a modifier
    //    to the view, it changes the runtime type which causes DebugReplaceableView to crash.
    //    We can work around this with a hook that effectively transforms calls to
    //    `DebugReplaceableView($0)` into `DebugReplaceableView(AnyView($0))`
    //
    // 3. Altogether, this means every user-defined view funnels through our AnyView wrapper.
    //    we can also use this to inject custom logic as needed, into every user defined view.
    guard ProcessInfo.processInfo.environment["XLOAD_INTERCEPT"] != "0" else { return }
    print("[XLoad] Loading ViewInterceptor...")
    ViewInterceptor.install()
}

private func loadWatcher() async throws {
    guard let watchPath = ProcessInfo.processInfo.environment["XLOAD_WATCH_DIR"]
        else { return }

    print("[XLoad] Watching for changes...")

    let reloader = FileReloader()
    try await reloader.watch(directory: watchPath)
}
