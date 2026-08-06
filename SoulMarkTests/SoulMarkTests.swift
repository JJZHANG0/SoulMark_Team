//
//  SoulMarkTests.swift
//  SoulMarkTests
//
//  Created by JJ Zhang on 2026/8/3.
//

import Testing
import CoreGraphics
import Foundation
import UIKit
@testable import SoulMark

struct SoulMarkTests {

    @Test func scenarioEmotionFallsBackToCalm() {
        #expect(ScenarioEmotion(serverValue: "happy") == .happy)
        #expect(ScenarioEmotion(serverValue: "unexpected") == .calm)
        #expect(ScenarioEmotion(serverValue: nil) == .calm)
    }

    @Test func realtimePhaseHasPriorityOverEmotion() {
        #expect(RealtimeVoiceCallPhase.idle.mascotAnimationState(emotion: .happy) == .idle)
        #expect(RealtimeVoiceCallPhase.listening.mascotAnimationState(emotion: .happy) == .listening)
        #expect(RealtimeVoiceCallPhase.speaking.mascotAnimationState(emotion: .caring) == .speaking(.caring))
        #expect(RealtimeVoiceCallPhase.failed("offline").mascotAnimationState(emotion: .happy) == .failed)
    }

    @Test func contactBirthdayFormatsDateAndCalculatesCompletedYears() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthday = try #require(calendar.date(from: DateComponents(year: 2000, month: 8, day: 20)))
        let beforeBirthday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 6)))
        let afterBirthday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 21)))

        #expect(ContactBirthday.storageString(from: birthday) == "2000/08/20")
        #expect(ContactBirthday.age(for: birthday, on: beforeBirthday, calendar: calendar) == 25)
        #expect(ContactBirthday.age(for: birthday, on: afterBirthday, calendar: calendar) == 26)
        #expect(ContactBirthday.date(from: "2000/08/20") == birthday)
    }

    @Test func defaultBirthdayStaysEmptyUntilUserChoosesOne() throws {
        let birthday = try #require(
            ContactInformationField.defaults.first {
                $0.label == "生日" || $0.label.caseInsensitiveCompare("Birthday") == .orderedSame
            }
        )

        #expect(birthday.value.isEmpty)
        #expect(ContactBirthday.date(from: birthday.value) == nil)
    }

    @Test func weeklyExpressionSignalUsesReviewAverageAndClampsProgress() {
        #expect(WeeklyExpressionSignal(averageScore: nil).displayScore == "--")
        #expect(WeeklyExpressionSignal(averageScore: 78.4).displayScore == "78")
        #expect(WeeklyExpressionSignal(averageScore: 120).progress == 1)
        #expect(WeeklyExpressionSignal(averageScore: -4).progress == 0)
    }

    @Test func publicUserIDUsesFourDigitMinimumWithoutTruncatingLargerIDs() {
        #expect(PublicUserIDFormatter.string(nil) == "0000")
        #expect(PublicUserIDFormatter.string(1) == "0001")
        #expect(PublicUserIDFormatter.string(9999) == "9999")
        #expect(PublicUserIDFormatter.string(10_000) == "10000")
        #expect(PublicUserIDFormatter.string(123_456) == "123456")
    }

    @Test func persistedPracticeRestoresScenarioConversationAndIdentity() {
        let practiceID = UUID()
        let record = PracticeRecord(
            id: practiceID,
            participantName: "Wren",
            modeTitle: "边界表达",
            durationSeconds: 42,
            userTranscript: "我需要一点自己的时间。",
            assistantTranscript: "我理解，我们晚点再聊。",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let session = record.scenarioConversationSession

        #expect(session.id == practiceID)
        #expect(session.messages.map(\.text) == ["我需要一点自己的时间。", "我理解，我们晚点再聊。"])
        #expect(session.messages.map(\.isUser) == [true, false])
    }

    @Test func realtimeVoiceURLUsesWebSocketSchemeAndGatewayPath() throws {
        let local = try RealtimeVoiceServiceConfiguration.websocketURL(from: "http://192.168.1.20:8000")
        let production = try RealtimeVoiceServiceConfiguration.websocketURL(from: "https://api.soulmark.app")

        #expect(local.absoluteString == "ws://192.168.1.20:8000/api/v1/realtime/scenario")
        #expect(production.absoluteString == "wss://api.soulmark.app/api/v1/realtime/scenario")
    }

    @Test func relationshipSignalUsesBackendFieldNames() throws {
        let signal = RelationshipSignalPayload(
            contactName: "Wren",
            trustDelta: 0.8,
            emotionalDepthDelta: 0.6,
            reciprocityDelta: 0.4,
            supportDelta: 0.7,
            confidence: 0.9,
            explanation: "坦诚交流得到了认真回应。"
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(signal))
                as? [String: Any]
        )

        #expect(object["contact_name"] as? String == "Wren")
        #expect(object["emotional_depth_delta"] as? Double == 0.6)
        #expect(object["support_delta"] as? Double == 0.7)
    }

    @Test func realtimeCaptureGateKeepsListeningDuringPlaybackAndAllowsBargeIn() {
        let gate = RealtimeCaptureGate()

        #expect(gate.canCapture)
        gate.setAssistantResponseActive(true)
        gate.beginPlaybackBuffer()
        #expect(gate.canCapture)
        #expect(!gate.shouldMuteVoiceProcessingInput)

        #expect(gate.beginBargeIn())
        #expect(gate.canCapture)
        #expect(!gate.shouldMuteVoiceProcessingInput)
    }

    @Test func realtimeCaptureGateStillHonorsManualMute() {
        let gate = RealtimeCaptureGate()
        gate.setManuallyMuted(true)
        gate.setAssistantResponseActive(true)
        #expect(!gate.canCapture)
        #expect(!gate.beginBargeIn())

        gate.setManuallyMuted(false)
        #expect(gate.canCapture)
    }

    @Test func realtimeCaptureGateProtectsQueuedAudioAndPlaybackTail() {
        let gate = RealtimeCaptureGate()

        gate.setAssistantResponseActive(true)
        gate.beginPlaybackBuffer()
        #expect(gate.setAssistantResponseActive(false) == nil)

        let generation = gate.finishPlaybackBuffer()
        #expect(generation != nil)
        #expect(gate.canCapture)

        #expect(gate.releaseTail(generation: generation!))
        #expect(gate.canCapture)
    }

    @Test func completedEventAfterBargeInDoesNotMuteUserAgain() {
        let gate = RealtimeCaptureGate()

        gate.setAssistantResponseActive(true)
        gate.beginPlaybackBuffer()
        #expect(gate.beginBargeIn())

        #expect(gate.setAssistantResponseActive(false) == nil)
        #expect(gate.canCapture)
    }

    @Test func realtimeCaptureGateFallsBackToFullDuplexWithoutMutedSpeechDetection() {
        let gate = RealtimeCaptureGate()

        gate.setAssistantPlaybackProtectionEnabled(false)
        gate.setAssistantResponseActive(true)
        gate.beginPlaybackBuffer()

        #expect(gate.canCapture)
        #expect(!gate.shouldMuteVoiceProcessingInput)
        #expect(!gate.beginBargeIn())
    }

    @Test func realtimeVoiceStartupDoesNotRequireMutedSpeechDetection() {
        #expect(!RealtimeVoiceStartupPolicy.shouldFail(
            voiceProcessingEnabled: true,
            mutedSpeechDetectionAvailable: false
        ))
        #expect(RealtimeVoiceStartupPolicy.shouldFail(
            voiceProcessingEnabled: false,
            mutedSpeechDetectionAvailable: true
        ))
    }

    @Test func relationshipFiltersReturnExpectedPeople() async throws {
        let people = RelationshipSampleData.people

        #expect(RelationshipFilter.all.filteredPeople(from: people).count == 14)
        #expect(RelationshipFilter.confidant.filteredPeople(from: people).map(\.name) == ["Wren", "Rhea"])
        #expect(RelationshipFilter.friend.filteredPeople(from: people).map(\.name) == ["Jasper", "Feel", "Owen"])
        #expect(RelationshipFilter.family.filteredPeople(from: people).map(\.name) == ["Lune", "Beau"])
        #expect(RelationshipFilter.collaborator.filteredPeople(from: people).map(\.name) == ["Hugo"])
        #expect(RelationshipFilter.classmate.filteredPeople(from: people).map(\.name) == ["Zora", "Silas"])
        #expect(RelationshipFilter.lightTie.filteredPeople(from: people).map(\.name) == ["Vivi", "Kai"])
        #expect(RelationshipFilter.distant.filteredPeople(from: people).map(\.name) == ["Torin", "Marduk"])
    }

    @Test func changingRelationshipCategoryMovesPersonBetweenFilters() async throws {
        var people = RelationshipSampleData.people
        let wrenID = try #require(people.first { $0.name == "Wren" }?.id)

        people.updateRelationship(for: wrenID, to: .family)

        #expect(RelationshipFilter.confidant.filteredPeople(from: people).map(\.name) == ["Rhea"])
        #expect(RelationshipFilter.family.filteredPeople(from: people).map(\.name) == ["Wren", "Lune", "Beau"])
    }

    @Test func addingPersonIncludesThemInMatchingFilter() async throws {
        var people = RelationshipSampleData.people
        let custom = RelationshipCategory.custom("闺蜜")

        people.addPerson(name: "Nia", note: "一起长大的朋友", category: custom)

        #expect(people.count == 15)
        #expect(custom.filteredPeople(from: people).map(\.name) == ["Nia"])
    }

    @Test func customRelationshipCanBeAssignedToExistingPerson() async throws {
        var people = RelationshipSampleData.people
        let custom = RelationshipCategory.custom("兄弟")
        let owenID = try #require(people.first { $0.name == "Owen" }?.id)

        people.updateRelationship(for: owenID, to: custom)

        #expect(RelationshipFilter.friend.filteredPeople(from: people).map(\.name) == ["Jasper", "Feel"])
        #expect(custom.filteredPeople(from: people).map(\.name) == ["Owen"])
    }

    @Test func deletingRelationshipRemovesMatchingPeopleFromGraph() async throws {
        var people = RelationshipSampleData.people

        people.deleteRelationship(.friend)

        #expect(RelationshipFilter.friend.filteredPeople(from: people).isEmpty)
        #expect(people.count == 11)
        #expect(!people.map(\.name).contains("Owen"))
    }

    @Test func deletingPersonRemovesOnlyThatPerson() async throws {
        var people = RelationshipSampleData.people
        let wrenID = try #require(people.first { $0.name == "Wren" }?.id)

        people.deletePerson(wrenID)

        #expect(people.count == 13)
        #expect(!people.map(\.name).contains("Wren"))
        #expect(people.map(\.name).contains("Rhea"))
    }

    @Test func updatingPersonPositionKeepsNodeInsideGraphBounds() async throws {
        var people = RelationshipSampleData.people
        let wrenID = try #require(people.first { $0.name == "Wren" }?.id)

        people.updatePosition(for: wrenID, to: CGPoint(x: -0.4, y: 1.4))

        let wren = try #require(people.first { $0.id == wrenID })
        #expect(wren.position.x == 0.10)
        #expect(wren.position.y == 0.92)
    }

    @Test func organizingPositionsCreatesReadableSpread() async throws {
        var people = RelationshipSampleData.people
        let originalPositions = people.map(\.position)

        people.organizePositions()

        #expect(people.map(\.position) != originalPositions)
        #expect(people.allSatisfy { person in
            person.position.x >= 0.12 &&
            person.position.x <= 0.88 &&
            person.position.y >= 0.12 &&
            person.position.y <= 0.90
        })
    }

    @Test func scenarioParticipantsCanComeFromRelationshipGraphAndCustomPersona() async throws {
        var participants = RelationshipSampleData.people.scenarioParticipants()

        participants.append(.custom(name: "面试官", note: "模拟压力面试", relationshipLabel: "自定义"))

        #expect(participants.count == RelationshipSampleData.people.count + 1)
        #expect(participants.prefix(4).map(\.name) == ["Wren", "Rhea", "Owen", "Feel"])
        #expect(participants.last?.isCustom == true)
    }

    @Test func scenarioOnlyCustomParticipantsCanBeDeleted() async throws {
        var participants = RelationshipSampleData.people.scenarioParticipants()
        let relationshipParticipantID = try #require(participants.first?.id)
        let customParticipant = ScenarioParticipant.custom(name: "面试官", note: "模拟压力面试", relationshipLabel: "自定义")

        participants.append(customParticipant)
        participants.deleteCustomParticipant(customParticipant.id)
        participants.deleteCustomParticipant(relationshipParticipantID)

        #expect(!participants.map(\.id).contains(customParticipant.id))
        #expect(participants.map(\.id).contains(relationshipParticipantID))
    }

    @Test func customScenarioModeCanBeAddedToPickerOptions() async throws {
        var modes = ScenarioMode.defaultModes

        modes.addCustomMode(title: "和室友沟通", guidance: "先讲具体事情，再提出可执行的约定。")

        #expect(modes.count == 5)
        #expect(modes.last?.title == "和室友沟通")
        #expect(modes.last?.guidance == "先讲具体事情，再提出可执行的约定。")
        #expect(modes.last?.isCustom == true)
    }

    @Test func scenarioParticipantPolicyKeepsEarlierPeopleWhenNewestSortsFirst() {
        let unlockedIDs = ScenarioParticipantAccessPolicy.reconciledUnlockedIDs(
            existing: ["wren", "rhea"],
            participantIDs: ["new-person", "wren", "rhea"]
        )

        #expect(unlockedIDs == ["wren", "rhea"])
        #expect(!unlockedIDs.contains("new-person"))
    }

    @Test func scenarioParticipantPolicyStopsNewPeopleAtTwo() {
        #expect(ScenarioParticipantAccessPolicy.canAddParticipant(currentCount: 1))
        #expect(!ScenarioParticipantAccessPolicy.canAddParticipant(currentCount: 2))
    }

    @Test func recordingTimerStartsAtZeroAndTicksUp() async throws {
        var timer = RecordingTimer()

        #expect(timer.displayText == "00:00")

        timer.start()
        timer.tick()
        timer.tick()

        #expect(timer.displayText == "00:02")
    }

    @Test func recordingTimerCancelAndFinishResetToZero() async throws {
        var timer = RecordingTimer()

        timer.start()
        timer.tick()
        timer.tick()
        timer.cancel()

        #expect(timer.displayText == "00:00")
        #expect(timer.isRunning == false)

        timer.start()
        timer.tick()
        timer.tick()
        timer.tick()

        let submittedSeconds = timer.finish()

        #expect(submittedSeconds == 3)
        #expect(timer.displayText == "00:00")
        #expect(timer.isRunning == false)
    }

    @Test func conversationReviewRecordCreatesScoreReasonAndAdvice() async throws {
        let record = ConversationReviewRecord.make(
            title: "微信聊天复盘",
            source: .wechat,
            transcript: "我昨天没有及时回复你，是因为我在赶项目。下次我会提前告诉你。"
        )

        #expect(record.score >= 60)
        #expect(!record.reason.isEmpty)
        #expect(!record.advice.isEmpty)
        #expect(record.source == .wechat)
    }

    @Test func conversationReviewRecordCanBeFilteredBySourceAndKeyword() async throws {
        let record = ConversationReviewRecord.make(
            title: "和 Wren 的复盘",
            source: .scenario,
            transcript: "我希望下次可以提前沟通。"
        )

        #expect(record.matches(source: .scenario, query: "Wren"))
        #expect(record.matches(source: .scenario, query: "提前"))
        #expect(!record.matches(source: .wechat, query: "Wren"))
        #expect(!record.matches(source: .scenario, query: "面试"))
    }

    @Test func scenarioHistorySearchMatchesParticipantAndMessageText() async throws {
        let session = ScenarioConversationSession(
            participantID: "wren",
            participantName: "Wren",
            date: Date(),
            messages: [
                ScenarioMessage(speaker: "你", text: "我想练习一次道歉。", isUser: true),
                ScenarioMessage(speaker: "Wren", text: "可以，先说你对这件事的理解。", isUser: false)
            ]
        )

        #expect(session.matches("Wren"))
        #expect(session.matches("道歉"))
        #expect(session.matches("理解"))
        #expect(!session.matches("面试"))
    }

    @Test func freeRelationshipPolicyStopsAtFivePeople() {
        #expect(FreeRelationshipPolicy.canAddPerson(currentCount: 0))
        #expect(FreeRelationshipPolicy.canAddPerson(currentCount: 4))
        #expect(!FreeRelationshipPolicy.canAddPerson(currentCount: 5))
        #expect(!FreeRelationshipPolicy.canAddPerson(currentCount: 6))
    }

    @Test func dailyQuoteCatalogContainsFiveHundredSourcedQuotes() throws {
        let quotes = try DailyQuoteCatalog.load()

        #expect(quotes.count == 500)
        #expect(quotes.allSatisfy {
            !$0.chinese.isEmpty && !$0.english.isEmpty && !$0.source.isEmpty
        })
    }

    @Test func dailyQuoteIsStableForOneUserAndLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = Date(timeIntervalSince1970: 1_786_080_000)
        let evening = morning.addingTimeInterval(60 * 60 * 12)
        let userID = UUID(uuidString: "B973B3E4-2D43-4C17-8AAE-93024A6C91E5")!

        let morningQuote = DailyQuoteCatalog.quote(userID: userID, date: morning, calendar: calendar)
        let eveningQuote = DailyQuoteCatalog.quote(userID: userID, date: evening, calendar: calendar)

        #expect(morningQuote == eveningQuote)
        #expect(morningQuote.shareText.contains("SoulMark"))
        #expect(morningQuote.shareText.contains(morningQuote.source))
        #expect(!morningQuote.chinese.isEmpty)
        #expect(!morningQuote.english.isEmpty)
    }

    @Test func dailyQuoteIndexUsesUserAndDateDeterministically() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = Date(timeIntervalSince1970: 1_786_080_000)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let firstUser = UUID(uuidString: "B973B3E4-2D43-4C17-8AAE-93024A6C91E5")!
        let secondUser = UUID(uuidString: "2A28D741-72E5-47E4-8E51-DC18E489906A")!

        let firstIndex = DailyQuoteCatalog.index(
            userID: firstUser,
            date: firstDay,
            calendar: calendar,
            count: 500
        )

        #expect(firstIndex == DailyQuoteCatalog.index(
            userID: firstUser,
            date: firstDay,
            calendar: calendar,
            count: 500
        ))
        #expect(firstIndex != DailyQuoteCatalog.index(
            userID: firstUser,
            date: nextDay,
            calendar: calendar,
            count: 500
        ))
        #expect(firstIndex != DailyQuoteCatalog.index(
            userID: secondUser,
            date: firstDay,
            calendar: calendar,
            count: 500
        ))
    }

    @MainActor
    @Test func dailyQuoteSharePayloadProvidesWechatCompatibleImageAndText() throws {
        let quote = DailySoulQuote(
            id: 1,
            chinese: "测试中文",
            english: "Test quote",
            source: "Test Source"
        )

        let payload = try DailyQuoteSharePayload.make(quote: quote)

        #expect(payload.items.contains { $0 is UIImage })
        #expect(payload.items.contains { $0 is NSString })
        #expect(payload.previewImage.cgImage?.width == 1080)
        #expect(payload.previewImage.cgImage?.height == 1350)
    }

    @Test func remoteContactMapsAvatarURLToRelationshipPerson() throws {
        let json = """
        {
          "id": "B973B3E4-2D43-4C17-8AAE-93024A6C91E5",
          "name": "Wren",
          "relationship_label": "friend",
          "notes": "Friend",
          "strength": 80,
          "event_count": 10,
          "intimacy_calculated": true,
          "position_x": 0.4,
          "position_y": 0.6,
          "symbol": "person.fill",
          "memory": "Memory",
          "avatar_url": "/media/avatars/wren.jpg"
        }
        """

        let contact = try JSONDecoder().decode(RemoteContact.self, from: Data(json.utf8))

        #expect(contact.relationshipPerson.avatarURL == "/media/avatars/wren.jpg")
        #expect(contact.relationshipPerson.eventCount == 10)
        #expect(contact.relationshipPerson.intimacyCalculated)
    }

    @Test func backendMediaURLResolvesRelativeAndAbsoluteAddresses() throws {
        let relative = try #require(BackendURLResolver.mediaURL(
            "/media/avatars/wren.jpg",
            baseURL: "http://192.168.110.109:8000"
        ))
        let absolute = try #require(BackendURLResolver.mediaURL(
            "https://cdn.example.com/wren.jpg",
            baseURL: "http://192.168.110.109:8000"
        ))

        #expect(relative.absoluteString == "http://192.168.110.109:8000/media/avatars/wren.jpg")
        #expect(absolute.absoluteString == "https://cdn.example.com/wren.jpg")
    }

    @Test func contactAvatarProcessorProducesBoundedJPEG() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1_600, height: 900)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_600, height: 900))
        }
        let source = try #require(image.pngData())

        let prepared = try ContactAvatarImageProcessor.prepare(source)
        let decoded = try #require(UIImage(data: prepared))

        #expect(decoded.size.width == decoded.size.height)
        #expect(decoded.size.width <= 1_024)
    }

    @Test func emptyScenarioParticipantListUsesSoulFallback() {
        let participants = [ScenarioParticipant]().withSoulFallback()

        #expect(participants.count == 1)
        #expect(participants.first?.name == "Soul")
        #expect(participants.first?.isCustom == false)
    }

    @Test func relationshipLabelsFaceAwayFromMapCenter() {
        let center = CGPoint(x: 0.5, y: 0.5)
        let right = RelationshipLabelPlacement.layout(node: CGPoint(x: 0.8, y: 0.5), center: center)
        let left = RelationshipLabelPlacement.layout(node: CGPoint(x: 0.2, y: 0.5), center: center)

        #expect(right.horizontalDirection == 1)
        #expect(left.horizontalDirection == -1)
    }

    @Test func relationshipOwnerNameUsesNicknameWithLocalizedFallback() {
        #expect(RelationshipOwnerDisplayName.resolve("  小雨  ", language: "zh") == "小雨")
        #expect(RelationshipOwnerDisplayName.resolve("", language: "zh") == "我")
        #expect(RelationshipOwnerDisplayName.resolve("   ", language: "en") == "Me")
    }

    @Test func achievementsUnlockFromCurrentSessionProgress() {
        let complete = AchievementProgress(
            peopleCount: 5,
            practiceCount: 3,
            reviewCount: 1,
            relationshipCategoryCount: 3
        )
        let empty = AchievementProgress(
            peopleCount: 0,
            practiceCount: 0,
            reviewCount: 0,
            relationshipCategoryCount: 0
        )

        #expect(SoulAchievement.all(progress: complete).allSatisfy { $0.isUnlocked })
        #expect(SoulAchievement.all(progress: empty).allSatisfy { !$0.isUnlocked })
    }

}
