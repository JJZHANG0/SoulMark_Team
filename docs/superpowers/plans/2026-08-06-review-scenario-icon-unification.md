# Review Scenario Icon Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every scenario-practice icon in Review match the bottom navigation simulation icon.

**Architecture:** Keep `ReviewSource.systemImage` as the single icon source. Change only its `.scenario` mapping so all existing Review consumers update consistently.

**Tech Stack:** Swift, SwiftUI, SF Symbols

## Global Constraints

- Use `waveform.and.mic` for `ReviewSource.scenario`.
- Do not change layout, colors, interactions, or other review-source icons.

---

### Task 1: Unify the scenario icon

**Files:**
- Modify: `SoulMark/SoulModels.swift:689`

**Interfaces:**
- Consumes: `ReviewSource.systemImage: String`
- Produces: `.scenario` mapping to `waveform.and.mic`

- [ ] **Step 1: Change the scenario mapping**

```swift
case .scenario: "waveform.and.mic"
```

- [ ] **Step 2: Verify syntax and scope**

Run: `xcrun swiftc -frontend -parse SoulMark/SoulModels.swift`

Run: `git diff --check`

Expected: both commands exit successfully and the only production change is the scenario icon string.
