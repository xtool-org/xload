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
        self.init(content.modifier(ViewWrapper()))
    }
}
