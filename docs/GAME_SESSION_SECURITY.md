# Game Session Security

## Purpose

Chapter completion is server-authoritative, but the client currently reports the final `chapterIndex`, `highestValue`, and `score`. This document defines the next anti-cheat layer without changing the gameplay rules.

## Rules

1. A gameplay session must be created by the authenticated server before a chapter attempt is considered valid.
2. The server records the chapter, target value, session start time, and a random session identifier.
3. A client may submit a completion only for its own active session.
4. A session can be completed once only.
5. The server rejects a chapter index outside `0..5`.
6. The server rejects a target result that does not match the chapter's configured target.
7. The server rejects impossible or negative score values.
8. The server records suspicious completion attempts in `security_events`.
9. The server remains the authority for chapter unlock state; the client never writes `progress/game` directly.
10. This layer must not trust a client-provided timestamp, reward amount, Gold amount, membership state, or chapter unlock index.

## Planned callable API

- `startGameSession({chapterIndex})`
  - authenticates the user
  - validates the chapter
  - returns a random `sessionId`
  - records the server start timestamp
  - stores the active session under `users/{uid}/game_sessions/{sessionId}`

- `completeChapter({sessionId, chapterIndex, highestValue, score})`
  - validates ownership and active status
  - validates chapter and target
  - validates the session has not already completed
  - marks the session completed atomically
  - updates server-authoritative chapter progress
  - records suspicious requests

## Important limitation

A session token alone cannot prove that a client genuinely performed every 2048 move. Stronger validation can be added later using server-issued move commands or a deterministic move/event log. The first implementation therefore focuses on preventing forged chapter completion, replayed completion, cross-account session reuse, and impossible result values without rewriting the game engine.
