# Rebirth 2048 — Single-Source Git Work Rules

Effective date: 2026-10-16

## 1. One source of truth

- The only authoritative project is `johnbutyno3/evolution_2048`.
- The only working branch is `feature/chapter1-spec-implementation`.
- GitHub on that branch is the source of truth. Do not use stale local files as the basis for a change.
- Do not create, switch to, or merge another branch.
- Do not create a backup project or duplicate repository. The user has removed the separate backup folder; do not recreate it or modify any similarly named backup repository.

## 2. Change direction

1. Inspect the current files on the authoritative GitHub branch.
2. Identify the cause and the smallest complete fix before writing.
3. Commit the fix directly to the existing branch.
4. Review the committed diff and affected call paths for regressions.
5. Tell the user the exact commit and files changed.
6. Have the local project fetch and reset to this branch only when ready to validate the committed version.
7. Run `flutter pub get`, `flutter analyze`, and `flutter test`; run relevant backend tests when backend files change.
8. If validation or runtime behavior fails, correct or revert the change on the same branch, then repeat validation.

## 3. No unverified claims

- Never claim a change passed tests unless those tests actually ran and their results are known.
- Static analysis and unit tests do not prove Firebase login, App Check, callable functions, Firestore permissions, purchases, membership, or life synchronization work end-to-end.
- Distinguish code inspection, automated test results, deployment status, and real-device/browser verification.
- Do not silently swallow a critical backend failure and present default values as authoritative account data.

## 4. Account and economy authority

- Firebase Auth identifies the signed-in account; restored authentication state must be resolved before routing.
- Gold, purchases, membership, and account permissions are server-authoritative. Never trust client-supplied balances or membership claims.
- Life and progression mutations must be transactionally validated by the backend. The client may optimistically update gameplay UI for responsiveness, but must reconcile to the server response and must not display an unverified default as confirmed state.
- If an authoritative response is invalid or contradicts a protected account entitlement, fail closed for the affected sensitive operation, record an auditable reason, and show a recoverable support path. Do not lock an account merely because of a transient network or service error.
- Ordinary network failure must not be misclassified as cheating or an authority mismatch.

## 5. Performance and correctness

- Keep gameplay interactions local-first where safe; do not block board animation on unrelated network reads.
- Use server transactions and idempotency for chargeable operations to prevent duplicate life deductions, duplicate purchases, and duplicate session creation.
- Guard asynchronous results against stale account/session state before publishing them.
- Errors affecting login, life, gold, membership, session creation, or progression must be visible and diagnosable; never hide them behind a plausible default.

## 6. Documentation and commits

- Keep this rule file on the same authoritative branch.
- Add timestamped progress/rules documents instead of overwriting historical archives when a dated archive is required.
- Commit and push project documents to Git first. Only then copy the committed version to the 2048 file library if requested.
- Keep commits focused, explain the behavior change, and never commit secrets, debug tokens, credentials, or generated dependency directories.
