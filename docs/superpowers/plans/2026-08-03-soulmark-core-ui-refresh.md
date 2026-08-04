# SoulMark Core UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a session-only SwiftUI prototype with a branded daily quote, brighter mascot focus, an empty five-person relationship map, simplified AI simulation stage, and functional achievement badges.

**Architecture:** Keep `ContentView` as the owner of session-level people and progress state. Add small pure policy/value types to `SoulModels.swift` so limits, quotes, graph label placement, fallback participant selection, and achievement unlocking are testable without UI inspection. Existing page files receive values and callbacks; no persistence, payment SDK, account service, or backend abstraction is added.

**Tech Stack:** SwiftUI, Swift Testing, Foundation, CoreGraphics, Xcode iOS build tooling.

## Global Constraints

- The relationship map starts empty and state lasts only for the current app run.
- Free relationship capacity is exactly five people.
- A sixth add attempt opens a membership placeholder; it performs no purchase.
- Existing Chinese/English localization, blue/pink theme, automatic day/night mode, tab navigation, relationship editing, person deletion, and scenario shortcuts remain usable.
- System sharing includes the `SoulMark` name and exposes installed extensions such as WeChat.
- No new third-party dependency is introduced.

---

### Task 1: Prototype Policies And Achievement Rules

**Files:**
- Modify: `SoulMark/SoulModels.swift`
- Test: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Produces: `FreeRelationshipPolicy.canAddPerson(currentCount: Int) -> Bool`
- Produces: `DailySoulQuote.quote(for: Date, calendar: Calendar) -> DailySoulQuote`
- Produces: `DailySoulQuote.shareText: String`
- Produces: `RelationshipLabelPlacement.layout(node:center:) -> RelationshipLabelLayout`
- Produces: `AchievementProgress` and `SoulAchievement.all(progress:)`
- Produces: `[ScenarioParticipant].withSoulFallback() -> [ScenarioParticipant]`

- [ ] **Step 1: Write failing policy, quote, fallback, label, and achievement tests**

```swift
@Test func freeRelationshipPolicyStopsAtFivePeople() {
    #expect(FreeRelationshipPolicy.canAddPerson(currentCount: 4))
    #expect(!FreeRelationshipPolicy.canAddPerson(currentCount: 5))
}

@Test func dailyQuoteShareTextIncludesBrandName() {
    let quote = DailySoulQuote.quote(for: Date(timeIntervalSince1970: 0))
    #expect(quote.shareText.contains("SoulMark"))
}

@Test func emptyParticipantListUsesSoulFallback() {
    #expect([ScenarioParticipant]().withSoulFallback().map(\.name) == ["Soul"])
}

@Test func labelsFaceAwayFromMapCenter() {
    let right = RelationshipLabelPlacement.layout(node: CGPoint(x: 0.8, y: 0.5), center: CGPoint(x: 0.5, y: 0.5))
    let left = RelationshipLabelPlacement.layout(node: CGPoint(x: 0.2, y: 0.5), center: CGPoint(x: 0.5, y: 0.5))
    #expect(right.horizontalDirection == 1)
    #expect(left.horizontalDirection == -1)
}

@Test func achievementsUnlockFromCurrentProgress() {
    let progress = AchievementProgress(peopleCount: 5, practiceCount: 3, reviewCount: 1, relationshipCategoryCount: 3)
    #expect(SoulAchievement.all(progress: progress).allSatisfy(\.isUnlocked))
}
```

- [ ] **Step 2: Run tests and verify missing-type failures**

Run: `xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .derivedData`

Expected: FAIL because the new policy and achievement types are not defined.

- [ ] **Step 3: Implement minimal pure model types**

```swift
enum FreeRelationshipPolicy {
    static let maximumPeople = 5
    static func canAddPerson(currentCount: Int) -> Bool { currentCount < maximumPeople }
}

struct AchievementProgress: Equatable {
    var peopleCount: Int
    var practiceCount: Int
    var reviewCount: Int
    var relationshipCategoryCount: Int
}
```

Add six curated bilingual `DailySoulQuote` values, deterministic calendar-day selection, branded share text, outward label geometry, a neutral `Soul` scenario fallback, and the six achievement definitions from the approved design.

- [ ] **Step 4: Run tests and verify all new model tests pass**

Run the Task 1 test command again.

Expected: PASS for all policy/value tests.

- [ ] **Step 5: Commit the model behavior**

```bash
git add SoulMark/SoulModels.swift SoulMarkTests/SoulMarkTests.swift
git commit -m "feat: add prototype limits quotes and achievements"
```

### Task 2: Empty Relationship State And Five-Person Gate

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/RelationshipGraphViews.swift`

**Interfaces:**
- Consumes: `FreeRelationshipPolicy.canAddPerson(currentCount:)`
- Produces: `MembershipUpgradeSheet`
- Produces: `RelationshipMapView.onAddPerson: () -> Void`

- [ ] **Step 1: Change launch state to an empty people array**

Replace `@State private var people = RelationshipSampleData.people` with an empty typed array. Keep sample data available only for tests and previews.

- [ ] **Step 2: Gate both header and empty-state add commands**

Route both commands through one `requestAddPerson()` method:

```swift
private func requestAddPerson() {
    if FreeRelationshipPolicy.canAddPerson(currentCount: people.count) {
        isAddingPerson = true
    } else {
        showingMembershipUpgrade = true
    }
}
```

- [ ] **Step 3: Add the membership placeholder sheet**

Create a bilingual sheet with the five-person usage count, membership benefits, a clearly labeled simulated upgrade button, and a close command. The upgrade button only dismisses or remains informational; it must not mutate entitlement state.

- [ ] **Step 4: Add a useful empty graph prompt**

When `people.isEmpty`, keep `CenterProfile` visible and add one compact `person.badge.plus` command below it. Do not render radial lines or stale sample labels.

- [ ] **Step 5: Build to catch callback and sheet errors**

Run: `xcodebuild -project SoulMark.xcodeproj -scheme SoulMark -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit empty-state and limit UI**

```bash
git add SoulMark/ContentView.swift SoulMark/RelationshipGraphViews.swift
git commit -m "feat: add empty relationship map and free limit"
```

### Task 3: Daily Quote And Dynamic Home Radar

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/HomeProfileViews.swift`
- Modify: `SoulMark/SoulTheme.swift`

**Interfaces:**
- Consumes: `[RelationshipPerson]`
- Consumes: `DailySoulQuote.quote(for:)`
- Produces: `IntegratedHomePage(people:onOpenRelationshipGraph:onOpenScenario:onOpenJournal:)`

- [ ] **Step 1: Pass live people state into Home**

Add `let people: [RelationshipPerson]` to `IntegratedHomePage` and pass the `ContentView.people` array.

- [ ] **Step 2: Insert quote as the first content card**

Place the quote immediately after `SoulPageHeader`. Show the localized quote, a small `DAILY DOSE` marker, and a `ShareLink` using `quote.shareText`. Use a familiar share icon and accessibility label.

- [ ] **Step 3: Brighten the compact mascot halo**

Extend `SoulMascotFigure` with `var haloIntensity: CGFloat = 1`. Use two compact blue/energy shadows with radii no greater than 20 points. Apply the brighter intensity only to the Home hero mascot.

- [ ] **Step 4: Replace hard-coded radar people**

Sort live people by strength and render at most three. For zero people, show a short empty message plus a command that opens the relationship map.

- [ ] **Step 5: Build and inspect compact layouts**

Run the generic iOS build and inspect Home previews in Chinese and English at an iPhone compact width. Confirm the quote is visible before the hero and the halo does not reduce text contrast.

- [ ] **Step 6: Commit Home improvements**

```bash
git add SoulMark/ContentView.swift SoulMark/HomeProfileViews.swift SoulMark/SoulTheme.swift
git commit -m "feat: add branded daily dose to home"
```

### Task 4: Collapsed Relationship Categories And Peripheral Labels

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/RelationshipGraphViews.swift`

**Interfaces:**
- Consumes: `RelationshipLabelPlacement.layout(node:center:)`
- Produces: `RelationshipHeader.onOpenCategories: () -> Void`
- Produces: `RelationshipCategoriesSheet`

- [ ] **Step 1: Move filters behind the ellipsis menu**

Add a bilingual `Relationship categories` menu command. Store `showingRelationshipCategories` in `ContentView` and present the current `RelationshipFilterBar` inside a medium sheet. Remove it from the always-visible graph overlay.

- [ ] **Step 2: Preserve category add and delete actions**

Keep custom relationship creation and all relationship deletion callbacks connected from the sheet. Selecting a filter dismisses the category sheet and clears the selected person.

- [ ] **Step 3: Apply outward node label geometry**

Calculate horizontal direction from each normalized node position relative to the center. Put the avatar at the node point and offset the name/note block by at least half the avatar width plus 8 points away from the center. Right-side labels use leading alignment; left-side labels use trailing alignment.

- [ ] **Step 4: Verify relationship text remains beside lines**

Keep the current perpendicular line-label offset and increase the background opacity only enough for contrast. Do not place text directly over the radial stroke.

- [ ] **Step 5: Run model tests and generic build**

Expected: outward-placement tests PASS and BUILD SUCCEEDED.

- [ ] **Step 6: Commit category and label layout**

```bash
git add SoulMark/ContentView.swift SoulMark/RelationshipGraphViews.swift
git commit -m "feat: simplify relationship map controls"
```

### Task 5: Minimal AI Conversation Stage

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/ScenarioSimulationView.swift`

**Interfaces:**
- Consumes: `[ScenarioParticipant].withSoulFallback()`
- Produces: `ScenarioSimulationView(relationshipPeople:focusedPersonID:onPracticeSubmitted:)`

- [ ] **Step 1: Add practice submission callback**

Call `onPracticeSubmitted(submittedSeconds)` only after the green confirmation command returns a positive recording duration. Cancel continues to reset without incrementing progress.

- [ ] **Step 2: Collapse participant and mode controls**

Remove the persistent participant rail, mode chips, guidance preview, and oversized control card from the default stage. Keep their existing sheets reachable from the header overflow menu.

- [ ] **Step 3: Build the open mascot stage**

Use a large flexible `Spacer`, centered `SoulMascotFigure`, one short current-context line, and one prominent circular microphone command labeled `Talk with AI`. The transcript can slide or scroll above the control only after messages exist.

- [ ] **Step 4: Keep history and conversation clearing behavior**

History remains in the top-left. Participant changes and New Conversation clear the transcript and reset the recording timer. An empty relationship map uses the neutral Soul participant.

- [ ] **Step 5: Run timer, fallback, and history tests plus build**

Expected: existing recording reset/history tests and the fallback test PASS; generic iOS BUILD SUCCEEDED.

- [ ] **Step 6: Commit simulation simplification**

```bash
git add SoulMark/ContentView.swift SoulMark/ScenarioSimulationView.swift
git commit -m "feat: simplify AI simulation stage"
```

### Task 6: Clickable Achievement Badge Sheet

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/HomeProfileViews.swift`

**Interfaces:**
- Consumes: `AchievementProgress`
- Consumes: `[SoulAchievement]`
- Produces: `IntegratedProfilePage(achievementProgress:)`
- Produces: `AchievementsSheet`

- [ ] **Step 1: Track prototype progress in ContentView**

Add session-only `practiceCount` and `reviewCount` integers. Compute unique relationship category count from `people`. Pass one `AchievementProgress` value to Profile.

- [ ] **Step 2: Make the Achievements row an actual button**

Extend `SoulMenuRow` with an optional action or wrap the achievement row in a plain button. Open `AchievementsSheet` while leaving the other account menu rows unchanged.

- [ ] **Step 3: Render locked and unlocked badges**

Use a two-column grid. Unlocked badge symbols use `SoulTheme.accent` and `SoulTheme.energy` with a compact glow. Locked badges use desaturated fills, a lock overlay, and the exact localized unlock requirement.

- [ ] **Step 4: Keep achievement progress current**

Submitting scenario practice immediately updates First Practice and Clear Voice. Adding/deleting people immediately updates First Connection, Inner Circle, and Relationship Explorer. The prototype Reflection Starter reads the session review count.

- [ ] **Step 5: Run achievement tests and generic build**

Expected: all achievement rule tests PASS and BUILD SUCCEEDED.

- [ ] **Step 6: Commit achievements UI**

```bash
git add SoulMark/ContentView.swift SoulMark/HomeProfileViews.swift
git commit -m "feat: add interactive achievement badges"
```

### Task 7: Full Regression And Visual Verification

**Files:**
- Verify: `SoulMarkTests/SoulMarkTests.swift`
- Verify: all modified Swift source files

**Interfaces:**
- Consumes: completed Tasks 1-6.
- Produces: verified prototype build.

- [ ] **Step 1: Run the full unit test suite**

Run: `xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .derivedData`

Expected: zero test failures. If the local simulator service is unavailable, report that environment failure separately and still run the generic build.

- [ ] **Step 2: Run the code-signing-disabled generic iOS build**

Run: `xcodebuild -project SoulMark.xcodeproj -scheme SoulMark -destination 'generic/platform=iOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Review the final diff and requirement checklist**

Confirm the diff excludes `SoulMark.xcodeproj/project.pbxproj` signing changes and includes all six approved product requirements. Confirm no persistence or purchase integration was introduced.

- [ ] **Step 4: Inspect compact iPhone Home, Map, Scenario, and Achievement screens**

Check Chinese and English text at compact width. Confirm no overlap between graph labels and lines, the daily quote appears on first view, the Home halo is visible, the Scenario stage is mostly open space, and locked badges are readable.

- [ ] **Step 5: Commit any verification-only corrections**

```bash
git add SoulMark SoulMarkTests
git commit -m "fix: polish refreshed prototype layouts"
```
