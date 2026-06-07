import AppIntents
import SwiftData

// MARK: - Helpers

@MainActor
private func fetchChore(_ id: UUID, _ context: ModelContext) -> Chore? {
    (try? context.fetch(FetchDescriptor<Chore>()))?.first { $0.uuid == id }
}

@MainActor
private func fetchParticipant(_ id: UUID, _ context: ModelContext) -> Participant? {
    (try? context.fetch(FetchDescriptor<Participant>()))?.first { $0.uuid == id }
}

@MainActor
private func points(for participant: Participant, in range: TimeRange) -> Int {
    let lower = range.lowerBound
    return participant.completions.reduce(0) { sum, completion in
        guard !completion.isSoftDeleted else { return sum }
        if let lower, completion.completedAt < lower { return sum }
        return sum + completion.pointsAwarded
    }
}

private func periodPhrase(_ range: TimeRange) -> String {
    switch range {
    case .today: return "today"
    case .week: return "this week"
    case .all: return "all-time"
    }
}

// MARK: - Log a chore

struct LogChoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Chore"
    static var description = IntentDescription("Log a completed chore for someone and earn points.")

    @Parameter(title: "Chore") var chore: ChoreEntity
    @Parameter(title: "Who") var participant: ParticipantEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$chore) for \(\.$participant)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext
        guard let choreModel = fetchChore(chore.id, context) else { throw $chore.needsValueError() }
        guard let personModel = fetchParticipant(participant.id, context) else { throw $participant.needsValueError() }

        context.insert(Completion(chore: choreModel, participant: personModel))
        // Let a save failure propagate so Siri/Shortcuts reports it instead of
        // falsely confirming success (the app's no-silent-data-loss rule).
        try context.save()
        WidgetUpdater.refresh(context) // keep widgets in step; cloud/watch sync on next app foreground

        return .result(dialog: "Logged \(chore.emoji) \(chore.name) for \(participant.name) · +\(chore.points) pts")
    }
}

// MARK: - Get someone's points

struct GetPointsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Points"
    static var description = IntentDescription("Get how many points a person has earned.")

    @Parameter(title: "Who") var participant: ParticipantEntity
    @Parameter(title: "Period", default: .week) var period: TimeRange

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$participant)'s points \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext
        guard let personModel = fetchParticipant(participant.id, context) else {
            return .result(value: 0, dialog: "Couldn't find \(participant.name).")
        }
        let total = points(for: personModel, in: period)
        return .result(value: total,
                       dialog: "\(participant.name) has \(total) point\(total == 1 ? "" : "s") \(periodPhrase(period)).")
    }
}

// MARK: - Leaderboard

struct LeaderboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Leaderboard"
    static var description = IntentDescription("See who's ahead.")

    @Parameter(title: "Period", default: .week) var period: TimeRange

    static var parameterSummary: some ParameterSummary {
        Summary("Show the leaderboard \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext
        let people = ((try? context.fetch(FetchDescriptor<Participant>())) ?? []).filter { !$0.isSoftDeleted }
        let standings = people
            .map { (person: $0, points: points(for: $0, in: period)) }
            .sorted { $0.points != $1.points ? $0.points > $1.points
                : $0.person.name.localizedCaseInsensitiveCompare($1.person.name) == .orderedAscending }

        guard !standings.isEmpty else {
            return .result(value: "No players yet", dialog: "No players yet — add someone in ChoreQuest first.")
        }

        let lines = standings.enumerated().map { index, entry in
            "\(index + 1). \(entry.person.emoji) \(entry.person.name): \(entry.points)"
        }
        let text = lines.joined(separator: "\n")
        return .result(value: text, dialog: "Leaderboard \(periodPhrase(period)):\n\(text)")
    }
}
