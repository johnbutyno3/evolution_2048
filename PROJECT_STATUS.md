# Rebirth 2048 — Project Status

Last updated: 2026-09-04

## 1. Current status

- Project: Rebirth 2048 / Evolution 2048
- Current branch: `feature/chapter1-spec-implementation`
- Latest game commit before this status document: `45a4b89`
- Onboarding: **completed and verified on Chrome**
- Current startup flow: **First launch → 3 onboarding pages → Game**
- The direct-to-game transition after onboarding is intentional for the current development stage.
- Final planned flow remains: **Onboarding → Personal Profile → Login/Register → Game**
- Windows desktop launch remains unresolved; Chrome is the current verification platform.

## 2. Confirmed game rules — authoritative

The following rules are the final rules and supersede older working notes or obsolete implementations.

### Chapters

| Chapter | Name | Tiers | Unlock target |
|---|---|---:|---:|
| 1 | Ocean | 12 | 2048 |
| 2 | Land | 13 | 4096 |
| 3 | Sky | 14 | 8192 |
| 4 | History | 15 | 16384 |
| 5 | Technology | 16 | 32768 |
| 6 | Universe | 17 | Ultimate challenge |

### Tools

- Chapters **1–6**: Undo
- Chapters **2–5**: Swap
- Chapter 2: Revive
- Chapter 3: Revive + Rewind
- Chapter 4: Revive + Rewind + Duplicate
- Chapter 5: Revive + Rewind + Duplicate
- Chapter 6: **Undo only**; all other tools disabled
- After reaching the chapter unlock target, the next chapter becomes available.
- A 4096 challenge can be chosen without restarting after 2048; challenge mode locks tools.
- Board: 4×4
- Core gameplay remains based on 2048 sliding and merging.
- Mobile input: swipe gestures; keyboard may remain for desktop testing.

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
- After completion, currently enters the game directly

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

## 6. Firebase / app setup

- Firebase configuration added.
- `lib/firebase_options.dart` added.
- Android Google Services configuration added.
- App icon assets/configuration updated for Android/iOS.

## 7. Verification

- `flutter analyze`: **No issues found** at the last verification.
- `git diff --check`: no whitespace errors; remaining LF→CRLF messages are Git line-ending warnings only.
- Chrome launch: **verified working**.
- Onboarding → direct game: **verified working**.

## 8. Current development priorities

### Next

1. Build Personal Profile screen.
2. Build Login / Register flow.
3. Connect Profile → Login/Register → Game flow.
4. Keep onboarding behavior unchanged unless a specific bug is found.

### Then

5. Complete and verify the final 6-chapter progression.
6. Align GameEngine target values and chapter data with the authoritative 6-chapter rules.
7. Implement and verify the exact tool layout for Chapters 1–6.
8. Complete Chapter 5 Technology and Chapter 6 Universe assets/data.
9. Verify chapter transition 4 → 5 and later transitions.
10. Return to Windows desktop launch/build issue after core game flow is stable.

## 9. Obsolete notes — do not use as current rules

Older saved working notes contain implementations with only Ocean/Land/Sky/History targets and older tool-display conditions. Those are historical implementation details and **must not override the final 6-chapter rules above**.
