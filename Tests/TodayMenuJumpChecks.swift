import Foundation
import CoreGraphics

@main
@MainActor
struct TodayMenuJumpChecks {
    static func main() async throws {
        typealias Controller = TodayMenuJumpController
        let ids = (0..<3).map { _ in UUID() }
        let viewport = CGRect(x: 0, y: 122, width: 420, height: 756)
        var checks = 0
        func expect(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        func rect(_ y: CGFloat, _ height: CGFloat = 1000) -> CGRect {
            CGRect(x: 20, y: y, width: 380, height: height)
        }
        func current(_ frames: [UUID: CGRect], previous: UUID? = nil) -> UUID? {
            Controller.currentRecipe(order: ids, frames: frames, viewport: viewport, previous: previous)
        }
        expect(Controller.tailMargin(viewportHeight: 756, cardHeight: 113.6667) > 642.3, "Measured short tail")
        expect(abs(Controller.tailMargin(viewportHeight: 756, cardHeight: 58.3333) - 697.6667) < 0.001, "Collapsed tail includes row insets")
        expect(Controller.tailMargin(viewportHeight: 756, cardHeight: 2359) == 0, "Long tail needs no alignment padding")
        expect(Controller.tailMargin(viewportHeight: 756, cardHeight: nil) == 0, "Do not guess an unrealized height")
        expect(current([:]) == nil, "No stale fallback without measurements")
        expect(current([ids[0]: rect(-900, 2700)]) == ids[0], "Middle of a long card")
        expect(current([ids[0]: rect(-200), ids[1]: rect(804)]) == ids[0], "Multiple visible cards use viewport top")
        expect(current([ids[1]: rect(124)]) == ids[0], "A gap belongs to a recycled preceding row")
        expect(current([ids[1]: rect(122)]) == ids[1], "Exact header alignment selects the target")
        expect(current([ids[1]: rect(123.2)], previous: ids[1]) == ids[1], "Boundary jitter retains measured current card")
        expect(current([ids[1]: rect(120.8)], previous: ids[0]) == ids[0], "Hysteresis is symmetric")
        expect(current([ids[1]: rect(119)], previous: ids[0]) == ids[1], "Beyond dead band changes card")
        expect(current([ids[2]: rect(0)]) == ids[2], "Manual scrolling selects the last card")
        expect(current([ids[0]: rect(157, 58)]) == ids[0], "Initial grouped section inset")

        let tokens = ids.map { _ in UUID() }
        func report(_ model: Controller, _ frames: [CGRect]) {
            // Height updates deliberately invalidate an epoch; re-sample as the row backgrounds do.
            for _ in 0..<3 {
                for index in ids.indices where model.order.contains(ids[index]) {
                    model.measure(ids[index], frame: frames[index], epoch: model.epoch, instance: tokens[index])
                }
            }
        }
        let initial = [rect(122), rect(1126), rect(2130, 113.6667)]
        func make() -> Controller {
            let model = Controller()
            model.updateOrder(ids)
            model.updateViewport(viewport)
            model.updateScroll(.init(offset: 0, contentHeight: 2400, containerHeight: 912, topInset: 122, bottomInset: 34))
            report(model, initial)
            return model
        }
        func place(_ model: Controller, secondTop: CGFloat, extraHeight: CGFloat = 0) {
            model.updateScroll(.init(offset: 1126 - secondTop, contentHeight: 2400 + extraHeight,
                                     containerHeight: 912, topInset: 122, bottomInset: 34))
            report(model, [rect(secondTop - 1004), rect(secondTop), rect(secondTop + 1004, 113.6667)])
        }
        func finished(_ model: Controller, seconds: Double = 4) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
            while model.isJumping && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
            expect(!model.isJumping, "Every request must release busy state")
        }

        let model = make()
        expect(model.currentID == ids[0], "Live initial current")
        expect(model.neighbor(.previous) == nil && model.neighbor(.next) == ids[1], "First direction states")
        report(model, [rect(-500), rect(504), rect(1508, 113.6667)])
        expect(model.currentID == ids[0] && model.neighbor(.previous) == ids[0], "First recipe midway can return to its own top")
        expect(model.neighbor(.next) == ids[1], "Downward navigation is unchanged midway")
        report(model, [rect(118), rect(1122), rect(2126, 113.6667)])
        expect(model.neighbor(.previous) == nil, "First recipe within 4pt is aligned")
        report(model, [rect(117.9), rect(1121.9), rect(2125.9, 113.6667)])
        expect(model.neighbor(.previous) == ids[0], "Beyond alignment tolerance returns to first recipe")
        let oldEpoch = model.epoch
        model.updateScroll(.init(offset: 1004, contentHeight: 2400, containerHeight: 912, topInset: 122, bottomInset: 34))
        expect(model.currentID == nil && model.neighbor(.next) == nil, "Invalidate previous scroll coordinates")
        model.measure(ids[1], frame: rect(122), epoch: oldEpoch, instance: tokens[1])
        expect(model.currentID == nil, "Reject a late geometry callback")
        place(model, secondTop: 122)
        expect(model.currentID == ids[1] && model.neighbor(.previous) == ids[0], "Re-sampling restores actual position")
        place(model, secondTop: 118)
        expect(model.neighbor(.previous) == ids[0], "Aligned second recipe goes to previous within tolerance")
        place(model, secondTop: 117.9)
        expect(model.neighbor(.previous) == ids[1], "Second recipe beyond tolerance returns to its own top")
        place(model, secondTop: -500)
        expect(model.currentID == ids[1] && model.neighbor(.previous) == ids[1], "Second recipe midway returns to itself")
        expect(model.neighbor(.next) == ids[2], "Next still advances from second recipe midway")
        place(model, secondTop: 126)
        expect(model.currentID == ids[0] && model.neighbor(.previous) == ids[0], "Gap belongs to preceding recipe, whose top is above viewport")
        model.removeMeasurement(ids[0], instance: tokens[0])
        expect(model.currentID == ids[0] && model.neighbor(.previous) == ids[0], "Recycled gap predecessor is an upward target without stale geometry")
        place(model, secondTop: 122)
        model.removeMeasurement(ids[1], instance: UUID())
        expect(model.currentID == ids[1], "Old recycled instance cannot remove a new measurement")
        model.removeMeasurement(ids[1], instance: tokens[1])
        expect(model.currentID == nil, "Disappeared row coordinates are removed")
        report(model, [rect(-1886), rect(-882), rect(122, 113.6667)])
        expect(model.currentID == ids[2] && model.neighbor(.next) == nil, "Last direction states")
        model.updateControlsHeight(104)
        expect(abs(model.bottomMargin - 642.3333) < 0.001, "Use maximum, not sum, of clearance and tail margin")
        report(model, [rect(-1886), rect(-882), rect(122, 900)])
        expect(model.bottomMargin == 116, "Long last card retains room to reach links behind buttons")
        report(model, [rect(-1886), rect(-882), rect(122, 200)])
        expect(model.bottomMargin == 556, "Photo/layout height changes recalculate padding")
        model.updateViewport(CGRect(x: 0, y: 122, width: 500, height: 700))
        expect(model.currentID == nil && model.bottomMargin == 116, "Width changes invalidate cached heights")
        model.updateOrder([ids[0]])
        expect(model.bottomMargin == 0 && model.neighbor(.next) == nil, "Single recipe")
        model.updateOrder([])
        expect(model.bottomMargin == 0 && model.currentID == nil, "Empty menu")

        let closing = make()
        closing.measure(ids[2], frame: rect(122, 58.3333), epoch: closing.epoch, instance: tokens[2], expanded: false)
        closing.measure(ids[2], frame: rect(122, 2359), epoch: closing.epoch, instance: tokens[2], expanded: true)
        expect(closing.margin(lastExpanded: true) == 0, "Expanded long tail")
        expect(abs(closing.margin(lastExpanded: false) - 697.6667) < 0.001, "Collapse reserves known height before UIKit clamps")
        closing.measure(ids[2], frame: rect(122, 2359), epoch: closing.epoch, instance: tokens[2], expanded: false)
        expect(abs(closing.margin(lastExpanded: false) - 697.6667) < 0.001, "Do not overwrite collapsed cache with old expanded frame")
        closing.measure(ids[2], frame: rect(122, 58.3333), epoch: closing.epoch, instance: tokens[2], expanded: false)
        expect(abs(closing.bottomMargin - 697.6667) < 0.001, "Measured short height replaces transition state")

        let aligned = make()
        var calls: [(UUID, Bool)] = []
        let alignedStart = ContinuousClock.now
        aligned.jump(.next, reduceMotion: false) { id, animated in
            calls.append((id, animated)); place(aligned, secondTop: 122)
        }
        aligned.jump(.next, reduceMotion: false) { _, _ in preconditionFailure("Do not queue taps") }
        try await finished(aligned)
        let alignedDuration = alignedStart.duration(to: .now)
        expect(alignedDuration < .milliseconds(350), "Aligned stable layout unlocks earlier than the old 480ms window")
        expect(calls.count == 1 && calls[0].0 == ids[1] && calls[0].1, "Aligned first move never retries")
        aligned.jump(.previous, reduceMotion: true) { id, animated in
            calls.append((id, animated)); place(aligned, secondTop: 1126)
        }
        try await finished(aligned)
        expect(calls.count == 2 && calls[1].0 == ids[0], "Immediate next operation uses fresh aligned coordinates")

        let returning = make()
        report(returning, [rect(-500), rect(504), rect(1508, 113.6667)])
        var returned: UUID?
        returning.jump(.previous, reduceMotion: true) { id, _ in
            returned = id; report(returning, initial)
        }
        try await finished(returning)
        expect(returned == ids[0] && returning.neighbor(.previous) == nil, "Up returns first recipe to top then disables")

        let moving = make()
        var movingCalls = 0
        moving.jump(.next, reduceMotion: false) { _, _ in
            movingCalls += 1
            moving.updatePhase(.moving)
            place(moving, secondTop: 122)
        }
        while movingCalls == 0 { await Task.yield() }
        try await Task.sleep(for: .milliseconds(100))
        expect(moving.isJumping, "Alignment alone never unlocks during animation")
        moving.updatePhase(.idle)
        try await Task.sleep(for: .milliseconds(60))
        expect(moving.isJumping, "Idle without fresh geometry does not finish a jump")
        place(moving, secondTop: 122)
        try await finished(moving)
        expect(movingCalls == 1, "Stopped and aligned movement finishes without a correction")

        let retry = make()
        calls = []
        retry.jump(.next, reduceMotion: false) { id, animated in
            calls.append((id, animated))
            if calls.count == 2 { place(retry, secondTop: 122) }
        }
        try await finished(retry)
        expect(calls.count == 2 && !calls[1].1, "An initially missed request is corrected once without animation")

        let bounded = make()
        calls = []
        bounded.jump(.next, reduceMotion: true) { id, animated in
            calls.append((id, animated))
            if calls.count == 2 { place(bounded, secondTop: 600, extraHeight: 1) }
            if calls.count == 3 { place(bounded, secondTop: 300, extraHeight: 2) }
        }
        try await finished(bounded)
        expect(calls.count == 3, "Maximum two retries")
        expect(calls.allSatisfy { !$0.1 }, "Reduce Motion suppresses every animation")

        let noProgress = make()
        var misses = 0
        noProgress.jump(.next, reduceMotion: false) { _, _ in misses += 1 }
        try await finished(noProgress)
        expect(misses == 2, "Unchanged failed correction stops early")

        let interrupted = make()
        var interruptedCalls = 0
        interrupted.jump(.next, reduceMotion: false) { _, _ in interruptedCalls += 1 }
        while interruptedCalls == 0 { await Task.yield() }
        interrupted.updatePhase(.userInteraction)
        expect(!interrupted.isJumping, "Manual interaction immediately unlocks controls")
        try await Task.sleep(for: .milliseconds(600))
        expect(interruptedCalls == 1, "Manual interaction cancels pending retries")
        interrupted.updatePhase(.idle)
        report(interrupted, initial)
        interrupted.jump(.next, reduceMotion: true) { _, _ in place(interrupted, secondTop: 122) }
        try await finished(interrupted)
        expect(interrupted.currentID == ids[1], "A new request works after interruption")

        let deleted = make()
        var deletedCalls = 0
        deleted.jump(.next, reduceMotion: false) { _, _ in deletedCalls += 1 }
        while deletedCalls == 0 { await Task.yield() }
        deleted.updateOrder([ids[0], ids[2]])
        expect(!deleted.isJumping, "Deleting a target cancels its request")
        try await Task.sleep(for: .milliseconds(600))
        expect(deletedCalls == 1, "Deleted UUID is never retried")
        deleted.updateOrder([ids[2], ids[0]])
        expect(deleted.currentID == nil, "Reorder clears old positions")

        let queued = make()
        var lateCalls = 0
        queued.jump(.next, reduceMotion: true) { _, _ in lateCalls += 1 }
        queued.cancel()
        try await Task.sleep(for: .milliseconds(100))
        expect(lateCalls == 0 && !queued.isJumping, "Cancellation before task start never scrolls later")

        let absentMetrics = Controller()
        absentMetrics.updateOrder(ids)
        absentMetrics.updateViewport(viewport)
        report(absentMetrics, initial)
        absentMetrics.jump(.next, reduceMotion: true) { _, _ in }
        try await finished(absentMetrics, seconds: 9)
        expect(absentMetrics.currentID == ids[0], "Timeout leaves menu content intact")
        print("PASS: \(checks) recipe jump geometry, padding, retry, cancellation, and lifecycle checks; aligned unlock: \(alignedDuration)")
    }
}
