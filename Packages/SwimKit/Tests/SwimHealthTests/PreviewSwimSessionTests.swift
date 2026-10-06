import Foundation
import XCTest
import SwimCore
@testable import SwimHealth

@MainActor
final class PreviewSwimSessionTests: XCTestCase {
    func testLifecycleThroughProtocol() async throws {
        let store = InMemoryStrokeOverrideStore()
        let session: any SwimSessionServing = {
            PreviewSwimSession(autoGenerate: false, overrideStore: store)
        }()
        let preview = try XCTUnwrap(session as? PreviewSwimSession)

        XCTAssertEqual(session.state, .idle)
        try await session.start(poolLength: PoolLength.yards25.measurement)
        XCTAssertEqual(session.state, .running)
        XCTAssertTrue(session.isSimulated)

        preview.simulateLength(duration: 20, stroke: .freestyle)
        preview.simulateLength(duration: 22, stroke: .unknown)
        XCTAssertEqual(session.lengths.map(\.index), [1, 2])
        XCTAssertEqual(session.distance.value, 50)
        XCTAssertEqual(session.distance.unit, UnitLength.yards)

        session.overrideStroke(lengthId: session.lengths[1].id, style: .backstroke)
        XCTAssertEqual(session.lengths[1].strokeSource, .user)

        session.pause()
        XCTAssertEqual(session.state, .paused)
        session.resume()
        XCTAssertEqual(session.state, .running)

        let workout = try await session.endAndSave()
        XCTAssertEqual(session.state, .ended)
        XCTAssertEqual(workout.lengths.count, 2)
        XCTAssertTrue(workout.isSample)
        XCTAssertEqual(store.overrides(forWorkoutKey: workout.overrideKey), [2: .backstroke])
        XCTAssertEqual(session.completedWorkout, workout)

        session.reset()
        XCTAssertEqual(session.state, .idle)
        XCTAssertTrue(session.lengths.isEmpty)
    }

    func testEndWithoutStartThrows() async {
        let session = PreviewSwimSession(autoGenerate: false)
        do {
            try await session.endAndSave()
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? SwimSessionError, .notActive)
        }
    }

    func testElapsedTimeExcludesPause() async throws {
        let session = PreviewSwimSession(autoGenerate: false)
        try await session.start(poolLength: PoolLength.meters25.measurement)
        let start = try XCTUnwrap(session.startedAt)
        XCTAssertEqual(session.elapsedTime(at: start.addingTimeInterval(10)), 10, accuracy: 0.001)
        XCTAssertEqual(session.elapsedTime(at: start.addingTimeInterval(-5)), 0)
    }

    func testSampleHistoryIsLabeled() async throws {
        let workouts = try await SampleSwimHistory().loadWorkouts(limit: 2)
        XCTAssertEqual(workouts.count, 2)
        XCTAssertTrue(workouts.allSatisfy(\.isSample))
    }
}
