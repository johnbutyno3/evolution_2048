# Rebirth 2048 — Project Status

Last updated: 2026-09-07

## 1. Current status

- Project: Rebirth 2048 / Evolution 2048
- Current branch: `feature/chapter1-spec-implementation`
- Latest confirmed game/auth commit: `7dbeca6`
- Onboarding: **completed and verified on Chrome**
- Startup flow: **First launch → 3 onboarding pages → Personal Profile → Login/Register → Game**
- Windows desktop launch remains unresolved; Chrome is the current verification platform.

## 2. Confirmed game rules — authoritative

The current implementation is the source of truth for tool behavior. Do not change the following tool distribution unless explicitly decided later.

### Chapters

| Chapter | Name | Tiers | Unlock target |
|---|---|---:|---:|
| 1 | Ocean | 12 | 2048 |
| 2 | Land | 13 | 4096 |
| 3 | Sky | 14 | 8192 |
| 4 | History | 15 | 16384 |
| 5 | Technology | 16 | 32768 |
| 6 | Universe | 17 | Ultimate challenge |

### Tools — current implementation

- Chapter 1 Ocean: **UNDO**
- Chapter 2 Land: **UNDO + SWAP**
- Chapter 3 Sky: **UNDO + SWAP + REVIVE**
- Chapter 4 History: **UNDO + SWAP + REVIVE + DUPLICATE**
- Chapter 5 Technology: **UNDO + SWAP + REVIVE + DUPLICATE**
- Chapter 6 Universe: **UNDO**
- `UNDO` is currently implemented internally as `timeRewind`.
- Tools currently use unlimited uses in the active development/test configuration.
- Board: 4×4
- Core gameplay remains based on 2048 sliding and merging.
- Mobile input: swipe gestures; keyboard may remain for desktop testing.

### Tool behavior currently implemented

- UNDO: restores the previous valid move state.
- SWAP: swaps two occupied tiles.
- REVIVE: removes one selected tile.
- DUPLICATE: copies a selected tile into an empty position.
- Tool actions apply their existing score penalties.
- Chapter 6 has only UNDO; other tools are disabled.

## 3. Chapter 1 — final 12-tier sequence

1. 2 — 矽藻
2. 4 — 鞭毛蟲
3. 8 — 磷蝦
4. 16 — 小丑魚
5. 32 — 水母
6. 64 — 魷魚
7. 128 — 海龜
8. 256 — 黃鰭鮪魚
9. 512 — 鯊魚
10. 1024 — 虎鯨
11. 2048 — 藍鯨
12. 4096 — 海底人類

Do not restore the older 18-tier Chapter 1 list.

## 4. Asset progress

### Onboarding — complete

Exactly 3 images:

- `assets/onboarding/onboarding_01.png`
- `assets/onboarding/onboarding_02.png`
- `assets/onboarding/onboarding_03.png`

Requirements implemented:

- Vertical 9:16 images
- Localized title and description overlays
- Next / Start controls localized
- Page indicators
- First-launch-only behavior using `SaveManager`
- After completion, enters Personal Profile

### Chapter backgrounds

- Chapter 1 Ocean: 4 gameplay backgrounds + chapter complete image — present
- Chapter 2 Land: 4 gameplay backgrounds + chapter complete image — present
- Chapter 3 Sky: 4 gameplay backgrounds + chapter complete image — present
- Chapter 4 History: 4 gameplay backgrounds + chapter complete image — present
- Chapter 5 Technology: background/creature assets are in progress
- Chapter 6 Universe: not yet completed

Gameplay backgrounds are intended to fill the 4×4 board area; chapter-complete images are separate and must not contain option/text overlays.

## 5. Localization — complete foundation

- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- Generated localization files updated
- Onboarding strings are localized
- Avoid hardcoded Chinese UI text in new code.

## 6. Firebase / authentication

- Firebase configuration added.
- `lib/firebase_options.dart` added.
- Email/password authentication implemented.
- Google authentication implemented.
- Apple authentication implemented.
- Phone/SMS authentication implemented.
- Temporary Skip option remains for testing.
- Real provider configuration still requires Firebase Console/platform setup.

## 7. Verification

- `flutter analyze`: **No issues found** at the last verification.
- `git diff --check`: no whitespace errors.
- Chrome launch: **verified working**.
- Onboarding → Profile → Login/Register → Game flow: implemented.
- GitHub and local development baseline were synchronized at commit `7dbeca6`.

## 8. Current development priorities

### Next

1. Verify the actual tool UI/layout against the current tool distribution above.
2. Complete and verify the final 6-chapter progression.
3. Align GameEngine target values and chapter progression with the authoritative chapter rules.
4. Verify chapter transitions, especially 4 → 5 → 6.
5. Complete Chapter 5 Technology and Chapter 6 Universe assets/data.
6. Remove or retain debug chapter-complete controls based on final testing needs.
7. Run full Chrome gameplay verification.
8. Return to Windows desktop launch/build issue after core game flow is stable.

## 9. Important implementation notes

- Current tool distribution in `lib/game/services/tool_manager.dart` is authoritative for the next development stage.
- Do not add REVIVE to Chapter 2 unless explicitly requested; the current implementation is intentional.
- Do not rename the internal `timeRewind` type merely for naming cleanup unless the gameplay behavior is also being changed.
- Do not restore obsolete 4-chapter or older tool rules.
