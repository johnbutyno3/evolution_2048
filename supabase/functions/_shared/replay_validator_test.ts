import { allowedToolsForChapter, replayGame, MAX_EVENTS } from "./replay_validator.js";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function expectThrows(run: () => unknown, message: string): void {
  let threw = false;
  try {
    run();
  } catch {
    threw = true;
  }
  assert(threw, message);
}

const initialTiles = [2, 2, null, null, null, null, null, null, null, null, null, null, null, null, null, null];

Deno.test("replay validator rejects a mismatched server-bound initial board", () => {
  const replayLog = { version: 1, chapter: "ocean", initialTiles, events: [] };
  const expected = [null, 2, 2, ...Array(13).fill(null)];
  expectThrows(() => replayGame({
    replayLog,
    chapterIndex: 0,
    targetValue: 4096,
    expectedInitialTiles: expected,
    requireCompletion: false,
  }), "Expected initial board mismatch to be rejected.");
});

Deno.test("replay validator rejects incomplete chapter completion", () => {
  const replayLog = { version: 1, chapter: "ocean", initialTiles, events: [] };
  expectThrows(() => replayGame({
    replayLog,
    chapterIndex: 0,
    targetValue: 4096,
    expectedInitialTiles: initialTiles,
    requireCompletion: true,
  }), "An incomplete replay must not be accepted as chapter completion.");
});

Deno.test("replay validator rejects more than the event limit", () => {
  const replayLog = {
    version: 1,
    chapter: "ocean",
    initialTiles,
    events: Array(MAX_EVENTS + 1).fill({ type: "unknown" }),
  };
  expectThrows(() => replayGame({
    replayLog,
    chapterIndex: 0,
    targetValue: 4096,
    expectedInitialTiles: initialTiles,
    requireCompletion: false,
  }), "Replay event limit must be enforced.");
});

Deno.test("chapter tool permissions remain restricted", () => {
  assert(
    JSON.stringify(allowedToolsForChapter(0)) === JSON.stringify(["timeRewind"]),
    "C1 must only allow UNDO.",
  );
  assert(
    JSON.stringify(allowedToolsForChapter(2)) ===
      JSON.stringify(["timeRewind", "revive", "positionSwap"]),
    "C3 must allow UNDO, REMOVE and SWAP.",
  );
});

Deno.test("replay validator rejects missing initial tiles with a validation error", () => {
  const replayLog = { version: 1, chapter: "ocean", events: [] };
  let message = "";
  try {
    replayGame({
      replayLog,
      chapterIndex: 0,
      requireCompletion: false,
    });
  } catch (error) {
    message = error instanceof Error ? error.message : "";
  }
  assert(
    message === "Initial board must contain exactly 16 cells.",
    "Missing initial tiles must produce a controlled validation error.",
  );
});

Deno.test("replay validator rejects non-array initial tiles", () => {
  const replayLog = {
    version: 1,
    chapter: "ocean",
    initialTiles: { 0: 2, 1: 2 },
    events: [],
  };
  expectThrows(() => replayGame({
    replayLog,
    chapterIndex: 0,
    requireCompletion: false,
  }), "Non-array initial tiles must be rejected.");
});
