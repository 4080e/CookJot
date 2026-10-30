import Foundation

@MainActor
final class IdleTimerController {
    private var requests = Set<UUID>()
    private let apply: (Bool) -> Void
    private(set) var isIdleTimerDisabled = false

    init(apply: @escaping (Bool) -> Void) {
        self.apply = apply
    }

    func updateRequest(_ id: UUID, isVisible: Bool, isActive: Bool, isEnabled: Bool = true) {
        if isVisible && isActive && isEnabled {
            requests.insert(id)
        } else {
            requests.remove(id)
        }
        let disabled = !requests.isEmpty
        guard disabled != isIdleTimerDisabled else { return }
        isIdleTimerDisabled = disabled
        apply(disabled)
    }
}

#if canImport(UIKit)
import SwiftUI
import UIKit

extension IdleTimerController {
    static let shared = IdleTimerController {
        UIApplication.shared.isIdleTimerDisabled = $0
    }
}

private struct KeepAwakeModifier: ViewModifier {
    let enabled: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var requestID = UUID()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                updateRequest()
            }
            .onDisappear {
                isVisible = false
                updateRequest()
            }
            .onChange(of: scenePhase) { _, _ in updateRequest() }
            .onChange(of: enabled) { _, _ in updateRequest() }
    }

    private func updateRequest() {
        IdleTimerController.shared.updateRequest(
            requestID, isVisible: isVisible, isActive: scenePhase == .active, isEnabled: enabled
        )
    }
}

extension View {
    func keepAwake(while enabled: Bool = true) -> some View {
        modifier(KeepAwakeModifier(enabled: enabled))
    }
}
#endif
