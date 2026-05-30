import SwiftUI // for linkage
import Synchronization
import CXLoad

enum ViewEraser {
    @available(iOS 26, *)
    static func install() {
        let hookFunction = UnsafeMutableRawPointer(
            mutating: xload_get_DebugReplaceableView_init_hook()
        )
        guard let swiftUI = dlopen(
            "/System/Library/Frameworks/SwiftUICore.framework/SwiftUICore",
            RTLD_LAZY,
        ) else {
            print("[XLoad] Could not install ViewEraser: failed to load SwiftUICore.framework")
            return
        }
        let target = dlsym(
            swiftUI,
            "$s7SwiftUI20DebugReplaceableViewV8_erasingACx_tcAA0E0RzlufC"
        )!
        orig.withLock {
            let res = ellekit::hook(target, hookFunction)
            $0 = res.map { ptr in .init(value: ptr) }
        }
    }

    fileprivate static let orig = Mutex<UncheckedSendable<UnsafeRawPointer>?>(nil)
}

@c @implementation func xload_get_DebugReplaceableView_init_orig() -> UnsafeRawPointer {
    ViewEraser.orig.withLock(\.self)!.value
}

@preconcurrency @MainActor
@_silgen_name("xload_wrap_DebugReplaceableView") func wrapView<V: View>(
    // the `consuming` is important for ABI reasons, otherwise
    // we'd need to manually destroy the generic param in C
    _ content: consuming V
) -> AnyView {
    AnyView(content)
}

private struct UncheckedSendable<V>: @unchecked Sendable {
    let value: V
}
