import AVFAudio
import Foundation
import SwiftUI

enum RealtimeVoiceCallPhase: Equatable {
    case idle
    case connecting
    case listening
    case speaking
    case failed(String)

    var isActive: Bool {
        switch self {
        case .connecting, .listening, .speaking:
            true
        case .idle, .failed:
            false
        }
    }

    var title: String {
        switch self {
        case .idle:
            localizedText("准备通话", "Ready to call")
        case .connecting:
            localizedText("正在连接 Soul", "Connecting to Soul")
        case .listening:
            localizedText("Soul 正在听", "Soul is listening")
        case .speaking:
            localizedText("Soul 正在回应", "Soul is responding")
        case .failed:
            localizedText("连接未完成", "Connection failed")
        }
    }
}

enum ScenarioEmotion: String, Equatable {
    case calm
    case happy
    case caring
    case serious
    case encouraging

    init(serverValue: String?) {
        self = serverValue.flatMap(Self.init(rawValue:)) ?? .calm
    }
}

enum ScenarioMascotAnimationState: Equatable {
    case idle
    case listening
    case thinking
    case speaking(ScenarioEmotion)
    case failed
}

extension RealtimeVoiceCallPhase {
    func mascotAnimationState(emotion: ScenarioEmotion) -> ScenarioMascotAnimationState {
        switch self {
        case .idle: .idle
        case .connecting: .thinking
        case .listening: .listening
        case .speaking: .speaking(emotion)
        case .failed: .failed
        }
    }
}

struct RealtimeTranscriptEvent: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct RealtimeVoiceSessionStart: Encodable {
    let type = "session.start"
    let participantName: String
    let participantNote: String
    let relationshipLabel: String
    let modeTitle: String
    let modeGuidance: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case type
        case participantName = "participant_name"
        case participantNote = "participant_note"
        case relationshipLabel = "relationship_label"
        case modeTitle = "mode_title"
        case modeGuidance = "mode_guidance"
        case language
    }
}

enum RealtimeVoiceServiceConfiguration {
    static var defaultBackendURL: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "SOULMARK_API_BASE_URL") as? String,
           !configured.isEmpty {
            return configured
        }
#if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
#elseif DEBUG
        return "http://192.168.110.109:8000"
#else
        return "https://api.soulmark.app"
#endif
    }

    static func websocketURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw RealtimeVoiceError.invalidBackendURL
        }
        components.scheme = scheme == "https" ? "wss" : "ws"
        components.path = "/api/v1/realtime/scenario"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw RealtimeVoiceError.invalidBackendURL
        }
        return url
    }
}

enum RealtimeVoiceError: LocalizedError {
    case invalidBackendURL
    case microphoneDenied
    case voiceProcessingUnavailable
    case invalidServerMessage
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            localizedText("语音服务地址无效，请在设置中检查。", "The voice service address is invalid. Check Settings.")
        case .microphoneDenied:
            localizedText("需要麦克风权限才能开始通话。", "Microphone access is required to start a call.")
        case .voiceProcessingUnavailable:
            localizedText(
                "当前音频设备无法启用通话回声消除，请更换音频设备后重试。",
                "Echo cancellation is unavailable for the current audio device. Try another audio device."
            )
        case .invalidServerMessage:
            localizedText("语音服务返回了无法识别的数据。", "The voice service returned an invalid message.")
        case .server(let message):
            message
        }
    }
}

enum RealtimeVoiceStartupPolicy {
    static func shouldFail(
        voiceProcessingEnabled: Bool,
        mutedSpeechDetectionAvailable _: Bool
    ) -> Bool {
        !voiceProcessingEnabled
    }
}

private struct RealtimeServerEvent: Decodable {
    let type: String
    let text: String?
    let code: String?
    let message: String?
    let recoverable: Bool?
    let emotion: String?
}

@MainActor
final class RealtimeVoiceCallManager: ObservableObject {
    @Published private(set) var phase: RealtimeVoiceCallPhase = .idle
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var isMuted = false
    @Published private(set) var assistantDraft = ""
    @Published private(set) var assistantEmotion: ScenarioEmotion = .calm
    @Published private(set) var latestTranscript: RealtimeTranscriptEvent?
    @Published private(set) var errorMessage: String?

    private let audio = RealtimeAudioEngine()
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var isEnding = false
    private var acceptsAssistantAudio = false

    var durationText: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    func start(
        participant: ScenarioParticipant,
        mode: ScenarioMode,
        backendURL: String,
        language: String
    ) async {
        guard !phase.isActive else { return }
        errorMessage = nil
        assistantDraft = ""
        assistantEmotion = .calm
        elapsedSeconds = 0
        isMuted = false
        isEnding = false
        acceptsAssistantAudio = false
        phase = .connecting

        do {
            guard await requestMicrophonePermission() else {
                throw RealtimeVoiceError.microphoneDenied
            }
            let url = try RealtimeVoiceServiceConfiguration.websocketURL(from: backendURL)
            var request = URLRequest(url: url)
            if let token = AuthTokenStore.shared.read(), !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let webSocket = URLSession.shared.webSocketTask(with: request)
            socket = webSocket
            webSocket.resume()
            receiveTask = Task { [weak self] in
                await self?.receiveMessages(from: webSocket)
            }

            let start = RealtimeVoiceSessionStart(
                participantName: participant.name,
                participantNote: participant.note,
                relationshipLabel: participant.relationshipLabel,
                modeTitle: mode.displayTitle,
                modeGuidance: mode.displayGuidance,
                language: language
            )
            let payload = try JSONEncoder().encode(start)
            guard let text = String(data: payload, encoding: .utf8) else {
                throw RealtimeVoiceError.invalidServerMessage
            }
            try await webSocket.send(.string(text))
        } catch {
            fail(error)
        }
    }

    @discardableResult
    func end() -> Int {
        let duration = elapsedSeconds
        guard phase.isActive || socket != nil else {
            phase = .idle
            return duration
        }
        isEnding = true
        if let socket {
            socket.send(.string(#"{"type":"session.complete"}"#)) { _ in }
            socket.cancel(with: .normalClosure, reason: nil)
        }
        cleanUp()
        phase = .idle
        return duration
    }

    func toggleMute() {
        isMuted.toggle()
        audio.isCaptureMuted = isMuted
    }

    func clearError() {
        errorMessage = nil
        if case .failed = phase {
            phase = .idle
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func receiveMessages(from webSocket: URLSessionWebSocketTask) async {
        do {
            while !Task.isCancelled {
                let message = try await webSocket.receive()
                switch message {
                case .data(let data):
                    if acceptsAssistantAudio {
                        audio.play(data)
                    }
                case .string(let text):
                    try handleServerText(text)
                @unknown default:
                    throw RealtimeVoiceError.invalidServerMessage
                }
            }
        } catch {
            if !isEnding {
                fail(error)
            }
        }
    }

    private func handleServerText(_ text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw RealtimeVoiceError.invalidServerMessage
        }
        let event = try JSONDecoder().decode(RealtimeServerEvent.self, from: data)
        switch event.type {
        case "session.ready":
            try startAudioCapture()
            phase = .listening
            startDurationTimer()
        case "input.speech_started":
            let isInterruptingAssistant = acceptsAssistantAudio || phase == .speaking
            acceptsAssistantAudio = false
            audio.stopPlayback()
            assistantDraft = ""
            assistantEmotion = .calm
            phase = .listening
            if isInterruptingAssistant {
                socket?.send(.string(#"{"type":"response.cancel"}"#)) { _ in }
            }
        case "assistant.response_started":
            acceptsAssistantAudio = true
            audio.setAssistantResponseActive(true)
            assistantEmotion = .calm
            phase = .speaking
        case "assistant.emotion":
            assistantEmotion = ScenarioEmotion(serverValue: event.emotion)
        case "assistant.response_completed":
            acceptsAssistantAudio = false
            audio.setAssistantResponseActive(false)
            phase = .listening
        case "user.transcript.completed":
            publishTranscript(role: .user, text: event.text)
        case "assistant.transcript.delta":
            if let delta = event.text {
                assistantDraft += delta
            }
        case "assistant.transcript.completed":
            publishTranscript(role: .assistant, text: event.text)
            assistantDraft = ""
        case "error":
            let message = event.message ?? localizedText("语音服务暂时不可用。", "The voice service is unavailable.")
            if event.recoverable != true {
                throw RealtimeVoiceError.server(message)
            }
            errorMessage = message
        default:
            break
        }
    }

    private func publishTranscript(role: RealtimeTranscriptEvent.Role, text: String?) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        latestTranscript = RealtimeTranscriptEvent(role: role, text: text)
    }

    private func startAudioCapture() throws {
        try audio.start(
            onAudio: { [weak self] data in
                Task { @MainActor [weak self] in
                    guard let self, let socket = self.socket, self.phase.isActive else { return }
                    do {
                        try await socket.send(.data(data))
                    } catch {
                        if !self.isEnding {
                            self.fail(error)
                        }
                    }
                }
            },
            onBargeIn: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleLocalBargeIn()
                }
            }
        )
    }

    private func handleLocalBargeIn() {
        guard phase.isActive else { return }
        let shouldCancelResponse = acceptsAssistantAudio || phase == .speaking
        acceptsAssistantAudio = false
        audio.stopPlayback()
        assistantDraft = ""
        assistantEmotion = .calm
        phase = .listening
        if shouldCancelResponse {
            socket?.send(.string(#"{"type":"response.cancel"}"#)) { _ in }
        }
    }

    private func startDurationTimer() {
        durationTask?.cancel()
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.elapsedSeconds += 1
            }
        }
    }

    private func fail(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription
            ?? localizedText("无法连接语音服务，请检查后端地址和网络。", "Could not connect to the voice service. Check the server address and network.")
        errorMessage = message
        cleanUp()
        phase = .failed(message)
    }

    private func cleanUp() {
        receiveTask?.cancel()
        receiveTask = nil
        durationTask?.cancel()
        durationTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        audio.stop()
        assistantDraft = ""
        assistantEmotion = .calm
        isMuted = false
        acceptsAssistantAudio = false
    }
}

final class RealtimeCaptureGate: @unchecked Sendable {
    private let lock = NSLock()
    private var protectsAssistantPlayback = true
    private var manuallyMuted = false
    private var assistantResponseActive = false
    private var pendingPlaybackBuffers = 0
    private var tailProtected = false
    private var generation = 0

    var canCapture: Bool {
        lock.lock()
        defer { lock.unlock() }
        // Voice processing already performs acoustic echo cancellation. Dropping every
        // microphone frame during assistant playback makes speech disappear whenever
        // the muted-speech callback is delayed or unavailable on a device.
        return !manuallyMuted
    }

    var shouldMuteVoiceProcessingInput: Bool {
        lock.lock()
        defer { lock.unlock() }
        return manuallyMuted
    }

    var isManuallyMuted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return manuallyMuted
    }

    @discardableResult
    func setManuallyMuted(_ muted: Bool) -> Bool {
        lock.lock()
        manuallyMuted = muted
        let shouldMute = manuallyMuted
        lock.unlock()
        return shouldMute
    }

    func setAssistantPlaybackProtectionEnabled(_ enabled: Bool) {
        lock.lock()
        protectsAssistantPlayback = enabled
        if !enabled {
            assistantResponseActive = false
            pendingPlaybackBuffers = 0
            tailProtected = false
            generation += 1
        }
        lock.unlock()
    }

    @discardableResult
    func setAssistantResponseActive(_ active: Bool) -> Int? {
        lock.lock()
        let wasAssistantProtected = isAssistantProtected
        assistantResponseActive = active
        generation += 1
        let currentGeneration = generation
        if active {
            tailProtected = true
        }
        let shouldScheduleTail = !active
            && wasAssistantProtected
            && pendingPlaybackBuffers == 0
        if shouldScheduleTail {
            tailProtected = true
        }
        lock.unlock()
        return shouldScheduleTail ? currentGeneration : nil
    }

    func beginPlaybackBuffer() {
        lock.lock()
        pendingPlaybackBuffers += 1
        tailProtected = true
        generation += 1
        lock.unlock()
    }

    func finishPlaybackBuffer() -> Int? {
        lock.lock()
        guard pendingPlaybackBuffers > 0 else {
            lock.unlock()
            return nil
        }
        pendingPlaybackBuffers -= 1
        generation += 1
        let currentGeneration = generation
        let shouldScheduleTail = pendingPlaybackBuffers == 0 && !assistantResponseActive
        lock.unlock()
        return shouldScheduleTail ? currentGeneration : nil
    }

    func releaseTail(generation expectedGeneration: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration,
              !assistantResponseActive,
              pendingPlaybackBuffers == 0 else {
            return false
        }
        tailProtected = false
        return true
    }

    func beginBargeIn() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !manuallyMuted, isAssistantProtected else { return false }
        assistantResponseActive = false
        pendingPlaybackBuffers = 0
        tailProtected = false
        generation += 1
        return true
    }

    func reset() {
        lock.lock()
        manuallyMuted = false
        assistantResponseActive = false
        pendingPlaybackBuffers = 0
        tailProtected = false
        generation += 1
        lock.unlock()
    }

    private var isAssistantProtected: Bool {
        protectsAssistantPlayback
            && (assistantResponseActive || pendingPlaybackBuffers > 0 || tailProtected)
    }
}

private final class RealtimeAudioEngine: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let captureGate = RealtimeCaptureGate()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!
    private var converter: AVAudioConverter?
    private var hasInputTap = false
    private var hasMutedSpeechListener = false
    private let playbackTailDuration: TimeInterval = 0.2
    var isCaptureMuted: Bool {
        get { captureGate.isManuallyMuted }
        set {
            _ = captureGate.setManuallyMuted(newValue)
            applyVoiceProcessingInputMute()
        }
    }

    func setAssistantResponseActive(_ active: Bool) {
        let tailGeneration = captureGate.setAssistantResponseActive(active)
        applyVoiceProcessingInputMute()
        if let tailGeneration {
            scheduleTailRelease(generation: tailGeneration)
        }
    }

    func start(
        onAudio: @escaping @Sendable (Data) -> Void,
        onBargeIn: @escaping @Sendable () -> Void
    ) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let input = engine.inputNode
        if !input.isVoiceProcessingEnabled {
            do {
                try input.setVoiceProcessingEnabled(true)
            } catch {
#if targetEnvironment(simulator)
                captureGate.setAssistantPlaybackProtectionEnabled(false)
#else
                throw RealtimeVoiceError.voiceProcessingUnavailable
#endif
            }
        }
#if !targetEnvironment(simulator)
        guard input.isVoiceProcessingEnabled else {
            throw RealtimeVoiceError.voiceProcessingUnavailable
        }
#endif
        if input.isVoiceProcessingEnabled {
            hasMutedSpeechListener = input.setMutedSpeechActivityEventListener { [weak self] event in
                guard event == .started,
                      let self,
                      self.captureGate.beginBargeIn() else {
                    return
                }
                self.applyVoiceProcessingInputMute()
                onBargeIn()
            }
        }
        captureGate.setAssistantPlaybackProtectionEnabled(hasMutedSpeechListener)
#if !targetEnvironment(simulator)
        guard !RealtimeVoiceStartupPolicy.shouldFail(
            voiceProcessingEnabled: input.isVoiceProcessingEnabled,
            mutedSpeechDetectionAvailable: hasMutedSpeechListener
        ) else {
            throw RealtimeVoiceError.voiceProcessingUnavailable
        }
#endif

        if player.engine == nil {
            engine.attach(player)
        }
        engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)

        let inputFormat = input.outputFormat(forBus: 0)
        guard let captureFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: captureFormat) else {
            throw RealtimeVoiceError.invalidServerMessage
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self.captureGate.canCapture,
                  let data = self.convert(buffer, using: converter, to: captureFormat) else { return }
            onAudio(data)
        }
        hasInputTap = true
        engine.prepare()
        try engine.start()
    }

    func play(_ data: Data) {
        guard !data.isEmpty, data.count.isMultiple(of: MemoryLayout<Int16>.size) else { return }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount),
              let destination = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            let samples = source.assumingMemoryBound(to: Int16.self)
            for index in 0..<Int(frameCount) {
                destination[index] = Float(samples[index]) / Float(Int16.max)
            }
        }
        captureGate.beginPlaybackBuffer()
        applyVoiceProcessingInputMute()
        player.scheduleBuffer(
            buffer,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            guard let self else { return }
            if let tailGeneration = self.captureGate.finishPlaybackBuffer() {
                self.scheduleTailRelease(generation: tailGeneration)
            }
            self.applyVoiceProcessingInputMute()
        }
        if !player.isPlaying {
            player.play()
        }
    }

    func stopPlayback() {
        player.stop()
        _ = captureGate.beginBargeIn()
        applyVoiceProcessingInputMute()
    }

    func stop() {
        player.stop()
        if hasMutedSpeechListener {
            engine.inputNode.setMutedSpeechActivityEventListener(nil)
            hasMutedSpeechListener = false
        }
        if hasInputTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        engine.stop()
        engine.reset()
        converter = nil
        captureGate.reset()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func scheduleTailRelease(generation: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + playbackTailDuration
        ) { [weak self] in
            guard let self, self.captureGate.releaseTail(generation: generation) else { return }
            self.applyVoiceProcessingInputMute()
        }
    }

    private func applyVoiceProcessingInputMute() {
        guard engine.inputNode.isVoiceProcessingEnabled else { return }
        engine.inputNode.isVoiceProcessingInputMuted = captureGate.shouldMuteVoiceProcessingInput
    }

    private func convert(
        _ input: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> Data? {
        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var conversionError: NSError?
        var suppliedInput = false
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return input
        }
        guard conversionError == nil,
              status != .error,
              output.frameLength > 0,
              let samples = output.int16ChannelData?[0] else { return nil }
        return Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }
}
