# SoulMark Core UI Refresh Design

## Goal

Refresh the home, relationship map, scenario simulation, and profile achievement experiences as a lightweight SwiftUI prototype. All user-added people and progress remain in view state for the current app run only. No backend, persistence, payment SDK, or Apple in-app purchase integration is included.

## Product Constraints

- The relationship map starts empty.
- A free user can add up to five people during the current app run.
- Attempting to add a sixth person opens a membership upgrade placeholder instead of the add-person sheet.
- The placeholder explains the benefit and includes a disabled or simulated upgrade command; it performs no purchase.
- Existing theme, bilingual support, day/night appearance, tab navigation, relationship editing, person deletion, and scenario shortcuts remain available.
- Chinese and English copy must both remain understandable.

## Home

The first visible content below the page header is a daily "toxic chicken soup" quote. The quote uses a small curated bilingual list and is selected from the current calendar day so it can change daily without a backend. A system share action shares the quote plus the `SoulMark` name. Installed share extensions, including WeChat when available, are handled by the system share sheet.

The existing mascot hero remains directly below the quote. Its blue energy ring becomes brighter and more visible through a stronger, compact glow around the mascot image. The glow must not wash out nearby text or recreate the large profile-sheet highlight previously rejected by the user.

The relationship radar reads from the current relationship state. When empty, it shows a clear empty state with a command that opens the relationship map. Once people are added, it shows the strongest recent connections.

## Relationship Map

The sample people are removed from the initial app state. The empty map keeps the center identity node and shows an add-person prompt.

Relationship category controls are removed from the always-visible bottom area. The top-right ellipsis menu gains a "Relationship categories" command. Opening it presents the existing category filters, custom relationship creation, and relationship deletion controls in a compact sheet. The map itself stays visually focused.

Person labels are positioned on the side of each node facing away from the center identity node. Labels use a stable width and alignment so names remain peripheral and avoid the radial relationship line. Relationship type text remains offset beside, rather than directly on, its line.

The add button opens the existing add-person sheet while the graph contains fewer than five people. At five people it opens a membership placeholder. Deleting a person immediately restores one free slot.

## Scenario Simulation

The main screen is simplified into three visual layers: a minimal page header with history and overflow actions, a large open center stage reserved for the Soul mascot, and one prominent "Talk with AI" microphone button. Participant and mode selection move into the overflow menu or compact sheets. Guidance, history, custom participants, and custom modes remain accessible without occupying the default stage.

When no relationship people exist, AI conversation still works with a neutral built-in Soul persona. User-created scenario personas remain session-only and removable. Changing the participant or starting a new conversation clears the current transcript, preserving current behavior.

## Achievements

The Achievements row in Profile becomes a button that opens a dedicated sheet. The sheet displays a compact badge grid with locked and unlocked states.

Prototype achievement conditions are derived from current in-memory UI state:

- First Connection: add at least one person.
- Inner Circle: add five people.
- First Practice: complete or submit at least one scenario recording.
- Reflection Starter: create at least one conversation review.
- Clear Voice: complete three scenario practices.
- Relationship Explorer: use at least three relationship categories among added people.

Locked badges remain visible in grayscale with their exact unlock condition. Unlocked badges use the active blue or pink theme color and a clear illuminated state. The achievement sheet is bilingual.

## State And Data Flow

`ContentView` owns the session-level people array and prototype progress counters. It passes people into Home, Relationship Map, Scenario Simulation, and Profile. Child views communicate actions through small callbacks. No new storage service or observable backend model is introduced.

The scenario screen reports submitted recordings through a callback so `ContentView` can increment practice progress. The profile screen receives an achievement snapshot computed from people and counters. Review progress may use a prototype count supplied by `ContentView`; creating or deleting review records updates that count within the current app run.

## Error And Edge States

- Empty relationship state offers one clear add action.
- The sixth add attempt always opens the membership placeholder.
- Share uses the system share sheet; unavailable social apps simply do not appear.
- Long names are constrained to avoid overlapping nodes or lines.
- Empty scenario history and empty participant lists retain useful empty states.

## Verification

- Unit tests cover the five-person free limit, slot restoration after deletion, daily quote selection, share text branding, and achievement unlock rules.
- Existing relationship and scenario model tests remain passing after sample initial state is removed from app launch behavior.
- A code-signing-disabled iOS build verifies Swift compilation.
- SwiftUI previews or simulator screenshots are checked at a compact iPhone viewport to confirm that labels, the mascot, and the main AI button do not overlap.
