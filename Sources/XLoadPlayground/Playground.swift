import SwiftUI

#if os(macOS)
@main enum Entrypoint {
    static func main() {
        _ = NSApplication.shared
        let delegate = PlaygroundDelegate()
        defer { extendLifetime(delegate) }
        NSApp.delegate = delegate
        NSApp.setActivationPolicy(.regular)
        NSApp.run()
    }
}

final class PlaygroundDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.miniaturizable, .closable, .resizable, .titled],
            backing: .buffered,
            defer: false,
        )

        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate), keyEquivalent: "q")

        let toggleItem = NSMenuItem(
            title: "Toggle Inspector",
            action: #selector(PlaygroundDelegate.enableInspector),
            keyEquivalent: "i"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(toggleItem)

        let viewController = NSHostingController(rootView: ContentView())
        viewController.sceneBridgingOptions = .all
        viewController.sizingOptions = [.minSize]
        window.contentViewController = viewController

        window.setContentSize(CGSize(width: 480, height: 270))
        window.center()
        window.setFrameAutosaveName("XTLWindow")

        window.makeKeyAndOrderFront(nil)
    }

    @objc func enableInspector() {
        NotificationCenter.default.post(name: Notification.Name("XLDSetInspecting"), object: nil)
    }
}
#else
// Stub to get it to compile on non-macOS
@main struct Playground: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif

struct ContentView: View {
    @State private var shown = false

    var body: some View {
        VStack {
            FirstView()

            SecondView()

            Button("Present") {
                shown = true
            }
        }
        .sheet(isPresented: $shown) {
            sheet
        }
    }

    var sheet: some View {
        Text("Shown")
    }
}

struct FirstView: View {
    var body: some View {
        Text("First view")
            .padding()
            .background(.red)
    }
}

struct SecondView: View {
    var body: some View {
        VStack {
            secondView

            ThirdView()
        }
        .padding()
        .background(.green)
    }

    var secondView: some View {
        Text("Second view")
    }
}

struct ThirdView: View {
    var body: some View {
        Text("Third view")
            .padding()
            .background(.blue)
    }
}
