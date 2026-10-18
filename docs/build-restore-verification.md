# Build restore verification (2026-10-18)

> **Verified on an emulator only. Not yet verified on a physical device (Galaxy S26 Ultra / S22 Ultra).**

## Environment

- Branch `build-restore`, Flutter 3.47.7 (Dart 3.13.5), JDK 17, Gradle 8.14.3, AGP 8.13.0, Kotlin 2.3.20, NDK 28.2.13676358
- Build: `flutter build apk --debug --flavor dev --target-platform android-arm64`
- Emulator: Android Studio AVD `Medium_Phone_API_37.0` (Android 17 / API 37, x86_64 with arm64-v8a translation, 1080x2400, gesture navigation)
  - The committed arm64-v8a-only APK installed and ran as-is through ARM translation. No x86_64 build was needed.
  - The API 36 AVD (`system-images;android-36;google_apis;x86_64`) crashed during emulator startup on this PC, so testing used API 37.
- Installed flavor: dev only (`uk.co.tdsstudios.noterly.dev`, label "Noterly Dev")
- Production flavor: APK build only (`uk.co.tdsstudios.noterly`, minSdk 36, arm64-v8a). Not installed anywhere.

## Checklist

| Item | Emulator (API 37) | S26 Ultra | S22 Ultra |
|---|---|---|---|
| App launch | Pass | Not verified | Not verified |
| First-launch dialog | Not shown (expected, see note 1) | Not verified | Not verified |
| Notification permission (POST_NOTIFICATIONS) prompt | Pass (prompt shown, granted) | Not verified | Not verified |
| Immediate notification | Pass (Mark as done / Snooze buttons shown) | Not verified | Not verified |
| Scheduled notification with app closed | Pass (process killed, scheduled 07:35, arrived 07:35:05; USE_EXACT_ALARM granted automatically) | Not verified | Not verified |
| Snooze action | Pass (exact alarm registered for +60 min) | Not verified | Not verified |
| Mark as done action (background) | Pass (archived with app process killed) | Not verified | Not verified |
| Bottom tab labels distinct (#33) | Pass (Active / Archive) | Not verified | Not verified |
| Edge-to-edge: tabs/FAB not covered by navigation bar | Pass (gesture navigation) | Not verified | Not verified |
| Back gesture | Pass (Settings → Main → Home) | Not verified | Not verified |
| Translations | Pass (per-app locale de-DE: Aktiv / Archiv / Neue Notiz) | Not verified | Not verified |
| Data persists across process kill | Pass | Not verified | Not verified |

Notes
1. `BuildInfo` is `UNSET_VERSION/UNSET_BRANCH` (inDev) for plain `flutter build`, and `main_page.dart` skips the first-launch dialog for inDev builds. Settings shows "inDev release UNSET_VERSION (UNSET_BRANCH)".
2. Relative times ("2 minutes ago") stay in English when the app language is German (jiffy locale is not set). Candidate for a separate fix.
3. No Korean translation exists (de, el, en, es, fr, it, pl, ru, uk only).

## Needs a human on the real devices

- Predictive back: whether the back-preview animation looks right (only navigation was checked on the emulator)
- Edge-to-edge with One UI's 3-button navigation bar, if used
- Scheduled notifications under One UI battery settings (Settings > Battery > Background usage limits); record which list the app is in
- Notification sound/vibration and heads-up appearance on One UI
- Everything in the S26 Ultra / S22 Ultra columns above
