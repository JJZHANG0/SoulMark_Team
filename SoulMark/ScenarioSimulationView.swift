//
//  ScenarioSimulationView.swift
//  SoulMark
//

import SwiftUI

private enum ScenarioPendingSheet {
    case addParticipant
    case addMode
    case upgrade
}

struct ScenarioSimulationView: View {
    @EnvironmentObject private var session: AppSession
    let relationshipPeople: [RelationshipPerson]
    let onPracticeSubmitted: (Int, String, String, String, [ScenarioMessage]) -> Void
    let onPracticeDeleted: () -> Void

    @State private var participants: [ScenarioParticipant]
    @State private var unlockedParticipantIDs: [ScenarioParticipant.ID]
    @State private var selectedParticipantID: ScenarioParticipant.ID?
    @State private var isAddingParticipant = false
    @State private var isAddingMode = false
    @State private var isShowingModePicker = false
    @State private var isShowingUpgradePrompt = false
    @State private var pendingSheet: ScenarioPendingSheet?
    @State private var modes = ScenarioMode.defaultModes
    @State private var selectedModeID = ScenarioMode.defaultModes[0].id
    @State private var draftMessage = ""
    @State private var conversation: [ScenarioMessage] = []
    @State private var conversationHistory: [ScenarioConversationSession] = []
    @State private var isShowingHistory = false
    @State private var historyErrorMessage: String?
    @State private var isShowingParticipantPicker = false
    @State private var conversationScrollTarget = UUID()
    @State private var isShowingGuidance = false
    @StateObject private var voiceCall = RealtimeVoiceCallManager()
    @AppStorage("soulMarkBackendURL") private var backendURL = RealtimeVoiceServiceConfiguration.defaultBackendURL
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkGenderTheme") private var genderTheme = "male"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"

    init(
        relationshipPeople: [RelationshipPerson],
        focusedPersonID: RelationshipPerson.ID? = nil,
        onPracticeSubmitted: @escaping (Int, String, String, String, [ScenarioMessage]) -> Void = { _, _, _, _, _ in },
        onPracticeDeleted: @escaping () -> Void = {}
    ) {
        self.relationshipPeople = relationshipPeople
        self.onPracticeSubmitted = onPracticeSubmitted
        self.onPracticeDeleted = onPracticeDeleted
        let initialParticipants = relationshipPeople.scenarioParticipants().withSoulFallback()
        _participants = State(initialValue: initialParticipants)
        let earliestRelationshipIDs = relationshipPeople
            .prefix(ScenarioParticipantAccessPolicy.freeLimit)
            .map { $0.id.uuidString }
        let initialUnlockedIDs = ScenarioParticipantAccessPolicy.reconciledUnlockedIDs(
            existing: earliestRelationshipIDs,
            participantIDs: initialParticipants.map(\.id)
        )
        _unlockedParticipantIDs = State(initialValue: initialUnlockedIDs)
        let focusedID = focusedPersonID?.uuidString
        let selectedID = focusedID.map { initialUnlockedIDs.contains($0) } == true
            ? focusedID
            : initialParticipants.first?.id
        _selectedParticipantID = State(initialValue: selectedID)
    }

    private var selectedParticipant: ScenarioParticipant {
        participants.first { $0.id == selectedParticipantID } ?? participants[0]
    }

    private var selectedMode: ScenarioMode {
        modes.first { $0.id == selectedModeID } ?? modes[0]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SoulBackground()

            VStack(spacing: 0) {
                ScenarioHeader(
                    onShowHistory: {
                        Task {
                            await loadConversationHistory()
                            isShowingHistory = true
                        }
                    },
                    onNewConversation: startNewConversation,
                    onChangeParticipant: {
                        isShowingParticipantPicker = true
                    },
                    onShowGuidance: {
                        isShowingGuidance = true
                    }
                )

                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    ScenarioAnimatedMascot(
                        height: voiceCall.phase.isActive || !conversation.isEmpty ? 175 : 238,
                        state: voiceCall.phase.mascotAnimationState(
                            emotion: voiceCall.assistantEmotion
                        )
                    )
                    .animation(.easeInOut(duration: 0.24), value: voiceCall.phase.isActive)

                    VStack(spacing: 5) {
                        Text(localizedText("准备与 AI 对话", "READY TO TALK WITH AI"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(SoulTheme.energy)

                        Text(localizedText(
                            "模拟 \(selectedParticipant.name) · \(selectedMode.displayTitle)",
                            "As \(selectedParticipant.name) · \(selectedMode.displayTitle)"
                        ))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                    }

                    if !conversation.isEmpty {
                        MinimalScenarioTranscript(messages: conversation, scrollTarget: conversationScrollTarget)
                            .frame(height: 110)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 12)

                    voiceControl
                        .padding(.bottom, 118)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            ScenarioModeQuickSwitch(mode: selectedMode) {
                isShowingModePicker = true
            }
            .padding(.top, 126)
            .padding(.trailing, 14)
        }
        .onAppear {
            isShowingModePicker = true
        }
        .onChange(of: relationshipPeople) { _, _ in
            syncRelationshipParticipants()
        }
        .onChange(of: voiceCall.latestTranscript) { _, event in
            guard let event else { return }
            conversation.append(
                ScenarioMessage(
                    speaker: event.role == .user ? localizedText("你", "You") : selectedParticipant.name,
                    text: event.text,
                    isUser: event.role == .user
                )
            )
            conversationScrollTarget = UUID()
        }
        .onChange(of: selectedModeID) { _, _ in
            endVoiceCall(reportPractice: false)
        }
        .onDisappear {
            endVoiceCall(reportPractice: false)
        }
        .sheet(isPresented: $isAddingParticipant, onDismiss: presentPendingSheetIfNeeded) {
            AddScenarioParticipantSheet { name, note, relationshipLabel in
                guard ScenarioParticipantAccessPolicy.canAddParticipant(
                    currentCount: participants.count
                ) else {
                    pendingSheet = .upgrade
                    return
                }
                let participant = ScenarioParticipant.custom(
                    name: name,
                    note: note,
                    relationshipLabel: relationshipLabel
                )
                participants.append(participant)
                unlockedParticipantIDs = ScenarioParticipantAccessPolicy.reconciledUnlockedIDs(
                    existing: unlockedParticipantIDs,
                    participantIDs: participants.map(\.id)
                )
                switchToParticipant(participant)
            }
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingMode, onDismiss: presentPendingSheetIfNeeded) {
            AddScenarioModeSheet { title, guidance in
                modes.addCustomMode(title: title, guidance: guidance)
                selectedModeID = modes.last?.id ?? selectedModeID
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
        .sheet(
            isPresented: $isShowingParticipantPicker,
            onDismiss: presentPendingSheetIfNeeded
        ) {
            ScenarioParticipantPickerSheet(
                participants: participants,
                selectedID: selectedParticipantID,
                isUnlocked: isParticipantUnlocked,
                onSelect: { participant in
                    if isParticipantUnlocked(participant) {
                        switchToParticipant(participant)
                        isShowingParticipantPicker = false
                    } else {
                        pendingSheet = .upgrade
                        isShowingParticipantPicker = false
                    }
                },
                onAdd: {
                    pendingSheet = ScenarioParticipantAccessPolicy.canAddParticipant(
                        currentCount: participants.count
                    ) ? .addParticipant : .upgrade
                    isShowingParticipantPicker = false
                },
                onDeleteCustom: deleteCustomParticipant
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingHistory, onDismiss: presentPendingSheetIfNeeded) {
            ScenarioHistorySheet(
                sessions: conversationSessions,
                currentParticipantName: selectedParticipant.name,
                onContinue: continueConversation,
                onDelete: deleteConversationSession
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingGuidance) {
            ScenarioGuidanceSheet(mode: selectedMode)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingModePicker, onDismiss: presentPendingSheetIfNeeded) {
            ScenarioModePickerSheet(
                modes: modes,
                selectedModeID: selectedModeID,
                onSelect: { mode in
                    selectedModeID = mode.id
                    isShowingModePicker = false
                },
                onAddMode: {
                    pendingSheet = .addMode
                    isShowingModePicker = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingUpgradePrompt) {
            ScenarioParticipantUpgradeSheet()
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
        }
        .alert(
            localizedText("历史记录操作失败", "History Update Failed"),
            isPresented: Binding(
                get: { historyErrorMessage != nil },
                set: { if !$0 { historyErrorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { historyErrorMessage = nil }
        } message: {
            Text(historyErrorMessage ?? "")
        }
    }

    private var voiceControl: some View {
        VStack(spacing: 11) {
            if voiceCall.phase.isActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(voiceCall.phase == .speaking ? SoulTheme.energy : SoulTheme.success)
                        .frame(width: 8, height: 8)

                    Text(voiceCall.phase.title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                }

                Text(voiceCall.durationText)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SoulTheme.primaryText)

                if !voiceCall.assistantDraft.isEmpty {
                    Text(voiceCall.assistantDraft)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }

                HStack(spacing: 24) {
                    Button {
                        voiceCall.toggleMute()
                    } label: {
                        Image(systemName: voiceCall.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(SoulTheme.primaryText)
                            .frame(width: 52, height: 52)
                            .background(SoulTheme.cardFill, in: Circle())
                            .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedText("静音", "Mute"))

                    Button {
                        endVoiceCall()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .frame(width: 58, height: 58)
                            .background(SoulTheme.danger, in: Circle())
                            .shadow(color: SoulTheme.danger.opacity(0.28), radius: 12, x: 0, y: 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedText("结束通话", "End call"))
                }
            } else {
                Button {
                    Task {
                        await voiceCall.start(
                            participant: selectedParticipant,
                            mode: selectedMode,
                            backendURL: backendURL,
                            language: language
                        )
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: voiceCall.phase == .connecting ? "ellipsis" : "phone.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 72, height: 72)
                            .background(SoulTheme.accent, in: Circle())
                            .shadow(color: SoulTheme.accent.opacity(0.30), radius: 13, x: 0, y: 8)

                        Text(localizedText("呼叫 Soul", "Call Soul"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(SoulTheme.primaryText)
                    }
                }
                .buttonStyle(.plain)

                if let error = voiceCall.errorMessage {
                    Button {
                        voiceCall.clearError()
                    } label: {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(SoulTheme.danger)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minHeight: 108)
    }

    private var partnerSelector: some View {
        Button {
            isShowingParticipantPicker = true
        } label: {
            HStack(spacing: 13) {
                ScenarioAvatar(participant: selectedParticipant, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("当前模拟对象", "Current Partner"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.energy)

                    HStack(spacing: 7) {
                        Text(selectedParticipant.name)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(primaryTextColor)

                        Text(selectedParticipant.relationshipLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                Spacer()

                Image(systemName: "person.2.badge.gearshape.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SoulTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(14)
            .background(SoulGlassCardBackground())
        }
        .buttonStyle(.plain)
    }

    private var conversationSessions: [ScenarioConversationSession] {
        conversationHistory
    }

    private func sendMessage() {
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        conversation.append(ScenarioMessage(speaker: localizedText("你", "You"), text: text, isUser: true))
        conversation.append(
            ScenarioMessage(
                speaker: selectedParticipant.name,
                text: localizedText("我听到了。你希望我接下来怎么回应这件事？", "I hear you. How would you like me to respond to this next?"),
                isUser: false
            )
        )
        draftMessage = ""
        conversationScrollTarget = UUID()
    }

    private func endVoiceCall(reportPractice: Bool = true) {
        let seconds = voiceCall.end()
        if reportPractice, seconds > 0 {
            onPracticeSubmitted(
                seconds,
                selectedParticipant.name,
                selectedMode.displayTitle,
                selectedMode.displayGuidance,
                conversation
            )
        }
    }

    private func deleteCustomParticipant(_ participant: ScenarioParticipant) {
        participants.deleteCustomParticipant(participant.id)
        participants = participants.withSoulFallback()
        unlockedParticipantIDs = ScenarioParticipantAccessPolicy.reconciledUnlockedIDs(
            existing: unlockedParticipantIDs,
            participantIDs: participants.map(\.id)
        )

        if selectedParticipantID == participant.id {
            selectedParticipantID = participants.first?.id
            resetConversation()
        }
    }

    private func syncRelationshipParticipants() {
        let customParticipants = participants.filter(\.isCustom)
        participants = (relationshipPeople.scenarioParticipants() + customParticipants).withSoulFallback()
        unlockedParticipantIDs = ScenarioParticipantAccessPolicy.reconciledUnlockedIDs(
            existing: unlockedParticipantIDs,
            participantIDs: participants.map(\.id)
        )

        if let selectedParticipantID,
           unlockedParticipantIDs.contains(selectedParticipantID) {
            return
        } else {
            selectedParticipantID = participants.first?.id
            resetConversation()
        }
    }

    private func isParticipantUnlocked(_ participant: ScenarioParticipant) -> Bool {
        unlockedParticipantIDs.contains(participant.id)
    }

    private func presentPendingSheetIfNeeded() {
        guard let pendingSheet else { return }
        self.pendingSheet = nil

        switch pendingSheet {
        case .addParticipant:
            isAddingParticipant = true
        case .addMode:
            isAddingMode = true
        case .upgrade:
            isShowingUpgradePrompt = true
        }
    }

    private func deleteConversationSession(_ session: ScenarioConversationSession) {
        Task {
            do {
                try await self.session.deletePractice(session.id)
                conversationHistory.removeAll { $0.id == session.id }
                onPracticeDeleted()
            } catch {
                historyErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadConversationHistory() async {
        guard let records = await session.loadPractices() else {
            historyErrorMessage = localizedText("暂时无法读取历史对话。", "Unable to load conversation history right now.")
            return
        }
        conversationHistory = records.map(\.scenarioConversationSession)
    }

    private func switchToParticipant(_ participant: ScenarioParticipant) {
        guard isParticipantUnlocked(participant) else {
            pendingSheet = .upgrade
            return
        }
        guard selectedParticipantID != participant.id else { return }
        selectedParticipantID = participant.id
        resetConversation()
    }

    private func startNewConversation() {
        resetConversation()
    }

    private func continueConversation(_ session: ScenarioConversationSession) {
        let targetParticipant: ScenarioParticipant?
        if let participantID = session.participantID,
           let participant = participants.first(where: { $0.id == participantID }) {
            targetParticipant = participant
        } else if let participant = participants.first(where: { $0.name == session.participantName }) {
            targetParticipant = participant
        } else {
            targetParticipant = nil
        }

        if let targetParticipant, !isParticipantUnlocked(targetParticipant) {
            pendingSheet = .upgrade
            isShowingHistory = false
            return
        }

        if let targetParticipant {
            selectedParticipantID = targetParticipant.id
        }
        conversation = session.messages
        draftMessage = ""
        endVoiceCall(reportPractice: false)
        isShowingHistory = false
        conversationScrollTarget = UUID()
    }

    private func resetConversation() {
        conversation = []
        draftMessage = ""
        endVoiceCall(reportPractice: false)
        conversationScrollTarget = UUID()
    }

}

private struct ScenarioAnimatedMascot: View {
    private static let sourceAspectRatio: CGFloat = 683 / 1536

    let height: CGFloat
    let state: ScenarioMascotAnimationState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let motion = ScenarioMascotMotion(state: state, phase: phase)

            ZStack {
                Image("SoulMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    .shadow(color: SoulTheme.energy.opacity(0.28), radius: 9, x: 0, y: 2)

                ScenarioVisorLight(
                    state: state,
                    phase: phase,
                    reduceMotion: reduceMotion
                )
                .frame(
                    width: height * Self.sourceAspectRatio,
                    height: height
                )
            }
            .frame(
                width: height * Self.sourceAspectRatio,
                height: height
            )
            .scaleEffect(motion.scale)
            .rotationEffect(.degrees(motion.rotation))
            .offset(x: motion.x, y: motion.y)
            .animation(.easeInOut(duration: 0.32), value: state)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct ScenarioMascotMotion {
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat

    init(state: ScenarioMascotAnimationState, phase: TimeInterval) {
        let slow = CGFloat(sin(phase * 1.35))
        let speech = CGFloat(sin(phase * 3.4))

        switch state {
        case .idle:
            x = 0
            y = slow * 2
            rotation = Double(slow) * 0.25
            scale = 1 + slow * 0.003
        case .listening:
            x = -1
            y = 1 + slow * 0.7
            rotation = -0.8 + Double(slow) * 0.18
            scale = 1.002
        case .thinking:
            x = slow * 0.8
            y = 0
            rotation = Double(slow) * 0.45
            scale = 1
        case .speaking(let emotion):
            switch emotion {
            case .calm:
                x = 0
                y = speech * 1.2
                rotation = Double(speech) * 0.3
                scale = 1 + speech * 0.002
            case .happy:
                x = 0
                y = -1.4 + speech * 1.5
                rotation = Double(speech) * 0.55
                scale = 1.005 + speech * 0.002
            case .caring:
                x = -0.6
                y = slow * 0.9
                rotation = -1 + Double(slow) * 0.22
                scale = 1.002
            case .serious:
                x = 0
                y = speech * 0.4
                rotation = Double(speech) * 0.08
                scale = 1
            case .encouraging:
                x = 0
                y = -0.8 + speech * 1.3
                rotation = Double(speech) * 0.35
                scale = 1.003 + speech * 0.002
            }
        case .failed:
            x = 0
            y = 1
            rotation = 0
            scale = 1
        }
    }
}

private struct ScenarioVisorLight: View {
    let state: ScenarioMascotAnimationState
    let phase: TimeInterval
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let style = ScenarioVisorStyle(state: state, phase: phase, reduceMotion: reduceMotion)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [style.color.opacity(0.45), style.color, style.color.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.height * style.width, height: max(2, proxy.size.height * 0.004))
                .scaleEffect(x: style.scaleX, y: style.scaleY)
                .opacity(style.opacity)
                .shadow(color: style.color.opacity(0.82), radius: style.glowRadius)
                .rotationEffect(.degrees(-1.2))
                .position(
                    x: proxy.size.width * 0.638 + style.scanOffset,
                    y: proxy.size.height * 0.159
                )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScenarioVisorStyle {
    let color: Color
    let width: CGFloat
    let opacity: Double
    let scaleX: CGFloat
    let scaleY: CGFloat
    let glowRadius: CGFloat
    let scanOffset: CGFloat

    init(state: ScenarioMascotAnimationState, phase: TimeInterval, reduceMotion: Bool) {
        let slow = reduceMotion ? 0 : CGFloat(sin(phase * 1.7))
        let speech = reduceMotion ? 0 : CGFloat(sin(phase * 4.2))
        let scan = reduceMotion ? 0 : CGFloat(sin(phase * 2.2))

        switch state {
        case .idle:
            color = SoulTheme.energy
            width = 0.105
            opacity = 0.72 + Double(slow) * 0.12
            scaleX = 1
            scaleY = 1
            glowRadius = 5
            scanOffset = 0
        case .listening:
            color = SoulTheme.energy
            width = 0.092
            opacity = 0.9
            scaleX = 1 + slow * 0.025
            scaleY = 0.78
            glowRadius = 6
            scanOffset = scan * 0.8
        case .thinking:
            color = SoulTheme.accent
            width = 0.07
            opacity = 0.88
            scaleX = 1
            scaleY = 0.8
            glowRadius = 7
            scanOffset = scan * 4
        case .speaking(let emotion):
            switch emotion {
            case .calm:
                color = SoulTheme.energy
                width = 0.105
                opacity = 0.9 + Double(speech) * 0.08
                scaleX = 1 + speech * 0.025
                scaleY = 1
                glowRadius = 7
                scanOffset = 0
            case .happy:
                color = Color(red: 0.20, green: 0.92, blue: 0.64)
                width = 0.116
                opacity = 0.96
                scaleX = 1 + speech * 0.04
                scaleY = 1.22 + speech * 0.08
                glowRadius = 9
                scanOffset = 0
            case .caring:
                color = Color(red: 0.28, green: 0.82, blue: 0.78)
                width = 0.1
                opacity = 0.82 + Double(slow) * 0.1
                scaleX = 1 + slow * 0.018
                scaleY = 0.92
                glowRadius = 7
                scanOffset = 0
            case .serious:
                color = SoulTheme.accent
                width = 0.085
                opacity = 0.8
                scaleX = 1
                scaleY = 0.62
                glowRadius = 4
                scanOffset = 0
            case .encouraging:
                color = SoulTheme.energy
                width = 0.112
                opacity = 0.92 + Double(speech) * 0.07
                scaleX = 1 + speech * 0.035
                scaleY = 1.08
                glowRadius = 9
                scanOffset = 0
            }
        case .failed:
            color = SoulTheme.warning
            width = 0.078
            opacity = 0.58
            scaleX = 1
            scaleY = 0.7
            glowRadius = 3
            scanOffset = 0
        }
    }
}

private struct ScenarioHeader: View {
    let onShowHistory: () -> Void
    let onNewConversation: () -> Void
    let onChangeParticipant: () -> Void
    let onShowGuidance: () -> Void

    var body: some View {
        SoulPageHeader(
            eyebrow: "Practice / 03",
            title: localizedText("情景模拟", "Simulation"),
            subtitle: localizedText("先练习，再走进真实对话。", "Practice first, then step into the real conversation.")
        ) {
            HStack(spacing: 8) {
                SoulIconButton(systemImage: "clock.arrow.circlepath", action: onShowHistory)
                SoulIconButton(systemImage: "plus.message.fill", action: onNewConversation)

                Menu {
                    Button(action: onChangeParticipant) {
                        Label(localizedText("切换对象", "Switch Partner"), systemImage: "person.2.fill")
                    }

                    Button(action: onShowGuidance) {
                        Label(localizedText("完整指导", "Full Guidance"), systemImage: "lightbulb.max.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .background(SoulTheme.cardFill, in: Circle())
                        .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

private struct ScenarioModeQuickSwitch: View {
    let mode: ScenarioMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 15, weight: .bold))

                Text(mode.displayTitle)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
            }
            .foregroundStyle(SoulTheme.accent)
            .padding(.vertical, 10)
            .frame(width: 64)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(
                    cornerRadius: SoulTheme.controlCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: SoulTheme.controlCornerRadius,
                    style: .continuous
                )
                .stroke(SoulTheme.accent.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: SoulTheme.accent.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedText("切换模拟模式", "Switch simulation mode"))
    }
}

private struct MinimalScenarioTranscript: View {
    let messages: [ScenarioMessage]
    let scrollTarget: UUID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        HStack {
                            if message.isUser { Spacer(minLength: 44) }

                            Text(message.text)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(message.isUser ? Color.white : SoulTheme.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    message.isUser ? SoulTheme.accent : SoulTheme.cardFill,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )

                            if !message.isUser { Spacer(minLength: 44) }
                        }
                    }

                    Color.clear.frame(height: 1).id(scrollTarget)
                }
                .padding(10)
            }
            .background(SoulGlassCardBackground())
            .onChange(of: scrollTarget) { _, newValue in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
        }
    }
}

private struct ScenarioStage: View {
    let participant: ScenarioParticipant

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SoulVisorPanelBackground()

            VStack(alignment: .leading, spacing: 10) {
                SoulStatusPill(text: localizedText("模拟信号已连接", "SIMULATION LINKED"), systemImage: "wave.3.right.circle.fill")

                Spacer()

                Text(localizedText("对话目标", "CONVERSATION TARGET"))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))

                Text(participant.name)
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(localizedText("Soul 正在分析语气与表达节奏", "Soul is reading tone and expression rhythm"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .frame(maxWidth: 170, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(18)

            ScenarioCharacterIllustration()
                .offset(x: 8, y: 24)
        }
        .frame(height: 250)
        .clipped()
    }
}

private struct ScenarioCharacterIllustration: View {
    var body: some View {
        SoulMascotFigure(height: 245)
    }
}

private struct ScenarioParticipantRail: View {
    let participants: [ScenarioParticipant]
    let selectedID: ScenarioParticipant.ID?
    let onSelect: (ScenarioParticipant) -> Void
    let onAdd: () -> Void
    let onDeleteCustom: (ScenarioParticipant) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(participants) { participant in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            onSelect(participant)
                        } label: {
                            VStack(spacing: 5) {
                                ScenarioAvatar(participant: participant, size: 44)

                                Text(participant.name)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(primaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.80)
                            }
                            .frame(width: 68, height: 64)
                            .background(
                                selectedID == participant.id
                                ? SoulTheme.accentSoft
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selectedID == participant.id ? participant.color.opacity(0.56) : .clear, lineWidth: 1.4)
                            )
                        }
                        .buttonStyle(.plain)

                        if participant.isCustom {
                            Button {
                                onDeleteCustom(participant)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(SoulTheme.danger, SoulTheme.cardFill)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: 2, y: -4)
                        }
                    }
                }

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(SoulTheme.accent)
                        .frame(width: 52, height: 52)
                        .background(SoulTheme.cardFill, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 76, height: 236)
    }
}

private struct ScenarioParticipantPickerSheet: View {
    let participants: [ScenarioParticipant]
    let selectedID: ScenarioParticipant.ID?
    let isUnlocked: (ScenarioParticipant) -> Bool
    let onSelect: (ScenarioParticipant) -> Void
    let onAdd: () -> Void
    let onDeleteCustom: (ScenarioParticipant) -> Void

    private var groupedParticipants: [(String, [ScenarioParticipant])] {
        Dictionary(grouping: participants, by: \.relationshipLabel)
            .map { key, value in (key, value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(SoulTheme.accent)

                        Text(
                            localizedText(
                                "免费版可使用前 2 位对象，更多对象需要升级。",
                                "The first 2 partners are included; more require an upgrade."
                            )
                        )
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        SoulTheme.accentSoft,
                        in: RoundedRectangle(
                            cornerRadius: SoulTheme.compactCornerRadius,
                            style: .continuous
                        )
                    )

                    ForEach(groupedParticipants, id: \.0) { groupName, people in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(groupName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(secondaryTextColor)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 10)], spacing: 10) {
                                ForEach(people) { participant in
                                    ZStack(alignment: .topTrailing) {
                                        Button {
                                            onSelect(participant)
                                        } label: {
                                            VStack(spacing: 7) {
                                                ZStack(alignment: .bottomTrailing) {
                                                    ScenarioAvatar(
                                                        participant: participant,
                                                        size: 48
                                                    )
                                                    .saturation(
                                                        isUnlocked(participant) ? 1 : 0.15
                                                    )
                                                    .opacity(
                                                        isUnlocked(participant) ? 1 : 0.55
                                                    )

                                                    if !isUnlocked(participant) {
                                                        Image(systemName: "lock.fill")
                                                            .font(
                                                                .system(
                                                                    size: 9,
                                                                    weight: .black
                                                                )
                                                            )
                                                            .foregroundStyle(Color.white)
                                                            .frame(width: 20, height: 20)
                                                            .background(
                                                                SoulTheme.accent,
                                                                in: Circle()
                                                            )
                                                    }
                                                }

                                                Text(participant.name)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(primaryTextColor)
                                                    .lineLimit(1)

                                                if !isUnlocked(participant) {
                                                    Text(localizedText("需升级", "Upgrade"))
                                                        .font(
                                                            .system(
                                                                size: 9,
                                                                weight: .heavy,
                                                                design: .rounded
                                                            )
                                                        )
                                                        .foregroundStyle(SoulTheme.accent)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 104)
                                            .background(
                                                selectedID == participant.id
                                                ? participant.color.opacity(0.18)
                                                : SoulTheme.cardFill,
                                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(selectedID == participant.id ? participant.color.opacity(0.52) : Color.clear, lineWidth: 1.3)
                                            )
                                        }
                                        .buttonStyle(.plain)

                                        if participant.isCustom {
                                            Button {
                                                onDeleteCustom(participant)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(SoulTheme.danger, SoulTheme.cardFill)
                                                    .frame(width: 28, height: 28)
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 4, y: -6)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button(action: onAdd) {
                        Label(
                            ScenarioParticipantAccessPolicy.canAddParticipant(
                                currentCount: participants.count
                            )
                                ? localizedText("创建自定义对象", "Create Custom Partner")
                                : localizedText("解锁更多对话对象", "Unlock More Partners"),
                            systemImage: ScenarioParticipantAccessPolicy.canAddParticipant(
                                currentCount: participants.count
                            ) ? "plus" : "lock.fill"
                        )
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("选择交流对象", "Choose Conversation Partner"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScenarioHistorySheet: View {
    let sessions: [ScenarioConversationSession]
    let currentParticipantName: String
    let onContinue: (ScenarioConversationSession) -> Void
    let onDelete: (ScenarioConversationSession) -> Void

    @State private var searchText = ""
    @State private var pendingDeletion: ScenarioConversationSession?

    private var filteredSessions: [ScenarioConversationSession] {
        sessions.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(secondaryTextColor)

                        TextField(localizedText("搜索用户或聊天关键词", "Search user or chat keywords"), text: $searchText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if filteredSessions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)

                            Text(localizedText("没有找到相关对话", "No matching conversations"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    }

                    ForEach(filteredSessions) { session in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.participantName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(primaryTextColor)

                                    Text(session.dateText)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(secondaryTextColor)
                                }

                                Spacer()

                                HStack(spacing: 6) {
                                    Text(session.participantName == currentParticipantName ? localizedText("当前", "Current") : localizedText("历史", "History"))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(SoulTheme.accent)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(SoulTheme.accentSoft, in: Capsule())

                                    Button(role: .destructive) {
                                        pendingDeletion = session
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(SoulTheme.danger)
                                            .frame(width: 28, height: 28)
                                            .background(SoulTheme.danger.opacity(0.14), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            ForEach(session.messages) { message in
                                Text("\(message.speaker)：\(message.text)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(message.isUser ? primaryTextColor : secondaryTextColor)
                                    .lineLimit(3)
                            }

                            Button {
                                onContinue(session)
                            } label: {
                                Label(localizedText("继续这个对话", "Continue this conversation"), systemImage: "arrowshape.turn.up.right.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(SoulGlassCardBackground())
                    }
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("以前对话", "Past Conversations"))
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                localizedText("删除这条历史对话？", "Delete This Conversation?"),
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let pendingDeletion {
                    Button(localizedText("确认删除", "Delete Conversation"), role: .destructive) {
                        onDelete(pendingDeletion)
                        self.pendingDeletion = nil
                    }
                }
                Button(localizedText("取消", "Cancel"), role: .cancel) {
                    pendingDeletion = nil
                }
            } message: {
                Text(localizedText("删除后无法恢复，请确认这不是误触。", "This cannot be undone. Please confirm it was intentional."))
            }
        }
    }
}

private struct ScenarioControlCard: View {
    let participant: ScenarioParticipant
    @Binding var selectedModeID: ScenarioMode.ID
    let modes: [ScenarioMode]
    let messages: [ScenarioMessage]
    let scrollTarget: UUID
    @Binding var draftMessage: String
    @Binding var recordingTimer: RecordingTimer
    let onAddMode: () -> Void
    let onNewConversation: () -> Void
    let onCancelRecording: () -> Void
    let onConfirmRecording: (Int) -> Void
    let onSend: () -> Void

    @State private var isShowingGuidance = false

    private var selectedMode: ScenarioMode {
        modes.first { $0.id == selectedModeID } ?? modes[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedText("模拟控制台", "Simulation Console"))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text(localizedText("与 \(participant.name) · \(selectedMode.displayTitle)", "With \(participant.name) · \(selectedMode.displayTitle)"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onNewConversation) {
                    Label(localizedText("新对话", "New Chat"), systemImage: "plus")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ScenarioModePicker(
                selectedModeID: $selectedModeID,
                modes: modes,
                onAddMode: onAddMode
            )

            SoulSectionHeader(title: localizedText("对话预览", "Conversation"), detail: "AI Live")

            ScenarioConversationPreview(
                messages: messages,
                guidance: selectedMode.displayGuidance,
                scrollTarget: scrollTarget
            )

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(recordingTimer.isRunning ? SoulTheme.danger : SoulTheme.energy)
                            .frame(width: 7, height: 7)

                        Text(recordingTimer.isRunning ? localizedText("录音中", "RECORDING") : localizedText("语音待命", "VOICE READY"))
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer()

                    VoiceWaveform()
                        .scaleEffect(x: 0.72, y: 0.52)
                        .frame(width: 116, height: 26)

                    Spacer()

                    if recordingTimer.isRunning {
                        Text(recordingTimer.displayText)
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(SoulTheme.danger)
                    } else {
                        Text("00:00")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                HStack(spacing: 32) {
                    ScenarioCircleAction(
                        systemImage: "xmark",
                        color: SoulTheme.danger,
                        action: onCancelRecording
                    )

                    Button {
                        if recordingTimer.isRunning {
                            recordingTimer.stop()
                        } else {
                            recordingTimer.start()
                        }
                    } label: {
                        Image(systemName: recordingTimer.isRunning ? "pause.fill" : "mic.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 72, height: 72)
                            .background(SoulTheme.accent, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.80), lineWidth: 2))
                            .overlay(Circle().stroke(SoulTheme.energy.opacity(0.70), lineWidth: 1.5).padding(-5))
                            .shadow(color: SoulTheme.accent.opacity(0.28), radius: 12, x: 0, y: 7)
                    }
                    .buttonStyle(.plain)

                    ScenarioCircleAction(systemImage: "checkmark", color: Color.white) {
                        let submittedSeconds = recordingTimer.finish()
                        onConfirmRecording(submittedSeconds)
                    }
                }
            }
            .padding(15)
            .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                TextField(localizedText("输入你想练习说的话", "Type what you want to practice saying"), text: $draftMessage)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 46, height: 46)
                        .background(
                            draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.gray.opacity(0.35)
                            : SoulTheme.accent,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
            }

            Divider()
                .background(SoulTheme.cardStroke)

            Button {
                isShowingGuidance = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(SoulTheme.warning)
                        .frame(width: 34, height: 34)
                        .background(SoulTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text(localizedText("实时指导：\(selectedMode.displayGuidance)", "Live guide: \(selectedMode.displayGuidance)"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(SoulGlassCardBackground(cornerRadius: 24, accented: true))
        .sheet(isPresented: $isShowingGuidance) {
            ScenarioGuidanceSheet(mode: selectedMode)
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct ScenarioGuidanceSheet: View {
    let mode: ScenarioMode

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(primaryTextColor)

                    Text(localizedText("完整实时指导", "Full Live Guide"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(SoulTheme.cardFill, in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(mode.displayGuidance)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(primaryTextColor)
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                GuidanceBullet(text: localizedText("先说事实，减少评价和指责。", "Start with facts and reduce judgment or blame."))
                GuidanceBullet(text: localizedText("再说你的感受，让对方知道这件事对你的影响。", "Then share your feelings so they understand the impact."))
                GuidanceBullet(text: localizedText("最后提出一个具体、可执行的下一步。", "Finally propose one specific next step."))
            }

            Spacer()
        }
        .padding(22)
        .background(SoulTheme.pageGradient)
    }
}

private struct GuidanceBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SoulTheme.accent)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .lineSpacing(2)
        }
    }
}

private struct ScenarioModePicker: View {
    @Binding var selectedModeID: ScenarioMode.ID
    let modes: [ScenarioMode]
    let onAddMode: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    Button {
                        selectedModeID = mode.id
                    } label: {
                        Label(mode.displayTitle, systemImage: mode.systemImage)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(selectedModeID == mode.id ? SoulTheme.accent : SoulTheme.secondaryText)
                            .padding(.horizontal, 11)
                            .frame(height: 36)
                            .background(
                                selectedModeID == mode.id
                                ? SoulTheme.accentSoft
                                : SoulTheme.cardFill,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onAddMode) {
                    Label(localizedText("自定义", "Custom"), systemImage: "plus")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(SoulTheme.accent)
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                        .background(SoulTheme.cardFill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }
}

private struct ScenarioModePickerSheet: View {
    let modes: [ScenarioMode]
    let selectedModeID: ScenarioMode.ID
    let onSelect: (ScenarioMode) -> Void
    let onAddMode: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        localizedText(
                            "选择这次想练习的对话方式",
                            "Choose how you want to practice this conversation"
                        )
                    )
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)

                    ForEach(modes) { mode in
                        Button {
                            onSelect(mode)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: mode.systemImage)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        selectedModeID == mode.id
                                            ? Color.white
                                            : SoulTheme.accent
                                    )
                                    .frame(width: 42, height: 42)
                                    .background(
                                        selectedModeID == mode.id
                                            ? SoulTheme.accent
                                            : SoulTheme.accentSoft,
                                        in: RoundedRectangle(
                                            cornerRadius: SoulTheme.compactCornerRadius,
                                            style: .continuous
                                        )
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayTitle)
                                        .font(
                                            .system(
                                                size: 15,
                                                weight: .heavy,
                                                design: .rounded
                                            )
                                        )
                                        .foregroundStyle(SoulTheme.primaryText)

                                    Text(mode.displayGuidance)
                                        .font(
                                            .system(
                                                size: 11,
                                                weight: .semibold,
                                                design: .rounded
                                            )
                                        )
                                        .foregroundStyle(SoulTheme.secondaryText)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                Image(
                                    systemName: selectedModeID == mode.id
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(
                                    selectedModeID == mode.id
                                        ? SoulTheme.accent
                                        : SoulTheme.cardStroke
                                )
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedModeID == mode.id
                                    ? SoulTheme.accentSoft
                                    : SoulTheme.cardFill,
                                in: RoundedRectangle(
                                    cornerRadius: SoulTheme.controlCornerRadius,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: SoulTheme.controlCornerRadius,
                                    style: .continuous
                                )
                                .stroke(
                                    selectedModeID == mode.id
                                        ? SoulTheme.accent.opacity(0.44)
                                        : SoulTheme.cardStroke,
                                    lineWidth: 1
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onAddMode) {
                        HStack(spacing: 14) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(SoulTheme.accent)
                                .frame(width: 42, height: 42)
                                .background(
                                    SoulTheme.accentSoft,
                                    in: RoundedRectangle(
                                        cornerRadius: SoulTheme.compactCornerRadius,
                                        style: .continuous
                                    )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedText("创建自定义模式", "Create Custom Mode"))
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SoulTheme.primaryText)

                                Text(localizedText(
                                    "设置名称和专属对话指导",
                                    "Set a name and custom conversation guidance"
                                ))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoulTheme.secondaryText)
                                .lineLimit(2)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(SoulTheme.accent)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            SoulTheme.cardFill,
                            in: RoundedRectangle(
                                cornerRadius: SoulTheme.controlCornerRadius,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: SoulTheme.controlCornerRadius,
                                style: .continuous
                            )
                            .stroke(SoulTheme.cardStroke, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(SoulTheme.pageGradient)
            .navigationTitle(localizedText("选择模拟模式", "Choose Simulation Mode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizedText("关闭", "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ScenarioParticipantUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.2.badge.plus.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 72, height: 72)
                .background(SoulTheme.accent, in: Circle())
                .shadow(
                    color: SoulTheme.accent.opacity(0.25),
                    radius: 14,
                    x: 0,
                    y: 8
                )

            VStack(spacing: 8) {
                Text(
                    localizedText(
                        "更多对话对象需要升级",
                        "Upgrade for More Partners"
                    )
                )
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .multilineTextAlignment(.center)

                Text(
                    localizedText(
                        "免费版支持 2 位情景模拟对象。升级后即可解锁更多对象。",
                        "The free plan supports 2 simulation partners. Upgrade to unlock more."
                    )
                )
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.secondaryText)
                .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Label(
                    localizedText("了解升级", "Explore Upgrade"),
                    systemImage: "lock.open.fill"
                )
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    SoulTheme.accent,
                    in: RoundedRectangle(
                        cornerRadius: SoulTheme.controlCornerRadius,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)

            Text(
                localizedText(
                    "当前仅作付费提示，不会发起扣款。",
                    "This is only an upgrade notice; no payment will be started."
                )
            )
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(SoulTheme.secondaryText)
        }
        .padding(24)
        .background(SoulTheme.pageGradient)
    }
}

private struct ScenarioConversationPreview: View {
    let messages: [ScenarioMessage]
    let guidance: String
    let scrollTarget: UUID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(SoulTheme.energy)

                            Text(localizedText("新的对话已准备好", "New conversation ready"))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(primaryTextColor)

                            Text(localizedText("说出第一句话，AI 会根据当前对象回应。", "Say the first line and AI will respond based on the current partner."))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    }

                    ForEach(messages) { message in
                        HStack {
                            if message.isUser {
                                Spacer(minLength: 28)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(message.speaker)
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(secondaryTextColor)

                                Text(message.text)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(primaryTextColor)
                                    .lineSpacing(2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                message.isUser
                                ? SoulTheme.accent.opacity(0.18)
                                : SoulTheme.cardFill,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )

                            if !message.isUser {
                                Spacer(minLength: 28)
                            }
                        }
                        .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("conversation-bottom")
                }
                .padding(10)
            }
            .onChange(of: scrollTarget) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("conversation-bottom", anchor: .bottom)
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .background(SoulTheme.subtleFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ScenarioCircleAction: View {
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(systemImage == "checkmark" ? SoulTheme.visorSurface : Color.white)
                .frame(width: 50, height: 50)
                .background(color, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct VoiceWaveform: View {
    private let bars: [CGFloat] = [18, 8, 26, 36, 22, 10, 28, 42, 16, 24, 34, 12, 26, 18]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(SoulTheme.accent.opacity(0.62))
                    .frame(width: 4, height: height)
            }
        }
    }
}

private struct ScenarioAvatar: View {
    let participant: ScenarioParticipant
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(participant.color.opacity(participant.isCustom ? 0.24 : 0.70))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 2))

            Image(systemName: participant.symbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(primaryTextColor)
        }
    }
}

private struct ScenarioTabBar: View {
    let onOpenRelationshipGraph: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            ScenarioTabItem(title: localizedText("首页", "Home"), systemImage: "house.fill", isSelected: false)

            Button(action: onOpenRelationshipGraph) {
                ScenarioTabItem(title: localizedText("关系网", "Map"), systemImage: "point.3.connected.trianglepath.dotted", isSelected: false)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(SoulTheme.accent)
                        .frame(width: 74, height: 74)

                    Image(systemName: "figure.wave")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                Text(localizedText("情景模拟", "Simulation"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -18)

            ScenarioTabItem(title: localizedText("情景模拟", "Simulation"), systemImage: "text.bubble.fill", isSelected: false)
            ScenarioTabItem(title: localizedText("我的", "Me"), systemImage: "person.crop.circle", isSelected: false)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(height: 98)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct ScenarioTabItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .semibold))

            Text(title)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(isSelected ? SoulTheme.primaryText : SoulTheme.secondaryText)
        .frame(maxWidth: .infinity)
    }
}

private struct AddScenarioParticipantSheet: View {
    let onAdd: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var relationship = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedText("创建模拟对象", "Create Simulation Partner"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 34, height: 34)
                        .background(SoulTheme.cardFill, in: Circle())
                }
            }

            TextField(localizedText("名字，例如：面试官", "Name, e.g. Interviewer"), text: $name)
                .textFieldStyle(.roundedBorder)

            TextField(localizedText("场景备注，例如：模拟一次艰难沟通", "Scene note, e.g. Practice a difficult conversation"), text: $note)
                .textFieldStyle(.roundedBorder)

            TextField(localizedText("关系标签，例如：导师、客户、朋友", "Relationship label, e.g. Mentor, Client, Friend"), text: $relationship)
                .textFieldStyle(.roundedBorder)

            Button {
                onAdd(name, note, relationship)
                dismiss()
            } label: {
                Label(localizedText("加入模拟", "Add to Simulation"), systemImage: "plus.message.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? SoulTheme.accent : Color.gray.opacity(0.20), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!canSubmit)

            Spacer()
        }
        .padding(24)
        .background(SoulTheme.pageGradient)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AddScenarioModeSheet: View {
    let onAdd: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var guidance = ""

    var body: some View {
        ZStack {
            SoulBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(
                            SoulTheme.accent,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedText("自定义模拟模式", "Custom Simulation Mode"))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(SoulTheme.primaryText)

                        Text(localizedText("创建你的专属练习场景", "Create your own practice scenario"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(SoulTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(SoulTheme.secondaryText)
                            .frame(width: 36, height: 36)
                            .background(SoulTheme.cardFill, in: Circle())
                            .overlay {
                                Circle().stroke(SoulTheme.cardStroke, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    modeField(
                        title: localizedText("模式名称", "Mode Name"),
                        placeholder: localizedText("例如：和室友沟通", "e.g. Talk with roommate"),
                        icon: "textformat",
                        text: $title
                    )

                    modeField(
                        title: localizedText("实时指导", "Live Guidance"),
                        placeholder: localizedText("例如：先讲事实，再讲需求", "e.g. Say facts first, then needs"),
                        icon: "sparkles",
                        text: $guidance
                    )
                }
                .padding(16)
                .background(SoulGlassCardBackground(accented: true))

                Button {
                    onAdd(title, guidance)
                    dismiss()
                } label: {
                    Label(localizedText("添加模式", "Add Mode"), systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            canSubmit ? SoulTheme.accent : SoulTheme.tertiaryText.opacity(0.32),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(22)
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func modeField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)

            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(SoulTheme.primaryText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(
                    SoulTheme.cardFill,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SoulTheme.cardStroke, lineWidth: 1)
                }
        }
    }
}
