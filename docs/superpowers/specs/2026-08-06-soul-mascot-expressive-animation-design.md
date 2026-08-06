# Soul IP Expressive Animation Design

## Goal

Make Soul's existing scenario-simulation animation clearly visible while preserving its calm, supportive personality. Both realtime voice and typed conversations must communicate listening, thinking, and responding through motion.

## Scope

- Keep the existing SwiftUI-driven mascot image and visor-light architecture.
- Increase motion amplitude to a "clearly visible but natural" level.
- Preserve the existing idle, listening, thinking, emotion-aware speaking, and failed states.
- Add animation-state sequencing to typed conversations.
- Preserve iOS Reduce Motion behavior.
- Add focused automated tests for state sequencing and motion amplitude.

## Motion Design

The mascot remains centered and uses coordinated offset, rotation, and scale rather than skeletal or frame-by-frame animation.

- **Idle:** approximately 5 points of vertical travel, up to 0.7 degrees of rotation, and about 0.8% breathing scale.
- **Listening:** a roughly 2-degree attentive lean with a small nod and subtle scale response.
- **Thinking:** a slow side-to-side drift and up to roughly 2.5 degrees of rotation; the visor scan remains the strongest visual cue.
- **Speaking — calm:** approximately 4 points of vertical response and up to 1.5 degrees of rotation.
- **Speaking — happy:** approximately 6–7 points of vertical response, up to 3 degrees of rotation, and a brighter energetic visor.
- **Speaking — caring:** a gentle lean and approximately 3 points of slow vertical movement.
- **Speaking — serious:** restrained but still visible motion, approximately 2 points and up to 0.6 degrees.
- **Speaking — encouraging:** approximately 5–6 points of movement and up to 2.2 degrees of rotation.
- **Failed:** stable posture with warning-colored visor feedback.

Exact constants may be tuned within these ranges during visual verification, but the relative personality of each state must remain intact.

## Typed Conversation State Flow

Typed messages currently append an immediate local response and leave the mascot idle. Replace that visual behavior with an explicit, testable state sequence:

1. The user submits non-empty text.
2. The mascot enters `thinking` immediately.
3. After a short deliberate pause, Soul's existing response is appended and the mascot enters `speaking(.calm)`.
4. After a short response beat, the mascot returns to `idle`.

Only one typed animation sequence may own the mascot at a time. Starting a new typed message cancels the previous pending sequence. Starting realtime voice, switching participants or modes, resetting the conversation, leaving the screen, or ending the interaction cancels typed animation and returns its state to idle. Realtime voice state always takes priority while active or failed.

## Architecture

- Extract mascot motion calculation from the private view-only implementation into an internal, pure model that tests can inspect.
- Add a small typed-conversation animation phase/state model with deterministic transitions.
- Keep view rendering in `ScenarioSimulationView`; it selects realtime voice state when appropriate and otherwise uses the typed-conversation animation state.
- Keep the existing `TimelineView` rendering and visor overlay.

No new package or media dependency is required.

## Accessibility

When Reduce Motion is enabled, continuous timeline movement remains paused. State changes may update the static pose and visor appearance, but no looping displacement or pulsing is introduced.

## Testing

Automated tests must verify:

- Every interactive state has a materially larger motion envelope than the previous subtle implementation.
- Serious and caring states remain less energetic than happy and encouraging states.
- Typed submission transitions through thinking, speaking, and idle in order.
- Cancellation prevents stale delayed responses or state transitions from taking control.
- Existing realtime phase-to-mascot mapping remains correct.

Build and test the iOS target after implementation. Visual inspection should confirm that motion is noticeable at the active 175-point mascot size without appearing erratic.

## Out of Scope

- New character artwork, spritesheets, video, Lottie, Rive, or skeletal animation.
- Backend response generation changes.
- Sound-effect or haptic design.
- Animation changes outside the scenario-simulation screen.
