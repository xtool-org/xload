import Foundation
import SwiftUI
import Synchronization
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
private final class ViewTracker {
    let viewsDidChange = PassthroughSubject<Void, Never>()

    var views: [UUID: Tree<ResolvedViewData>] = [:] {
        didSet { viewsDidChange.send() }
    }

    #if canImport(UIKit)
    static var window: UIWindow?
    #endif

    static let shared = ViewTracker()
    private init() {
        #if canImport(UIKit)
        Task { @MainActor in
            let keyWindow = (UIApplication.shared as PleaseJustGiveMeTheKeyWindow).keyWindow!
            let window = RendererWindow(windowScene: keyWindow.windowScene!)
            Self.window = window
            let rootViewController = RendererViewController()
            window.rootViewController = rootViewController
        }
        #endif
    }
}

#if canImport(UIKit)
private final class RendererWindow: UIWindow {
    override var canBecomeKey: Bool { false }

    private var cancellable: AnyCancellable?

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        windowLevel = .alert + 1
        isHidden = false

        cancellable = ViewTracker.shared.viewsDidChange
            .map { ViewTracker.shared.views.isEmpty }
            .removeDuplicates()
            .sink { isEmpty in
                self.isUserInteractionEnabled = !isEmpty
            }
    }

    required init?(coder: NSCoder) { nil }
}

private final class RendererViewController: UIViewController {
    // invariant: views.count == viewDatas.count
    var views: [UIView] = []
    var viewDatas: [ResolvedViewData] = []

    private var touchLocation: CGPoint? {
        didSet { touchDidUpdate() }
    }

    private var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        cancellable = ViewTracker.shared.viewsDidChange
            .prepend(())
//            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.renderViews() }
    }

    private func renderViews() {
        let currentViews = Array(ViewTracker.shared.views.values.flatMap(\.preOrder))
        var views = self.views

        defer {
            self.views = views
            self.viewDatas = currentViews
        }

        let oldCount = views.count
        let newCount = currentViews.count
        if oldCount < newCount {
            for _ in oldCount..<newCount {
                let view = UIView()
                view.layer.borderColor = UIColor.red.cgColor
                view.layer.borderWidth = 1
                self.view.addSubview(view)
                views.append(view)
            }
        } else {
            for v in views[newCount..<oldCount] {
                v.removeFromSuperview()
            }
            views.removeLast(oldCount - newCount)
        }

        for (view, data) in zip(views, currentViews) {
            view.frame = data.frame
        }
    }

    private func touchDidUpdate() {
        for (view, data) in zip(views, viewDatas) {
            let hasTouch = touchLocation.map { data.frame.contains($0) } == true
            view.layer.borderColor = hasTouch ? UIColor.green.cgColor : UIColor.red.cgColor
        }
    }

    private func handleTouches(_ touches: Set<UITouch>) {
        guard touches.count == 1 else {
            touchLocation = nil
            return
        }
        touchLocation = touches.first!.location(in: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touchLocation
        touchLocation = nil

        guard let location else { return }
        let matching = self.viewDatas.filter { $0.frame.contains(location) }
        let ordered = matching.map { "  - \($0.symbol)" }.joined(separator: "\n")
        print("[XLoad] selected views:\n\(ordered)")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocation = nil
    }
}
#endif

#if canImport(UIKit)
extension UIApplication: PleaseJustGiveMeTheKeyWindow {}

protocol PleaseJustGiveMeTheKeyWindow {
    @MainActor var keyWindow: UIWindow? { get }
}
#endif

struct ViewWrapper: ViewModifier {
    @Environment(\.isParentDragging) private var isParentDragging
    @GestureState private var dragPoint: CGPoint?
    private var isDragging: Bool { dragPoint != nil }
    private var isAnyDragging: Bool { isParentDragging == true || isDragging }
    private var isRoot: Bool { isParentDragging == nil }
    @State private var viewID = UUID()
    @State private var isVisible = false

    private let symbol: String?

    private var isInspecting: Bool {
        InspectionController.shared.isInspecting
    }

    nonisolated init() {
        // by registering an Observation access in this method, we make it so any time
        // we call notify(), it triggers an update on every SwiftUI view in the app.
        InjectionWatcher.shared.subscribe()

        if InspectionController.shared.isInspecting {
            symbol = getViewSymbol(Thread.callStackReturnAddresses)
        } else {
            symbol = nil
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.isParentDragging, isAnyDragging)
            .transformAnchorPreference(key: TreePreferenceKey.self, value: .bounds) { children, bounds in
                if let symbol, isVisible {
                    let node = Tree(
                        value: ViewData(id: viewID, symbol: symbol, frame: bounds),
                        children: children,
                    )
                    children = [node]
                } else if !isVisible {
                    children = []
                }
            }
            .onAppear {
                isVisible = true
            }
            .onDisappear {
                isVisible = false
            }
            .modify { view in
                if isRoot {
                    view.overlayPreferenceValue(TreePreferenceKey.self) { trees in
                        if isInspecting {
                            GeometryReader { content in
                                let frame = content.frame(in: .global)
                                let tree: Tree<ResolvedViewData>? = {
                                    guard trees.count == 1 else { return nil }
                                    return trees[0].map { data in
                                        let resolved = content[data.frame].offsetBy(
                                            dx: frame.minX,
                                            dy: frame.minY,
                                        )
                                        return ResolvedViewData(
                                            id: data.id,
                                            symbol: data.symbol,
                                            frame: resolved
                                        )
                                    }
                                }()
                                Color.clear.onChange(of: tree, initial: true) { _, new in
                                    ViewTracker.shared.views[viewID] = tree
                                }
                            }
                            .onDisappear {
                                ViewTracker.shared.views[viewID] = nil
                            }
                        }
                    }
                } else {
                    view
                }
            }
    }
}

private struct PointInfo: Identifiable, Equatable {
    let id: String
    let rect: CGRect
    let containsView: Bool
}

private struct Pair<A: Equatable, B: Equatable>: Equatable {
    let first: A
    let second: B

    static func == (lhs: Self, rhs: Self) -> Bool {
        (lhs.first, lhs.second) == (rhs.first, rhs.second)
    }
}

private let demanglingCache = Mutex<[Int: String?]>([:])

private func getViewSymbol(_ addresses: [NSNumber]) -> String? {
    // TODO: maintain a map of system MachO file ranges
    // that way we can easily discard system objects

    guard addresses.count >= 5 else { return nil }

    let address = addresses[4].intValue

    let value = demanglingCache.withLock { $0[address] }
    switch value {
    case .some(.some(let value)):
        return value
    case .some(.none):
        return nil
    case .none:
        break
    }

    let result = computeInfo(address)
    demanglingCache.withLock { $0[address] = result }
    return result
}

extension View {
    func modify<V: View>(@ViewBuilder _ body: (Self) -> V) -> V {
        body(self)
    }
}

private func computeInfo(_ address: Int) -> String? {
    let pointer = UnsafeRawPointer(bitPattern: address)

    var info = Dl_info()
    guard dladdr(pointer, &info) != 0 else { return nil }

    guard !UnsafeBufferPointer(start: info.dli_fname, count: strlen(info.dli_fname))
        .withMemoryRebound(to: UInt8.self, { $0.starts(with: "/System/".utf8) })
        else { return nil }

    let symbolName = UnsafeBufferPointer(start: info.dli_sname, count: strlen(info.dli_sname))
    guard symbolName.withMemoryRebound(to: UInt8.self, { $0.starts(with: "$s".utf8) })
          else { return nil }
    guard var demangled = demangle(raw: symbolName.span)
          else { return nil }

    let suffix = " : some"
    if demangled.hasSuffix(suffix) {
        demangled.removeLast(suffix.count)
    }

    return demangled
}

func demangle(raw: Span<CChar>) -> String? {
    let demangledNamePtr = raw.withUnsafeBufferPointer { buffer in
        _swift_demangle(
            mangledName: buffer.baseAddress,
            mangledNameLength: UInt(buffer.count),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0
        )
    }
    guard let demangledNamePtr else { return nil }
    let demangledName = String(cString: demangledNamePtr)
    free(demangledNamePtr)
    return demangledName
}

@_silgen_name("swift_demangle")
public func _swift_demangle(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
) -> UnsafeMutablePointer<CChar>?

final class InspectionController: Observable, Sendable {
    private let registrar = ObservationRegistrar()

    private let _isInspecting = Atomic(false)

    var isInspecting: Bool {
        get {
            registrar.access(self, keyPath: \.isInspecting)
            return _isInspecting.load(ordering: .acquiring)
        }
        set {
            registrar.withMutation(of: self, keyPath: \.isInspecting) {
                _isInspecting.store(newValue, ordering: .releasing)
            }
        }
    }

    static let shared = InspectionController()

    init() {
        let notifications = NotificationCenter.default.notifications(
            named: Notification.Name("XLDSetInspecting")
        )
        Task {
            for await notification in notifications {
                if let value = notification.object as? Bool {
                    isInspecting = value
                } else {
                    isInspecting.toggle()
                }
                // because Observation plays badly with multiple threads sometimes
                isInspecting = isInspecting
            }
        }
    }
}

extension EnvironmentValues {
    @Entry fileprivate var isParentDragging: Bool?
}

private struct Tree<V> {
    var value: V
    var children: [Tree<V>]

    var preOrder: some Sequence<V> {
        [[value], children.lazy.flatMap(\.preOrder)].lazy.joined()
    }

    func map<R, E>(_ transform: (V) throws(E) -> R) throws(E) -> Tree<R> {
        try Tree<R>(
            value: transform(value),
            children: children.map { child throws(E) in
                try child.map(transform)
            }
        )
    }
}

extension Tree: Equatable where V: Equatable {}
extension Tree: Hashable where V: Hashable {}
extension Tree: Identifiable where V: Identifiable {
    var id: V.ID { value.id }
}

private struct ViewData: Identifiable {
    let id: UUID
    let symbol: String
    let frame: Anchor<CGRect>
}

private struct ResolvedViewData: Identifiable, Hashable {
    let id: UUID
    let symbol: String
    let frame: CGRect
}

private struct TreePreferenceKey: PreferenceKey {
    typealias Node = Tree<ViewData>
    static var defaultValue: [Node] { [] }

    static func reduce(value: inout [Node], nextValue: () -> [Node]) {
        value += nextValue()
    }
}
