# Scenario Mascot Emotion Animation Design

## Goal

Give the existing SoulMark IP character restrained, emotionally legible motion during realtime scenario conversations. Body movement stays subtle; the visor light is the primary emotional display.

## Scope

- Enable full animation only in the scenario simulation conversation screen.
- Keep existing mascot usage on Home, Profile, and Authentication static.
- Reuse the existing `SoulMascot` image without redrawing or replacing the IP.
- Preserve interruption behavior and realtime audio latency.

## Interaction States

### Idle

- Slow vertical breathing motion.
- Low-intensity cyan visor pulse.
- No abrupt or repeating decorative movement.

### Listening

- Activate while the user is speaking and while the realtime session is ready for input.
- Move the body forward slightly and reduce general movement.
- Narrow the visor light and animate a slow directional flow to communicate attention.

### Thinking

- Use between completed user input and the start of the assistant response when that boundary is available.
- Keep the body almost still.
- Run one restrained visor scan from side to side.

### Speaking

- Use small nods and a low-amplitude breathing rhythm.
- Vary visor brightness with a controlled repeating speech pulse.
- Apply the emotion supplied by the server:
  - `calm`: cyan, balanced pulse, minimal nod.
  - `happy`: soft cyan-green, slightly lifted posture, brief brighter curved visor.
  - `caring`: warmer cyan, slower pulse, slight side tilt.
  - `serious`: darker narrow visor, stable posture, reduced movement.
  - `encouraging`: one subtle upward motion and light expansion, then normal speaking motion.

### Interruption and Failure

- User interruption immediately cancels the speaking animation and transitions to listening.
- Failed connections return the body to idle and use a low-intensity warning visor state without continuous flashing.
- Unknown, missing, or invalid emotion values fall back to `calm` and never block audio.

## Motion Constraints

- Translation: approximately 1–4 points.
- Rotation: approximately 1–2 degrees.
- Scale variation: subtle enough to avoid visible image blur or layout movement.
- Animate within the mascot's existing frame so surrounding controls never shift.
- Respect Reduce Motion by removing continuous body transforms and retaining only low-frequency visor opacity changes.

## Architecture

### Shared animation model

Add a small scenario-only presentation model that maps realtime call phase and server emotion into:

- `idle`
- `listening`
- `thinking`
- `speaking(ScenarioEmotion)`
- `failed`

`ScenarioEmotion` accepts the five supported server values and decodes unknown values as `calm`.

### Realtime protocol

Send an optional `assistant.emotion` event as soon as the first meaningful assistant transcript fragment is available. The response starts in `calm`, then the backend derives a supported emotion from the assistant's own words and updates the animation during the opening phrase. Existing clients remain compatible because the new event is optional.

The client enters calm speaking state when `assistant.response_started` arrives and applies `assistant.emotion` when available. Audio playback, transcript delivery, and interruption messages keep their existing behavior.

### Animated mascot view

Keep `SoulMascotFigure` unchanged for existing static call sites. Add a scenario-specific wrapper that:

- renders the existing mascot image;
- applies restrained whole-body transforms within a fixed frame;
- overlays a visor light aligned proportionally to the source image;
- changes visor color, width, glow, curve, and pulse timing from animation state;
- stops timers and repeating animations when inactive or off-screen.

## Data Flow

1. User speech sets the realtime phase to listening.
2. Backend completes input processing and prepares the assistant response.
3. Backend emits response start; the client begins with calm speaking motion.
4. The first meaningful assistant transcript fragment produces an optional `assistant.emotion` event.
5. Realtime manager publishes speaking phase plus decoded emotion.
6. Scenario screen derives a mascot animation state.
7. Animated mascot transitions without affecting the audio pipeline.
8. Interruption or response completion immediately moves the mascot back to listening.

## Error Handling

- Missing emotion: use `calm`.
- Unsupported emotion: use `calm`.
- Event received out of order: realtime call phase has priority over emotion.
- Disconnected session: use failed briefly, then idle when dismissed or cleared.
- Reduced Motion enabled: disable body loops and scanning; retain static state colors and gentle opacity feedback.

## Verification

Keep verification focused to conserve test budget:

- Unit test server-emotion decoding and unknown-value fallback.
- Unit test realtime-phase-to-animation-state mapping, including interruption priority.
- Add one backend test that response-start events contain a supported emotion or omit it safely.
- Run one app compile check and the targeted tests only; do not run the full UI suite.

## Acceptance Criteria

- The character visibly idles before a call without large movement.
- The character shows attentive listening while the user speaks.
- The character expresses the response emotion while AI audio is playing.
- The visor is the strongest emotional cue and remains aligned at supported scenario sizes.
- User interruption changes the character to listening immediately.
- Unknown emotion data cannot break or delay the conversation.
- Other pages retain their current mascot appearance.
