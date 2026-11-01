import SwiftUI

/// The row background includes List's own insets, so measurements describe the card, not its text.
struct TodayMenuRowBackground: View {
    let id: UUID
    let epoch: Int
    let jumps: TodayMenuJumpController
    let expanded: Bool
    let enabled: Bool
    @State private var instance = UUID()

    var body: some View {
        GeometryReader { geometry in
            Color(uiColor: .secondarySystemGroupedBackground)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    if enabled { jumps.measure(id, frame: frame, epoch: epoch, instance: instance, expanded: expanded) }
                }
                .onAppear {
                    if enabled { jumps.measure(id, frame: geometry.frame(in: .global), epoch: epoch, instance: instance, expanded: expanded) }
                }
                .onChange(of: epoch) { _, value in
                    // Re-sample after scroll/layout updates even when the rectangle is unchanged.
                    if enabled { jumps.measure(id, frame: geometry.frame(in: .global), epoch: value, instance: instance, expanded: expanded) }
                }
                .onDisappear { jumps.removeMeasurement(id, instance: instance) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
