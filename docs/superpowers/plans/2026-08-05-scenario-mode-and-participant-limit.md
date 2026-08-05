# Scenario Mode And Participant Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make mode selection unavoidable on scenario-page entry and limit free scenario partners to two with a visual upgrade prompt.

**Architecture:** Add a pure access policy in the existing model file so quota behavior is independently testable. Keep the UI state and presentation in `ScenarioSimulationView.swift`, with focused mode-picker and upgrade-prompt components that reuse the current sheets and theme.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Xcode project build.

## Global Constraints

- Free scenario access is limited to exactly two conversation partners.
- Every new `ScenarioSimulationView` presentation opens mode selection.
- Locked partners remain visible and show a payment requirement.
- No payment SDK, checkout, subscription state, backend endpoint, or external navigation is added.
- Add only two focused automated tests, then run a compile verification.

---

### Task 1: Scenario partner access policy

**Files:**
- Modify: `SoulMark/SoulModels.swift`
- Test: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Produces: `ScenarioParticipantAccessPolicy.freeLimit: Int`, `isUnlocked(index: Int) -> Bool`, and `canAddParticipant(currentCount: Int) -> Bool`.

- [ ] **Step 1: Write the two failing policy tests**

```swift
@Test func scenarioParticipantPolicyRejectsThirdPersonByID() {
    let participantIDs = ["wren", "rhea", "owen"]
    #expect(ScenarioParticipantAccessPolicy.isUnlocked(participantID: "wren", in: participantIDs))
    #expect(!ScenarioParticipantAccessPolicy.isUnlocked(participantID: "owen", in: participantIDs))
}

@Test func scenarioParticipantPolicyStopsNewPeopleAtTwo() {
    #expect(ScenarioParticipantAccessPolicy.canAddParticipant(currentCount: 1))
    #expect(!ScenarioParticipantAccessPolicy.canAddParticipant(currentCount: 2))
}
```

- [ ] **Step 2: Run the focused tests and confirm they fail because the policy does not exist**

Run: `xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoulMarkTests/SoulMarkTests/scenarioParticipantPolicyRejectsThirdPersonByID -only-testing:SoulMarkTests/SoulMarkTests/scenarioParticipantPolicyStopsNewPeopleAtTwo`

Expected: compilation failure naming `ScenarioParticipantAccessPolicy`.

- [ ] **Step 3: Add the minimal policy**

```swift
enum ScenarioParticipantAccessPolicy {
    static let freeLimit = 2

    static func isUnlocked(index: Int) -> Bool {
        index >= 0 && index < freeLimit
    }

    static func canAddParticipant(currentCount: Int) -> Bool {
        currentCount < freeLimit
    }
}
```

- [ ] **Step 4: Re-run the two focused tests and confirm they pass**

- [ ] **Step 5: Commit the policy and tests**

```bash
git add SoulMark/SoulModels.swift SoulMarkTests/SoulMarkTests.swift
git commit -m "feat: limit free scenario partners"
```

### Task 2: Visible mode selection and locked partner presentation

**Files:**
- Modify: `SoulMark/ScenarioSimulationView.swift`

**Interfaces:**
- Consumes: `ScenarioParticipantAccessPolicy.isUnlocked(index:)` and `canAddParticipant(currentCount:)`.
- Produces: entry mode picker, persistent compact mode control, locked partner cells, and display-only upgrade sheet.

- [ ] **Step 1: Add presentation state and route all partner selection/add actions through quota checks**

Add `isShowingModePicker`, `isShowingUpgradePrompt`, and an initial-entry flag. Use participant array indices to determine whether selection is unlocked. When adding at two or more participants, present the upgrade prompt instead of the custom participant form.

- [ ] **Step 2: Replace the hidden mode submenu with a compact right-side mode control**

Overlay a narrow button showing `selectedMode.systemImage` and a shortened `selectedMode.displayTitle`. Tapping it opens the shared mode picker without changing the main vertical stack sizing.

- [ ] **Step 3: Add the shared mode picker**

Create `ScenarioModePickerSheet` in `ScenarioSimulationView.swift`. It renders all existing modes with selection state, selects and closes on tap, and exposes a custom-mode action that opens the existing `AddScenarioModeSheet`. Present it once when the view appears and whenever the compact control is tapped.

- [ ] **Step 4: Show quota state in the partner picker**

Pass an `isUnlocked` closure into `ScenarioParticipantPickerSheet`. Add lock and “需升级” treatment to locked cells; tapping a locked cell opens the display-only upgrade prompt. Keep every participant visible.

- [ ] **Step 5: Add the display-only upgrade prompt**

Create `ScenarioParticipantUpgradeSheet` with copy stating that the free plan supports two partners. Its “了解升级” and close controls only dismiss the sheet.

- [ ] **Step 6: Run the two focused tests and compile the app**

Run the focused test command from Task 1, then:

`xcodebuild build -project SoulMark.xcodeproj -scheme SoulMark -destination 'generic/platform=iOS Simulator'`

Expected: tests pass and build ends with `BUILD SUCCEEDED`.

- [ ] **Step 7: Review the diff and commit the UI**

```bash
git diff --check
git add SoulMark/ScenarioSimulationView.swift
git commit -m "feat: surface scenario modes and paid partner locks"
```
