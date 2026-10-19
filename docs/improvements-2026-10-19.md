# Improvements (2026-10-19)

Eight items reported after using the dev build on the S26 Ultra. Verified on the emulator `S26U_API37`
(1440x3120 @600, shown as One UI default FHD+ 1080x2340 @450), mostly with the release build.

| # | Report | Cause | Change |
|---|---|---|---|
| 1 | Startup and page changes slower than the Play Store version | The installed APK was a **debug** build (JIT, debug checks). Cold start on the emulator: debug did not draw its first frame within 10 s (`am start -W` timed out; Dart `main` ran ~5.7 s after process start), release 3.7–3.9 s. The emulator runs arm64 code through translation, so real-device numbers are lower for both. | Release builds now sign with the local debug key when `key.properties` is missing (`android/app/build.gradle`), so a release APK installs over the debug one without uninstalling (same certificate, data kept: checked on the emulator). |
| 2 | Undo snack bar only goes away when swiped down | Flutter 3.47 makes snack bars with an action persist by default (`SnackBar.persist ?? action != null`) | `persist: false` on every snack bar with Undo. Display time is Flutter's default 4 s, unchanged from the Play Store version (neither sets a duration). |
| 3 | Snack bar moves the New note button, so taps hit Undo | Fixed snack bars push the FAB up into the snack bar's old place | **Reverted, left as in the Play Store version.** Tried: floating above the button, then beside it in the same row; both looked wrong to the user. Alternatives discussed (undo row in place of the swiped item, banner at the top, undo icon in the app bar, restore from Archive only); the user chose to keep the standard behaviour, as Gmail also pushes its button up. |
| 4 | No visible separation between items on the main screen | New Material 3 cards use `surfaceContainerLow` instead of an elevation tint; the dynamic (Material You) scheme from `dynamic_color` leaves it equal to the page colour, so cards and the page-coloured dividers vanished | Card colour set explicitly to the old elevation-1 tint (`ElevationOverlay.applySurfaceTint`) |
| 5 | Scrolling the main list is not smooth | Debug build (see 1), plus every scroll offset called `setState` on the whole main page, rebuilding every item each frame | Rebuild only when the app bar elevation actually changes |
| 6 | Enter the time with the number keypad | `showTimePicker` opened in dial mode | `initialEntryMode: TimePickerEntryMode.input` (the clock icon still switches to the dial) |
| 7 | Repeat on days of the week like a clock alarm | Not supported | Weekly repetition has day-of-week toggles. `RepetitionData.weekdays` (saved as `weekdays`, old saves load with none). With days chosen, the next time is the next chosen day, in weeks that are a multiple of the number of weeks; the first time moves onto a chosen day. Shown as e.g. "weekly (Tue, Thu)". |
| 8 | Galaxy Watch 8 gets no notifications; Noterly is not in Galaxy Wearable's app list | See below | No code change |

## 8: why Noterly is missing from Galaxy Wearable

- Galaxy Wearable's *App notifications* list shows recently notifying apps by default; the drop-down at the top switches
  it to **All**. The dev build is listed as **Noterly Dev**.
- Noterly posts every reminder as an ongoing notification unless the reminder's **Dismissible** switch is on (setting from
  #35). Ongoing notifications are not forwarded to the watch, so with the defaults Noterly never sends anything the watch
  side sees. Turning on Dismissible for a reminder is needed for it to reach the watch.
- Not testable on the emulator; needs the phone and the watch.

## Checked on the emulator (release build unless noted)

- Release APK installed over the debug APK: data kept, 12 items still listed
- Scheduled reminder with the app process killed: posted on time; Mark as done from the notification archived it
- Snack bar after archiving: original layout (full width, pushes New note up), goes away by itself; Undo restores the item
- Repeat picker: weekly shows S M T W T F S; Tue+Thu selected moved "Today 8:00" to "Tomorrow 8:00" (Tuesday) and the
  alarm was registered for 2026-10-20 08:00; the list shows "Repeats weekly (Tue, Thu)"
- Time picker opens in input mode with the numeric keypad
- Weekday logic (throwaway unit test, not committed): Mon/Wed/Fri sequence, every 2 weeks on Tue/Sun, alignment, old JSON

## Not changed

- The Create and Edit pages have the same card colour issue as item 4 (not reported, left as is)
- The time input fields are not focused automatically; tap the hour to open the keypad

## Final check (after reverting item 3)

Diff checked: `97aa094..HEAD` (all of today's code changes).

- Fixed: the app bar shadow could get stuck after switching tabs (the scroll listener compared against the other tab's
  state). The elevation is now taken from the current tab on every build.
- Fixed: picking a new date for a weekday-repeating reminder now moves it onto a selected day straight away, not only
  on save.
- `weekdays` is read with `List<int>.from` so later edits never act on a lazy cast view.
- `flutter analyze`: 0 errors, 0 warnings (20 pre-existing infos).
- Throwaway unit test (not committed): weekday sequences incl. every 2 and 3 weeks across a year boundary, alignment,
  JSON round trip through `jsonEncode`, old saves without `weekdays`, picker copy independent of the original.
- Emulator, release build: archive → snack bar disappears on its own; Undo restores the item; scheduled reminder fires
  with the process killed; Mark as done from the notification archives it.
- No new bugs found in today's changes beyond the two fixed above.
