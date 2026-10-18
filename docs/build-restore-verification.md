# Build restore verification (2026-10-18)

> **Verified on an emulator only. Not yet verified on a physical device (Galaxy S26 Ultra / S22 Ultra).**
>
> Decision (2026-10-18): because the physical devices cannot be used for every test, verification is done on the Android emulator. Items that only a physical device can confirm are listed at the end of each section.

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
3. Korean translation is intentionally not added (user decision). Shipped languages: de, el, en, es, fr, it, pl, ru, uk.

## Needs a human on the real devices

- Predictive back: whether the back-preview animation looks right (only navigation was checked on the emulator)
- Edge-to-edge with One UI's 3-button navigation bar, if used
- Scheduled notifications under One UI battery settings (Settings > Battery > Background usage limits); record which list the app is in
- Notification sound/vibration and heads-up appearance on One UI
- Everything in the S26 Ultra / S22 Ultra columns above

## Second pass: S26 Ultra screen profile (emulator)

Assumption: exact S26 Ultra panel specs could not be confirmed from this PC, so the AVD uses the
S25 Ultra values (6.9", 1440x3120 QHD+, ~500 ppi). Same API 37 system image as above.

- AVD `S26U_API37`: `hw.lcd.width=1440`, `hw.lcd.height=3120`, `hw.lcd.density=600`, 4 GB RAM
- One UI default display emulated with `adb shell wm size 1080x2340` + `adb shell wm density 450`
  (same dp layout as QHD+ at 600 dpi: 600/1440 = 450/1080)

| Item | QHD+ 1440x3120 @600 | FHD+ 1080x2340 @450 |
|---|---|---|
| App launch, notification permission prompt | Pass | Pass |
| Immediate notification with Mark as done / Snooze | Pass | Pass |
| Layout: tabs/FAB not covered, gesture navigation | Pass | Pass |
| Layout: tabs/FAB not covered, 3-button navigation | — | Pass |

Observed on both profiles: on the Create page with the keyboard open, the floating "Create" button overlaps
the Schedule/Repeating switches (existing behaviour, not a regression).

Not reproducible on the emulator: One UI itself (Samsung launcher, notification styling, Good Lock etc.),
Samsung battery/background policies (sleeping apps, Adaptive battery), curved corner radius and the
punch-hole cutout position, 120 Hz adaptive refresh, S Pen, Samsung keyboard.

## Issue fixes (emulator `S26U_API37`)

| Issue | Reproduced | Cause | Fix |
|---|---|---|---|
| #42 notes wiped | Yes (truncated `data.json` opened as an empty list) | Non-atomic, un-awaited save; a failed read set the list to `[]` and the next save made it permanent (`lib/managers/file_manager.dart`, `lib/managers/app_manager.dart` `_load`) | 4666243 |
| #20 snoozed repeating reminder reappears after Mark as done | Yes | `snoozeDateTime` not cleared on done, so the past snooze time was rescheduled (`lib/managers/notification_manager.dart` done handler) | 180f20b |
| #22 scheduled notification only appears after opening the app | No (fixed by the merge) | 1.4.2's manifest did not declare `ScheduledNotificationReceiver` / `ScheduledNotificationBootReceiver` or `RECEIVE_BOOT_COMPLETED`, so alarms had no receiver to post the notification; it was only shown when the app opened and `updateAllNotifications` caught up. Added by f267b6c (flutter-upgrade). | Verified: arrives with the app closed (07:35 test) and after a reboot without opening the app (08:21 test) |
| #21 hourly repeating item disappears from the list after tapping its notification | No | Tapping only opens the edit page (`lib/managers/notification_manager.dart` handleResponse, no data change; same logic as 1.4.2). Most likely the same mechanism as #42: the tap brings the app to the foreground, the resume callback (`lib/managers/app_manager.dart` LifecycleEventHandler → `fullUpdate`) re-reads `data.json`, and in 1.4.2 a failed/partial read replaced the list with `[]`. Fixed by 4666243. | Tested on the emulator with the app in the background and with the process killed (cold start): the item stays in the list both times |
| #38 notifications disappear when the app is swiped away in Recents | No | On stock Android (emulator) swiping the task away ends the process but the posted notifications and the scheduled alarms stay. The report is from MIUI (Xiaomi Mi 8, Android 10), which force-stops apps without "Autostart" on swipe; a force-stop removes the app's notifications and alarms, and no app code can prevent it. Nothing in the app cancels notifications on task removal (no `onTaskRemoved`/`onDestroy` handling). Needs a check on One UI. | Not changed |
| #35 notifications not shown on Galaxy Watch 4 | Not testable on the emulator | Every Noterly notification is posted with `ongoing: true` (`lib/managers/notification_manager.dart:322`). Ongoing notifications are not bridged from the phone to Wear OS / Galaxy Watch, so they never reach the watch. All items also share one `groupKey` (line 320) without a summary notification. Making notifications non-ongoing would change the app's core behaviour (reminders that cannot be swiped away), so no code change was made without confirming on a watch. | Not changed; candidate: an opt-in setting for non-ongoing notifications |
