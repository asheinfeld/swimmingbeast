import Foundation
import XCTest
@testable import SwimCore

final class SwimWorkoutTests: XCTestCase {
    private func workout(pool: PoolLength, strokes: [StrokeStyle], split: TimeInterval = 30) -> SwimWorkout {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let lengths = strokes.enumerated().map { i, stroke in
            Length(index: i + 1, duration: split, stroke: stroke, poolLength: pool.measurement,
                   startedAt: start.addingTimeInterval(Double(i) * (split + 10)))
        }
        return SwimWorkout(startedAt: start, endedAt: start.addingTimeInterval(3600),
                           poolLength: pool.measurement, lengths: lengths)
    }

    func testDistanceIsLengthsTimesPool() {
        let w = workout(pool: .meters25, strokes: Array(repeating: .freestyle, count: 40))
        XCTAssertEqual(w.distance.value, 1000)
        XCTAssertEqual(w.distance.unit, UnitLength.meters)

        let yards = workout(pool: .yards25, strokes: Array(repeating: .freestyle, count: 4))
        XCTAssertEqual(yards.distance.value, 100)
        XCTAssertEqual(yards.distance.unit, UnitLength.yards)
    }

    func testAveragePaceExcludesRest() throws {
        let w = workout(pool: .meters25, strokes: Array(repeating: .freestyle, count: 4), split: 25)
        let pace = try XCTUnwrap(w.averagePace)
        XCTAssertEqual(pace.converted(to: .metersPerSecond).value, 1.0, accuracy: 0.0001)
        XCTAssertEqual(SwimFormat.pace(pace, unit: .meters), "1:40 /100m")
    }

    func testPacePer100Yards() throws {
        // 25 yd in 20 s → 100 yd in 80 s.
        let speed = try XCTUnwrap(Pace.speed(distance: Measurement(value: 25, unit: .yards), duration: 20))
        XCTAssertEqual(try XCTUnwrap(Pace.secondsPer100(speed, unit: .yards)), 80, accuracy: 0.001)
        XCTAssertEqual(SwimFormat.pace(speed, unit: .yards), "1:20 /100yd")
    }

    func testSplitPaceDerivedFromPoolLength() throws {
        let length = Length(index: 1, duration: 50, stroke: .freestyle, poolLength: PoolLength.meters50.measurement)
        XCTAssertEqual(try XCTUnwrap(length.splitPace).converted(to: .metersPerSecond).value, 1.0, accuracy: 0.0001)
    }

    func testStrokeMix() {
        let w = workout(pool: .meters25, strokes: [.freestyle, .freestyle, .backstroke, .butterfly])
        let mix = w.strokeMix
        XCTAssertEqual(mix.map(\.stroke), [.freestyle, .backstroke, .butterfly])
        XCTAssertEqual(mix.first?.fraction, 0.5)
        XCTAssertEqual(mix.reduce(0) { $0 + $1.fraction }, 1, accuracy: 0.0001)
        XCTAssertTrue(workout(pool: .meters25, strokes: []).strokeMix.isEmpty)
    }

    func testOverrideStrokeMarksUserSource() {
        var w = workout(pool: .meters25, strokes: [.freestyle, .unknown])
        let target = w.lengths[1].id
        XCTAssertTrue(w.overrideStroke(lengthId: target, style: .butterfly))
        XCTAssertEqual(w.lengths[1].stroke, .butterfly)
        XCTAssertEqual(w.lengths[1].strokeSource, .user)
        XCTAssertEqual(w.userOverrides, [2: .butterfly])
        XCTAssertFalse(w.overrideStroke(lengthId: UUID(), style: .freestyle))
    }

    func testApplyingOverridesByIndex() {
        let w = workout(pool: .meters25, strokes: [.freestyle, .freestyle, .freestyle])
            .applyingOverrides([3: .breaststroke, 99: .butterfly])
        XCTAssertEqual(w.lengths.map(\.stroke), [.freestyle, .freestyle, .breaststroke])
        XCTAssertEqual(w.lengths.map(\.strokeSource), [.healthKit, .healthKit, .user])
    }

    func testCodableRoundTrip() throws {
        var w = workout(pool: .yards25, strokes: [.freestyle, .backstroke])
        w.healthKitUUID = UUID()
        let decoded = try SwimWorkoutCoding.decode(SwimWorkoutCoding.encode(w))
        XCTAssertEqual(decoded, w)
    }
}

final class StrokeStyleTests: XCTestCase {
    func testHealthKitRawValueMapping() {
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 0), .unknown)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 1), .mixed)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 2), .freestyle)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 3), .backstroke)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 4), .breaststroke)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 5), .butterfly)
        XCTAssertEqual(StrokeStyle(healthKitRawValue: 6), .unknown, "kickboard has no case")
        XCTAssertEqual(StrokeStyle(healthKitRawValue: nil), .unknown)
        for style in StrokeStyle.allCases {
            XCTAssertEqual(StrokeStyle(healthKitRawValue: style.healthKitRawValue), style)
        }
    }
}

final class PoolLengthTests: XCTestCase {
    func testMatchesMeasurement() {
        XCTAssertEqual(PoolLength(measurement: Measurement(value: 25, unit: .yards)), .yards25)
        XCTAssertEqual(PoolLength(measurement: Measurement(value: 25, unit: .meters)), .meters25)
        XCTAssertEqual(PoolLength(measurement: Measurement(value: 0.05, unit: .kilometers)), .meters50)
        XCTAssertNil(PoolLength(measurement: Measurement(value: 33.33, unit: .meters)))
    }

    func testDisplayUnitResolution() {
        XCTAssertEqual(DisplayUnitPreference.matchPool.resolve(for: PoolLength.yards25.measurement), .yards)
        XCTAssertEqual(DisplayUnitPreference.matchPool.resolve(for: PoolLength.meters50.measurement), .meters)
        XCTAssertEqual(DisplayUnitPreference.yards.resolve(for: PoolLength.meters25.measurement), .yards)
    }
}

final class FormatTests: XCTestCase {
    func testFormats() {
        XCTAssertEqual(SwimFormat.duration(65), "1:05")
        XCTAssertEqual(SwimFormat.duration(3725), "1:02:05")
        XCTAssertEqual(SwimFormat.split(32.44), "32.4")
        XCTAssertEqual(SwimFormat.split(75.5), "1:15.5")
        XCTAssertEqual(SwimFormat.distance(Measurement(value: 1250, unit: .meters), unit: .meters), "1,250 m")
        XCTAssertEqual(SwimFormat.distance(Measurement(value: 100, unit: .yards), unit: .meters), "91 m")
        XCTAssertEqual(SwimFormat.pace(nil, unit: .meters), "--:-- /100m")
        XCTAssertEqual(SwimFormat.percent(0.333), "33%")
    }
}

final class LengthReconcilerTests: XCTestCase {
    let pool = PoolLength.meters25.measurement
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testBuildsIndexedLengthsInOrder() {
        let laps = [
            LapRecord(start: t0.addingTimeInterval(40), duration: 31, stroke: .backstroke),
            LapRecord(start: t0, duration: 30, stroke: .freestyle),
        ]
        let lengths = LengthReconciler.reconcile(existing: [], laps: laps, poolLength: pool)
        XCTAssertEqual(lengths.map(\.index), [1, 2])
        XCTAssertEqual(lengths.map(\.stroke), [.freestyle, .backstroke])
        XCTAssertNotNil(lengths[0].splitPace)
    }

    func testKeepsIdsAndUserOverridesAcrossUpdates() {
        let first = LengthReconciler.reconcile(
            existing: [], laps: [LapRecord(start: t0, duration: 30, stroke: .freestyle)], poolLength: pool)
        var edited = first
        edited[0].stroke = .butterfly
        edited[0].strokeSource = .user

        let second = LengthReconciler.reconcile(
            existing: edited,
            laps: [
                LapRecord(start: t0, duration: 30, stroke: .mixed),
                LapRecord(start: t0.addingTimeInterval(40), duration: 29, stroke: .freestyle),
            ],
            poolLength: pool)

        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second[0].id, first[0].id)
        XCTAssertEqual(second[0].stroke, .butterfly)
        XCTAssertEqual(second[0].strokeSource, .user)
        XCTAssertEqual(second[1].strokeSource, .healthKit)
    }

    func testHealthKitRefinementUpdatesNonOverriddenStroke() {
        let first = LengthReconciler.reconcile(
            existing: [], laps: [LapRecord(start: t0, duration: 30, stroke: .unknown)], poolLength: pool)
        let second = LengthReconciler.reconcile(
            existing: first, laps: [LapRecord(start: t0, duration: 30, stroke: .freestyle)], poolLength: pool)
        XCTAssertEqual(second[0].id, first[0].id)
        XCTAssertEqual(second[0].stroke, .freestyle)
    }
}

@MainActor
final class StrokeOverrideTests: XCTestCase {
    func testMetadataRoundTrip() async {
        let overrides: [Int: StrokeStyle] = [1: .butterfly, 12: .breaststroke]
        let encoded = StrokeOverrideMetadata.encode(overrides)
        XCTAssertEqual(encoded, #"{"1":"butterfly","12":"breaststroke"}"#)
        XCTAssertEqual(StrokeOverrideMetadata.decode(encoded), overrides)
        XCTAssertNil(StrokeOverrideMetadata.encode([:]))
        XCTAssertEqual(StrokeOverrideMetadata.decode("not json"), [:])
    }

    func testInMemoryStoreAppliesAndClears() async {
        let store = InMemoryStrokeOverrideStore()
        let workout = SampleData.first
        store.setOverride(.butterfly, lengthIndex: 1, workoutKey: workout.overrideKey)
        XCTAssertEqual(store.applyOverrides(to: workout).lengths[0].stroke, .butterfly)

        store.setOverride(nil, lengthIndex: 1, workoutKey: workout.overrideKey)
        XCTAssertTrue(store.overrides(forWorkoutKey: workout.overrideKey).isEmpty)
    }

    func testOverrideKeyPrefersHealthKitUUID() async {
        var w = SampleData.first
        XCTAssertEqual(w.overrideKey, w.id.uuidString)
        let hk = UUID()
        w.healthKitUUID = hk
        XCTAssertEqual(w.overrideKey, hk.uuidString)
    }
}

final class SampleDataTests: XCTestCase {
    func testSamplesAreLabeled() {
        XCTAssertFalse(SampleData.workouts.isEmpty)
        XCTAssertTrue(SampleData.workouts.allSatisfy(\.isSample))
        XCTAssertEqual(SampleData.workouts.map(\.id).count, Set(SampleData.workouts.map(\.id)).count)
    }
}
