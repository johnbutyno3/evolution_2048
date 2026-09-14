# Game Session Security

## Purpose

Chapter completion is server-authoritative. A gameplay attempt is bound to a server-created game session, and completion is submitted using the session's replay log instead of trusting client-reported final score or highest-value fields.

This document defines the game-session anti-cheat layer without changing the gameplay rules.

## Rules

1. A gameplay session must be created by the authenticated server before a chapter attempt is considered valid.
2. The server records the chapter, target value, session start time, and a random session identifier.
3. A client may submit a completion only for its own active session.
4. A session can be completed once only.
5. The server rejects a chapter index outside `0..5`.
6. The server rejects a target result that does not match the chapter's configured target.
7. The server validates the submitted replay log and rejects malformed or impossible gameplay data.
8. The server records suspicious completion attempts in `security_events`.
9. The server remains the authority for chapter unlock state; the client never writes `progress/game` directly.
10. This layer must not trust a client-provided timestamp, reward amount, Gold amount, membership state, or chapter unlock index.

## Current Callable API

### `startGameSession({chapterIndex})`

- authenticates the user
- validates the chapter
- creates a random `sessionId`
- records the server start timestamp
- stores the active session under `users/{uid}/game_sessions/{sessionId}`

### `useTool({sessionId, toolType})`

- requires the authenticated user's active game session
- binds tool usage to the current `sessionId`
- validates the requested tool
- updates the server-side tool-use state according to the authoritative rules

### `completeChapter({sessionId, chapterIndex, replayLog})`

- validates ownership and active status
- validates the chapter
- validates the session has not already completed
- validates the submitted replay log
- marks the session completed atomically
- updates server-authoritative chapter progress
- records suspicious requests

## Client Integration

The Flutter client exposes the active game session through `PlayerProgressService.activeGameSessionId`.

Tool usage sends the active `sessionId` to `useTool`.

Chapter completion obtains the engine-generated `replayLog` and submits that log together with the existing session and chapter index.

The completion flow does not create a second session when the active session already exists.

## Important Limitation

A replay log is stronger than trusting only a client-reported final score or highest value, but a client-generated log is still not equivalent to independently observing every physical input.

Stronger validation can be added later using server-issued move commands, deterministic state validation, or additional signed/session-bound event data.

The current implementation therefore focuses on preventing forged chapter completion, replayed completion, cross-account session reuse, invalid chapter results, and malformed/impossible replay data without rewriting the game engine.
