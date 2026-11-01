import Foundation
import CoreGraphics
import Observation

/// Transient viewport state. Recipe data and the saved menu order remain in their existing stores.
@MainActor
@Observable
final class TodayMenuJumpController {
    enum Direction { case previous, next }
    enum Phase { case idle, moving, userInteraction }

    nonisolated struct ScrollMetrics: Equatable {
        var offset: CGFloat
        var contentHeight: CGFloat
        var containerHeight: CGFloat
        var topInset: CGFloat
        var bottomInset: CGFloat
    }

    private struct Row {
        let frame: CGRect
        let epoch: Int
        let instance: UUID
    }

    private(set) var order: [UUID] = []
    private(set) var viewport = CGRect.zero
    private(set) var metrics: ScrollMetrics?
    private(set) var phase: Phase = .idle
    private(set) var epoch = 0
    private(set) var currentID: UUID?
    private(set) var isJumping = false
    private var rows: [UUID: Row] = [:]
    private var heights: [UUID: CGFloat] = [:]
    private var collapsedHeights: [UUID: CGFloat] = [:]
    private var measuredExpansion: [UUID: Bool] = [:]
    private var previousCurrentID: UUID?
    private var requestID: UUID?
    private var jumpTask: Task<Void, Never>?
    private var controlsClearance: CGFloat = 0
    nonisolated private static let alignmentTolerance: CGFloat = 4

    var bottomMargin: CGFloat {
        guard order.count > 1 else { return 0 }
        return max(controlsClearance, Self.tailMargin(viewportHeight: viewport.height,
                                                     cardHeight: order.last.flatMap { heights[$0] }))
    }

    /// Reserve the already measured collapsed height in the same render that closes the group.
    /// Otherwise UIKit can clamp the offset before the shorter row's geometry callback arrives.
    func margin(lastExpanded: Bool) -> CGFloat {
        guard order.count > 1, let last = order.last else { return 0 }
        if !lastExpanded {
            if let height = collapsedHeights[last] {
                return max(controlsClearance, Self.tailMargin(viewportHeight: viewport.height, cardHeight: height))
            }
            if measuredExpansion[last] == true { return max(controlsClearance, viewport.height) }
        }
        return bottomMargin
    }

    static func tailMargin(viewportHeight: CGFloat, cardHeight: CGFloat?) -> CGFloat {
        guard let cardHeight, cardHeight > 0 else { return 0 }
        return max(0, viewportHeight - cardHeight)
    }

    private var liveFrames: [UUID: CGRect] {
        rows.filter { $0.value.epoch == epoch }.mapValues(\.frame)
    }

    func neighbor(_ direction: Direction) -> UUID? {
        guard let currentID, let index = order.firstIndex(of: currentID) else { return nil }
        if direction == .previous {
            // A missing current rectangle can only be the recycled predecessor of a visible gap.
            // Its top is already above the viewport; never use its old cached coordinates.
            guard let frame = liveFrames[currentID] else { return currentID }
            if frame.minY < viewport.minY - Self.alignmentTolerance { return currentID }
        }
        let next = index + (direction == .previous ? -1 : 1)
        return order.indices.contains(next) ? order[next] : nil
    }

    func updateOrder(_ ids: [UUID]) {
        guard order != ids else { return }
        cancel()
        order = ids
        heights = heights.filter { ids.contains($0.key) }
        collapsedHeights = collapsedHeights.filter { ids.contains($0.key) }
        measuredExpansion = measuredExpansion.filter { ids.contains($0.key) }
        rows.removeAll()
        previousCurrentID = nil
        invalidateFrames()
    }

    func updateViewport(_ frame: CGRect) {
        guard frame != viewport else { return }
        if abs(frame.width - viewport.width) > 0.5 {
            heights.removeAll()
            collapsedHeights.removeAll()
            measuredExpansion.removeAll()
        }
        viewport = frame
        invalidateFrames()
    }

    func updateScroll(_ value: ScrollMetrics) {
        guard metrics != value else { return }
        metrics = value
        invalidateFrames()
    }

    func updatePhase(_ value: Phase) {
        guard phase != value else { return }
        phase = value
        if value == .userInteraction { cancel() }
        invalidateFrames()
    }

    func updateControlsHeight(_ height: CGFloat) {
        controlsClearance = height + 12
    }

    func contentChanged() {
        cancel()
        heights.removeAll()
        collapsedHeights.removeAll()
        measuredExpansion.removeAll()
        invalidateFrames()
    }

    func layoutChanged() {
        cancel()
        invalidateFrames()
    }

    func measure(_ id: UUID, frame: CGRect, epoch reportedEpoch: Int, instance: UUID, expanded: Bool = false) {
        guard reportedEpoch == epoch, order.contains(id), frame.height > 0,
              frame.minY.isFinite, frame.height.isFinite else { return }
        let changedHeight = heights[id].map { abs($0 - frame.height) > 0.5 } ?? false
        let oldHeightDuringClose = !expanded && measuredExpansion[id] == true
            && heights[id].map { abs($0 - frame.height) <= 0.5 } == true
        if !oldHeightDuringClose {
            if heights[id] != frame.height { heights[id] = frame.height }
            measuredExpansion[id] = expanded
            if !expanded, collapsedHeights[id] != frame.height { collapsedHeights[id] = frame.height }
        }
        if changedHeight { invalidateFrames() }
        // On a height change all row backgrounds refresh in the new epoch.
        rows[id] = Row(frame: frame, epoch: reportedEpoch, instance: instance)
        refreshCurrent()
    }

    func removeMeasurement(_ id: UUID, instance: UUID) {
        guard rows[id]?.instance == instance else { return }
        rows.removeValue(forKey: id)
        refreshCurrent()
    }

    private func invalidateFrames() {
        epoch += 1
        currentID = nil
    }

    private func refreshCurrent() {
        let value = Self.currentRecipe(order: order, frames: liveFrames, viewport: viewport,
                                       previous: previousCurrentID)
        if currentID != value { currentID = value }
        if let currentID { previousCurrentID = currentID }
    }

    /// Only fresh, currently generated rectangles participate. A gap belongs to the preceding ID,
    /// including when List has already recycled that preceding row.
    static func currentRecipe(order: [UUID], frames: [UUID: CGRect], viewport: CGRect,
                              previous: UUID?) -> UUID? {
        guard viewport.height > 0 else { return nil }
        let visible = order.filter { frames[$0]?.intersects(viewport) == true }
        guard let first = visible.first, let firstIndex = order.firstIndex(of: first) else { return nil }
        let crossing = visible.last { (frames[$0]?.minY ?? .infinity) <= viewport.minY + 0.5 }
        let candidate = crossing ?? order[max(0, firstIndex - 1)]
        // Snap exact top alignment; use a 2pt dead band for subpixel boundary fluctuations.
        if let previous, order.contains(previous), previous != candidate,
           let a = order.firstIndex(of: previous), let b = order.firstIndex(of: candidate), abs(a - b) == 1,
           let boundary = frames[order[max(a, b)]]?.minY {
            let distance = abs(boundary - viewport.minY)
            if distance > 0.5 && distance <= 2 { return previous }
        }
        return candidate
    }

    func jump(_ direction: Direction, reduceMotion: Bool, scroll: @escaping (UUID, Bool) -> Void) {
        guard !isJumping, phase == .idle, let target = neighbor(direction) else { return }
        let token = UUID()
        requestID = token
        isJumping = true
        jumpTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == token {
                    self.isJumping = false
                    self.requestID = nil
                    self.jumpTask = nil
                }
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(8))
            do {
                try self.checkRequest(target: target, token: token)
                scroll(target, !reduceMotion)
                var lastMiss: Layout?
                for attempt in 0...2 {
                    let snapshot = try await self.waitForStableLayout(target: target, token: token, deadline: deadline)
                    if snapshot.isAligned { return }
                    if let lastMiss, snapshot.near(lastMiss) { return }
                    guard attempt < 2 else { return }
                    lastMiss = snapshot
                    try self.checkRequest(target: target, token: token)
                    // Corrections are unanimated; never animate a second trip through long content.
                    scroll(target, false)
                }
            } catch { /* Cancellation, disappearance and timeout all release the controls. */ }
        }
    }

    func cancel() {
        jumpTask?.cancel()
        jumpTask = nil
        requestID = nil
        isJumping = false
    }

    private struct Layout {
        let viewport: CGRect
        let metrics: ScrollMetrics
        let frames: [UUID: CGRect]
        let target: CGRect?
        let epoch: Int
        let margin: CGFloat

        var isAligned: Bool {
            target.map { abs($0.minY - viewport.minY) <= TodayMenuJumpController.alignmentTolerance } == true
        }

        func near(_ other: Self) -> Bool {
            func nearRect(_ a: CGRect, _ b: CGRect) -> Bool {
                abs(a.minX - b.minX) <= 0.5 && abs(a.minY - b.minY) <= 0.5
                    && abs(a.width - b.width) <= 0.5 && abs(a.height - b.height) <= 0.5
            }
            return epoch == other.epoch && nearRect(viewport, other.viewport)
                && Set(frames.keys) == Set(other.frames.keys)
                && frames.allSatisfy { id, frame in other.frames[id].map { nearRect(frame, $0) } == true }
                && zip([metrics.offset, metrics.contentHeight, metrics.containerHeight,
                        metrics.topInset, metrics.bottomInset, margin],
                       [other.metrics.offset, other.metrics.contentHeight, other.metrics.containerHeight,
                        other.metrics.topInset, other.metrics.bottomInset, other.margin])
                    .allSatisfy { abs($0 - $1) <= 0.5 }
        }
    }

    private func checkRequest(target: UUID, token: UUID) throws {
        try Task.checkCancellation()
        guard requestID == token, order.contains(target), phase != .userInteraction else {
            throw CancellationError()
        }
    }

    private func waitForStableLayout(target: UUID, token: UUID,
                                     deadline: ContinuousClock.Instant) async throws -> Layout {
        var previous: Layout?
        var matches = 0
        while ContinuousClock.now < deadline {
            try checkRequest(target: target, token: token)
            if phase == .idle, let metrics, viewport.height > 0 {
                let frames = liveFrames
                let value = Layout(viewport: viewport, metrics: metrics, frames: frames,
                                   target: frames[target], epoch: epoch, margin: bottomMargin)
                matches = previous.map { value.near($0) } == true ? matches + 1 : 0
                previous = value
                // An aligned target needs only two matching 20ms samples after the first one.
                // Keep the previous ~480ms stability window before deciding to retry a miss.
                if matches >= (value.isAligned ? 2 : 24) { return value }
            } else { matches = 0; previous = nil }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw CancellationError()
    }
}
