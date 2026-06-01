import Foundation
import SwiftUI

struct ViewWrapper: ViewModifier {
    @Environment(\.isParentDragging) private var isParentDragging
    @GestureState private var dragPoint: CGPoint?
    private var isDragging: Bool { dragPoint != nil }
    private var isAnyDragging: Bool { isParentDragging == true || isDragging }
    private var isRoot: Bool { isParentDragging == nil }

    private let symbol: String?

    nonisolated init() {
        // by registering an Observation access in this method, we make it so any time
        // we call notify(), it triggers an update on every SwiftUI view in the app.
        InjectionWatcher.shared.subscribe()

        if InspectionController.shared.isInspecting {
            symbol = getInfo(Thread.callStackReturnAddresses)
        } else {
            symbol = nil
        }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.isParentDragging, isAnyDragging)
            .transformAnchorPreference(key: TreePreferenceKey.self, value: .bounds) { children, bounds in
                if let symbol {
                    let node = Tree(
                        value: ViewData(symbol: symbol, frame: bounds),
                        children: children,
                    )
                    children = [node]
                }
            }
            .overlayPreferenceValue(TreePreferenceKey.self) { trees in
                if symbol != nil {
                    GeometryReader { proxy in
                        let points: Array = trees.flatMap(\.preOrder).map { item in
                            let rect = proxy[item.frame]
                            return PointInfo(
                                id: item.id,
                                rect: rect,
                                containsView: dragPoint.map { rect.contains($0) } == true
                            )
                        }

                        ZStack(alignment: .topLeading) {
                            ForEach(points) { node in
                                let rect = node.rect
                                Rectangle()
                                    .stroke()
                                    .foregroundStyle(node.containsView ? .green : .red)
                                    .frame(width: rect.width, height: rect.height)
                                    .offset(x: rect.minX, y: rect.minY)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if let dragPoint {
                                Circle()
                                    .frame(width: 20, height: 20)
                                    .position(dragPoint)
                            }
                        }
                        .onChange(of: Pair(first: points, second: dragPoint == nil)) { old, new in
                            if new.second {
                                InspectionController.shared.isInspecting = false
                                let symbols = old.first.filter(\.containsView).map(\.id)
                                print("[XLoad] symbols: \(symbols.joined(separator: " -> "))")
                            }
                        }
                    }
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragPoint) { value, state, _ in
                                state = value.location
                            }
                    )
                    .overlay {
                        if !isAnyDragging {
                            Rectangle()
                                .stroke()
                                .foregroundStyle(.red)
                        }
                    }
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

private struct TreeView: View {
    let trees: [Tree<ViewData>]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(trees, id: \.value.id) { tree in
                Text("- \(tree.value.symbol)")
                TreeView(trees: tree.children)
                    .padding(.leading, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func getInfo(_ addresses: [NSNumber]) -> String? {
    guard addresses.count >= 5,
          let pointer = UnsafeRawPointer(bitPattern: addresses[4].intValue)
          else { return nil }
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

    private let lock = NSRecursiveLock()
    private nonisolated(unsafe) var _isInspecting = false

    var isInspecting: Bool {
        get {
            registrar.access(self, keyPath: \.isInspecting)
            return lock.withLock { _isInspecting }
        }
        set {
            lock.withLock {
                registrar.withMutation(of: self, keyPath: \.isInspecting) {
                    _isInspecting = newValue
                }
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
            }
        }
    }
}

extension EnvironmentValues {
    @Entry fileprivate var isParentDragging: Bool?
}

private struct Tree<V> {
    let value: V
    let children: [Tree<V>]

    var preOrder: some Sequence<V> {
        [[value], children.lazy.flatMap(\.preOrder)].lazy.joined()
    }
}

private struct ViewData: Identifiable {
    var id: String { symbol }

    let symbol: String
    let frame: Anchor<CGRect>
}

private struct TreePreferenceKey: PreferenceKey {
    typealias Node = Tree<ViewData>
    static var defaultValue: [Node] { [] }

    static func reduce(value: inout [Node], nextValue: () -> [Node]) {
        value += nextValue()
    }
}
