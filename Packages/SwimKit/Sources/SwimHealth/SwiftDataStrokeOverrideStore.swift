#if canImport(SwiftData)
import Foundation
import SwiftData
import SwimCore

@Model
public final class StrokeOverrideRecord {
    public var workoutKey: String
    public var lengthIndex: Int
    public var strokeRaw: String
    public var updatedAt: Date

    public init(workoutKey: String, lengthIndex: Int, stroke: StrokeStyle, updatedAt: Date = .now) {
        self.workoutKey = workoutKey
        self.lengthIndex = lengthIndex
        self.strokeRaw = stroke.rawValue
        self.updatedAt = updatedAt
    }
}

public enum SwimPersistence {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: StrokeOverrideRecord.self, configurations: configuration)
    }
}

@MainActor
public final class SwiftDataStrokeOverrideStore: StrokeOverrideStoring {
    private let context: ModelContext

    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func overrides(forWorkoutKey key: String) -> [Int: StrokeStyle] {
        var result: [Int: StrokeStyle] = [:]
        for record in records(forWorkoutKey: key) {
            if let style = StrokeStyle(rawValue: record.strokeRaw) {
                result[record.lengthIndex] = style
            }
        }
        return result
    }

    public func setOverride(_ style: StrokeStyle?, lengthIndex: Int, workoutKey: String) {
        let existing = records(forWorkoutKey: workoutKey).filter { $0.lengthIndex == lengthIndex }
        switch (style, existing.first) {
        case (nil, _):
            existing.forEach { context.delete($0) }
        case (let style?, let record?):
            record.strokeRaw = style.rawValue
            record.updatedAt = .now
            existing.dropFirst().forEach { context.delete($0) }
        case (let style?, nil):
            context.insert(StrokeOverrideRecord(workoutKey: workoutKey, lengthIndex: lengthIndex, stroke: style))
        }
        try? context.save()
    }

    private func records(forWorkoutKey key: String) -> [StrokeOverrideRecord] {
        let descriptor = FetchDescriptor<StrokeOverrideRecord>(
            predicate: #Predicate { $0.workoutKey == key },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
#endif
