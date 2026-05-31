import SwiftUI
import CXLoad

enum ViewInterceptor {
    static func install() {
        xload_install_hooks()
    }
}

extension AnyView {
    @_silgen_name("xload_wrap_view")
    package init(_wrapping content: some View) {
        // by registering an Observation access in this method, we make it so any time
        // we call notify(), it triggers an update on every SwiftUI view in the app.
        InjectionWatcher.shared.subscribe()
        // we can even wrap `content` in another view here if we want.
        // could be useful for view debugging.
        self.init(content)
    }
}
