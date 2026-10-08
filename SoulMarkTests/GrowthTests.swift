import Foundation
import Testing
@testable import SoulMark

struct GrowthTests {
    @Test func decodesProgressAndKeepsEarnedMilestones() throws {
        let data = Data("""
        {"balance":110,"level":2,"level_experience":10,"next_level_experience":150,
        "peak_level":10,"chat_experience_today":5,"title_key":"explorer",
        "next_title_level":3,"decayed_experience":30,"next_decay_date":"2026-10-20"}
        """.utf8)
        let growth = try JSONDecoder().decode(GrowthSnapshot.self, from: data)
        #expect(growth.level == 2)
        #expect(growth.progress == 10.0 / 150.0)
        #expect(growth.currentMilestone.level == 1)
        #expect(growth.unlockedMilestones.map(\.level) == [1, 3, 5, 10])
    }

    @Test func chatPayloadIncludesOnlyNewCompleteTranscripts() {
        let events = [
            RealtimeTranscriptEvent(role: .assistant, text: "Hello"),
            RealtimeTranscriptEvent(role: .user, text: "First\nsecond line"),
            RealtimeTranscriptEvent(role: .assistant, text: "Response"),
            RealtimeTranscriptEvent(role: .user, text: "Unanswered")
        ]
        let messages = GrowthChatMessage.from(events)
        #expect(messages.count == 4)
        #expect(messages[1].text == "First\nsecond line")
        #expect(messages[1].role == "user")
    }

    @Test func requestGuardRejectsOldAccountsAndResponses() {
        var guardState = GrowthRequestGuard()
        let old = guardState.begin()
        let current = guardState.begin()
        #expect(!guardState.accepts(old))
        #expect(guardState.accepts(current))
        guardState.invalidate()
        #expect(!guardState.accepts(current))
    }
    @Test @MainActor func onlyConfirmedAssistantAnswersBecomeRewardable() throws {
        let manager = RealtimeVoiceCallManager()
        try manager.handleServerText(#"{"type":"user.transcript.completed","text":"Hi"}"#)
        try manager.handleServerText(#"{"type":"assistant.transcript.completed","text":"Draft"}"#)
        #expect(manager.completedTranscripts.count == 1)
        let confirmed = #"{"type":"assistant.turn.completed","text":"Final","response_id":"r1"}"#
        try manager.handleServerText(confirmed)
        try manager.handleServerText(confirmed)
        #expect(manager.completedTranscripts.count == 2)
        #expect(manager.completedTranscripts.last?.text == "Final")
    }

    @Test func failedCallCanBeFinalizedOnceBeforeStartingAnother() {
        var capture = GrowthCallCapture()
        capture.begin(participant: "Soul", mode: "Practice", guidance: "")
        let events = [RealtimeTranscriptEvent(role: .user, text: "Hi"), RealtimeTranscriptEvent(role: .assistant, text: "Hello")]
        let first = capture.finish(ownerID: UUID(), duration: 5, events: events)
        #expect(first != nil)
        #expect(capture.finish(ownerID: UUID(), duration: 5, events: events) == nil)
        capture.begin(participant: "Soul", mode: "Practice", guidance: "")
        let second = capture.finish(ownerID: UUID(), duration: 5, events: events)
        #expect(second != nil)
        #expect(first?.id != second?.id)
        #expect(first?.messages.count == 2)
    }

}
