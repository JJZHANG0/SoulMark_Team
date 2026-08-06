# Scenario Mascot Emotion Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Animate the SoulMark scenario mascot with restrained body motion and visor-led emotion that follows realtime listening and AI response states.

**Architecture:** The realtime gateway begins every response in calm state, derives one supported emotion from the first meaningful assistant transcript fragment, and sends an optional `assistant.emotion` event without delaying audio. The iOS realtime manager decodes that value into a small animation state model, and a scenario-only SwiftUI wrapper animates the existing mascot image plus a precisely aligned visor overlay.

**Tech Stack:** SwiftUI, AVFAudio realtime WebSocket events, FastAPI WebSocket gateway, pytest, Swift Testing.

## Global Constraints

- Keep whole-body translation within 1–4 points and rotation within 1–2 degrees.
- Keep `SoulMascotFigure` unchanged for Home, Profile, and Authentication.
- Unknown or missing emotion values must fall back to `calm` and must not delay audio.
- User interruption must move the mascot to listening immediately.
- Respect Reduce Motion by disabling continuous body and scanning transforms.
- Run only targeted state/protocol tests and one compile check; do not run the full UI suite.
- Preserve unrelated local changes, including `.idea/workspace.xml`.

---

### Task 1: Realtime emotion protocol

**Files:**
- Modify: `SoulMark_backend/app/api/v1/realtime.py`
- Modify: `SoulMark_backend/tests/test_realtime_gateway.py`

**Interfaces:**
- Consumes: assistant transcript deltas relayed from Qwen.
- Produces: `classify_scenario_emotion(text: str) -> str` and one optional `assistant.emotion` JSON event per response with `emotion` in `calm|happy|caring|serious|encouraging`.

- [ ] **Step 1: Write the failing classifier test**

Add to `SoulMark_backend/tests/test_realtime_gateway.py`:

```python
from app.api.v1.realtime import classify_scenario_emotion


def test_scenario_emotion_classifier_uses_supported_fallbacks() -> None:
    assert classify_scenario_emotion("太好了，我终于成功了") == "happy"
    assert classify_scenario_emotion("我最近真的很难过") == "caring"
    assert classify_scenario_emotion("这件事必须认真处理") == "serious"
    assert classify_scenario_emotion("我想试着勇敢说出来") == "encouraging"
    assert classify_scenario_emotion("我们继续聊吧") == "calm"
```

- [ ] **Step 2: Run the classifier test and verify RED**

Run:

```bash
cd SoulMark_backend
.venv/bin/pytest tests/test_realtime_gateway.py::test_scenario_emotion_classifier_uses_supported_fallbacks -q
```

Expected: collection fails because `classify_scenario_emotion` does not exist.

- [ ] **Step 3: Implement the deterministic gateway classifier**

Add a bounded, ordered keyword classifier in `realtime.py`:

```python
SCENARIO_EMOTION_KEYWORDS = {
    "caring": ("难过", "伤心", "害怕", "焦虑", "痛苦", "sad", "afraid", "anxious"),
    "happy": ("太好了", "开心", "成功", "高兴", "great news", "happy", "succeeded"),
    "serious": ("必须", "底线", "严重", "认真", "must", "boundary", "serious"),
    "encouraging": ("想试", "努力", "勇敢", "开始", "try", "brave", "start"),
}


def classify_scenario_emotion(text: str) -> str:
    normalized = text.casefold()
    for emotion, keywords in SCENARIO_EMOTION_KEYWORDS.items():
        if any(keyword in normalized for keyword in keywords):
            return emotion
    return "calm"
```

Reset an assistant transcript buffer and `emotion_sent` flag on `response.created`. Append each `response.audio_transcript.delta`; once the buffer contains meaningful text, send at most one emotion event:

```python
await websocket.send_json(
    {
        "type": "assistant.emotion",
        "emotion": classify_scenario_emotion(assistant_text),
    }
)
```

- [ ] **Step 4: Extend the gateway relay test**

Update the existing fake Qwen event sequence to include `response.created` followed by an assistant transcript delta, then assert the client receives:

```python
assert socket.receive_json() == {
    "type": "assistant.emotion",
    "emotion": "caring",
}
```

- [ ] **Step 5: Run only gateway emotion tests and verify GREEN**

Run:

```bash
cd SoulMark_backend
.venv/bin/pytest tests/test_realtime_gateway.py -q
```

Expected: all tests in this file pass.

---

### Task 2: iOS emotion and animation state model

**Files:**
- Modify: `SoulMark/RealtimeVoiceCall.swift`
- Modify: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Consumes: optional `emotion` from `assistant.emotion` and `RealtimeVoiceCallPhase`.
- Produces: `ScenarioEmotion`, `ScenarioMascotAnimationState`, `RealtimeVoiceCallPhase.mascotAnimationState(emotion:)`, and published `assistantEmotion`.

- [ ] **Step 1: Write failing Swift state tests**

Add to `SoulMarkTests/SoulMarkTests.swift`:

```swift
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
```

- [ ] **Step 2: Run only the two tests and verify RED**

Run:

```bash
xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:SoulMarkTests/SoulMarkTests/scenarioEmotionFallsBackToCalm -only-testing:SoulMarkTests/SoulMarkTests/realtimePhaseHasPriorityOverEmotion CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because the new types do not exist.

- [ ] **Step 3: Add the state model**

Add to `RealtimeVoiceCall.swift`:

```swift
enum ScenarioEmotion: String, Equatable {
    case calm, happy, caring, serious, encouraging

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
```

Add a mapping method where call phase overrides stale emotion. Map `.connecting` to `.thinking`, `.listening` to `.listening`, `.speaking` to `.speaking(emotion)`, and `.failed` to `.failed`.

- [ ] **Step 4: Decode and publish the server emotion**

Add `emotion: String?` to `RealtimeServerEvent`, add:

```swift
@Published private(set) var assistantEmotion: ScenarioEmotion = .calm
```

On `assistant.response_started`, reset `assistantEmotion` to `.calm` before setting phase to speaking. On `assistant.emotion`, set `assistantEmotion = ScenarioEmotion(serverValue: event.emotion)`. Reset it to `.calm` on a new session and cleanup.

- [ ] **Step 5: Run only the state tests and verify GREEN**

Run the Step 2 command again. Expected: both targeted tests pass.

---

### Task 3: Scenario-only animated mascot

**Files:**
- Modify: `SoulMark/ScenarioSimulationView.swift`

**Interfaces:**
- Consumes: `ScenarioMascotAnimationState`, `SoulTheme.accent`, `SoulTheme.energy`, and `accessibilityReduceMotion`.
- Produces: `ScenarioAnimatedMascot` and `ScenarioVisorLight` private SwiftUI views.

- [ ] **Step 1: Add the fixed-frame animated wrapper**

Create a private `ScenarioAnimatedMascot` near the scenario presentation components:

```swift
private struct ScenarioAnimatedMascot: View {
    let height: CGFloat
    let state: ScenarioMascotAnimationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loop = false

    var body: some View {
        ZStack {
            Image("SoulMascot")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .scaleEffect(bodyScale)
                .rotationEffect(.degrees(bodyRotation))
                .offset(x: bodyOffset.width, y: bodyOffset.height)

            ScenarioVisorLight(height: height, state: state, loop: loop)
        }
        .frame(height: height)
        .clipped()
        .onAppear { loop = true }
        .onDisappear { loop = false }
        .animation(reduceMotion ? nil : loopAnimation, value: loop)
        .animation(.easeInOut(duration: 0.28), value: state)
    }
}
```

Keep computed transforms inside the approved bounds. When Reduce Motion is true, return identity transforms.

- [ ] **Step 2: Add the visor overlay**

Build `ScenarioVisorLight` using a trimmed `Capsule`/curved stroke positioned proportionally inside the fixed mascot frame. Use these mappings:

```swift
// idle: cyan, low opacity, slow pulse
// listening: narrow cyan, directional shimmer
// thinking: cyan scan, still body
// happy: cyan-green, slightly wider and brighter
// caring: warm cyan, slow soft pulse
// serious: darker, thinner, low movement
// encouraging: energy color, one restrained expansion
// failed: SoulTheme.warning at low opacity, no flashing
```

Keep the overlay inside the character frame and mark it accessibility-hidden.

- [ ] **Step 3: Wire realtime state into the scenario screen**

Replace only the scenario call site's `SoulMascotFigure` with:

```swift
ScenarioAnimatedMascot(
    height: voiceCall.phase.isActive || !conversation.isEmpty ? 175 : 238,
    state: voiceCall.phase.mascotAnimationState(emotion: voiceCall.assistantEmotion)
)
```

Leave all other `SoulMascotFigure` call sites unchanged.

- [ ] **Step 4: Verify interruption behavior in code**

Confirm both server `input.speech_started` and local `handleLocalBargeIn()` set phase to `.listening`. Because phase has mapping priority, no additional animation cancellation state is allowed.

---

### Task 4: Focused verification

**Files:**
- No production file changes expected.

**Interfaces:**
- Consumes: completed backend protocol, iOS state model, and animated mascot.
- Produces: verification evidence only.

- [ ] **Step 1: Run backend realtime gateway tests**

```bash
cd SoulMark_backend
.venv/bin/pytest tests/test_realtime_gateway.py -q
```

Expected: pass with no failures.

- [ ] **Step 2: Run the two targeted Swift tests**

Use the command from Task 2 Step 2. Expected: two tests pass. If the local simulator service is unavailable, record that environmental blocker and continue to the compile check.

- [ ] **Step 3: Compile the app once without UI tests**

```bash
xcodebuild build -project SoulMark.xcodeproj -scheme SoulMark -destination 'generic/platform=iOS' -derivedDataPath .derivedData/mascot-animation CODE_SIGNING_ALLOWED=NO EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets
```

Expected: `BUILD SUCCEEDED`. If the host blocks Observation macros or simulator asset tooling, separately run:

```bash
xcrun swiftc -frontend -parse SoulMark/*.swift SoulMarkTests/*.swift
git diff --check
```

and report the build as environment-blocked rather than passing.

- [ ] **Step 4: Review scope**

```bash
git diff --name-only
git diff --check
```

Confirm only realtime gateway/tests, realtime iOS manager/tests, scenario UI, and intended documentation changed; preserve `.idea/workspace.xml` as unrelated user state.
