# Final check of today's changes (2026-10-18)

Scope: everything merged into `main` today: the build restore (`noterly-build-restore-handoff.md`), the six issues
(#42, #20, #22, #21, #38, #35), the per-reminder **Dismissible** switch and the **Dismissible notifications** setting.
Diff checked: `c0d7894..2f75058`.

Result: no new bugs found in today's changes, so no code was changed.

## Environment

- Flutter 3.47.7 (Dart 3.13.5), Windows 11
- Emulator `S26U_API37` (API 37, 1440x3120 @600, shown as One UI default FHD+ 1080x2340 @450)
- `flutter build apk --debug --flavor dev` (release not built: no `key.properties`)

## Static analysis

`flutter analyze`: 0 errors, 0 warnings. 21 infos, all pre-existing (deprecated APIs, `use_build_context_synchronously`).

## Unit checks

The repo has no tests. These were run as a throwaway `test/` file and not committed. `path_provider` was pointed at a
temp folder.

| Check | Result |
|---|---|
| `AppData` / `NotificationItem` JSON round trip keeps `dismissible` and `dismissibleNotificationsEnabled` | Pass |
| Old save without those fields: setting defaults to on, each reminder to off | Pass |
| No save file: `FileManager.load` returns `null` | Pass |
| Three saves fired without awaiting: the last one wins, no `.tmp` left, `.bak` written | Pass |
| Truncated `data.json`: loads `data.json.bak` | Pass |
| Both files unreadable: throws `SaveFileUnreadableException` and keeps a `.corrupt-<time>` copy | Pass |
| Corrupt `data.json` is not copied over a good `.bak` on the next save | Pass |
| `FileManager.delete` removes the save, backup and temp files | Pass |

## Emulator scenarios

Notification flags were read with `adb shell dumpsys notification`; save data with `run-as ... cat app_flutter/data.json`.

| Scenario | Result |
|---|---|
| Old-format save (no new fields) loads, items kept, new fields written with defaults | Pass |
| New immediate reminder with Dismissible on: posted without `ONGOING_EVENT` | Pass |
| Clear all removes it; after resume and after a cold start it is not shown again and stays in the list | Pass |
| Scheduled and repeating dismissible reminders fire with the app in the background, not ongoing | Pass |
| Swiped repeating dismissible reminder moves to its next occurrence (next hour) | Pass |
| Setting off: Dismissible switch hidden on Create and Edit; all notifications re-posted as ongoing, swiped ones shown again | Pass |
| Setting off: saving an edit keeps the reminder's own `dismissible: true` | Pass |
| Setting on again: dismissible reminders lose `ONGOING_EVENT` in place | Pass |
| #20: snoozed repeating reminder, Mark as done after the snooze fires: not shown again, next hour scheduled, snooze cleared | Pass |
| #42: truncated `data.json` on cold start: backup loaded, all items kept, file rewritten | Pass |

## Known limitation of the Dismissible option

The app cannot tell a swipe from the system removing the notification. After a force-stop (seen on the emulator) or a
reboot (from the code), a due dismissible reminder is not shown again; ongoing ones are. The reminder stays in the list.

## Pre-existing issues seen, not from today's changes (not fixed)

- Create page: with the keyboard open, the Create button covers the Schedule/Repeating switches.
- Saving an edited reminder re-posts its notification as a heads-up.
- Relative times ("2 minutes ago") stay in English when the app language is German.

## Needs the real devices

- Release build (needs the signing key)
- Swiping notifications and scheduled reminders under One UI battery settings
- #35: notifications reaching the Galaxy Watch with Dismissible on
- #38: notifications after closing the app from Recents on One UI
