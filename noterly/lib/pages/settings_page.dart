import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:noterly/build_info.dart';
import 'package:noterly/extensions/duration_extensions.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/managers/auto_backup.dart';
import 'package:noterly/managers/backup_manager.dart';
import 'package:noterly/managers/file_manager.dart';
import 'package:noterly/managers/notification_manager.dart';
import 'package:noterly/managers/scroll_capture.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/models/repetition_data.dart';
import 'package:noterly/widgets/duration_picker.dart';
import 'package:noterly/widgets/first_launch_dialog.dart';
import 'package:noterly/widgets/expressive.dart';
import 'package:noterly_backup/noterly_backup.dart';
import 'package:system_settings_2/system_settings_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../managers/log.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const String _copyrightText = '''
• Tom Chapman (en_GB, en_US)
• FBI (es)
• Sascha Grebe (de)
• Bluefy (de)
• DindinYT37 (de)
• Mr.Spok (ru, ua)
• SPLESHER (pl)
• GaetanoEsse (it)
• Nader Ghr (fr)''';

  final int _millisBeforeReset = 1000;
  int _easterEggCount = 0;
  int _lastTapTime = 0;

  bool _debugOptions = false;

  /// False when automatic backup is on but its folder can no longer be written to.
  bool _autoBackupWritable = true;

  /// Whether the phone has Google Play services, which runs Google backup and opens its settings.
  bool _hasGooglePlayServices = false;

  /// The phone's Google backup settings, opened by Google Play services.
  static final Uri _googleBackupSettings = Uri.parse('https://one.google.com/backupsettings');

  @override
  void initState() {
    super.initState();
    _checkAutoBackupFolder();
    _checkGooglePlayServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.of(context).page_settings_title),
      ),
      body: ScrollCaptureTarget(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _getHeader(Strings.of(context).page_settings_header_notifications),
            _getCard(context, [
              ListTile(
                title: Text(Strings.of(context).page_settings_notifications_snoozeDuration),
                subtitle: Text(AppManager.instance.data.snoozeDuration.toRelativeDurationString()),
                leading: const Icon(Icons.snooze),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 12,
                onTap: () {
                  showDurationPicker(
                    context: context,
                    initialDuration: AppManager.instance.data.snoozeDuration,
                  ).then((value) {
                    if (value == null) return;
                    setState(() {
                      AppManager.instance.data.snoozeDuration = value;
                      AppManager.instance.data.snoozeToastText = Strings.of(context).toast_notificationSnoozed(value.toRelativeDurationString());
                    });
                    AppManager.instance.saveSettings();
                  });
                },
              ),
              SwitchListTile(
                value: AppManager.instance.data.dismissibleNotificationsEnabled,
                title: Text(Strings.of(context).page_settings_notifications_dismissible_title),
                subtitle: Text(Strings.of(context).page_settings_notifications_dismissible_subtitle),
                secondary: const Icon(Icons.watch),
                onChanged: (value) async {
                  setState(() => AppManager.instance.data.dismissibleNotificationsEnabled = value);
                  await AppManager.instance.saveSettings();
                  await NotificationManager.instance.refreshAllNotifications();
                },
              ),
              if (AppManager.instance.data.dismissibleNotificationsEnabled)
                SwitchListTile(
                  value: AppManager.instance.data.dismissibleByDefault,
                  title: Text(Strings.of(context).page_settings_notifications_dismissibleByDefault_title),
                  subtitle: Text(Strings.of(context).page_settings_notifications_dismissibleByDefault_subtitle),
                  secondary: const Icon(Icons.tune),
                  onChanged: (value) async {
                    setState(() => AppManager.instance.data.dismissibleByDefault = value);
                    await AppManager.instance.saveSettings();
                  },
                ),
            ]),
            _getSpacer(),
            _getHeader(Strings.of(context).page_settings_header_swipe),
            _getCard(context, [
              SwitchListTile(
                value: AppManager.instance.data.swipeEnabled,
                title: Text(Strings.of(context).page_settings_swipe_enabled_title),
                subtitle: Text(Strings.of(context).page_settings_swipe_enabled_subtitle),
                secondary: const Icon(Icons.swipe),
                onChanged: (value) async {
                  setState(() => AppManager.instance.data.swipeEnabled = value);
                  await AppManager.instance.saveSettings();
                },
              ),
              if (AppManager.instance.data.swipeEnabled) ...[
                _getSwipeActionTile(context, right: true),
                _getSwipeActionTile(context, right: false),
              ],
            ]),
            _getSpacer(),
            _getHeader(Strings.of(context).page_settings_header_system),
            _getCard(context, [
              ListTile(
                title: Text(Strings.of(context).page_settings_system_notificationSettings),
                leading: const Icon(Icons.notifications),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  try {
                    SystemSettings.appNotifications();
                  } catch (_) {
                    try {
                      SystemSettings.app();
                    } catch (_) {
                      Log.logger.e('Failed to open system settings');
                    }
                  }
                },
              )
            ]),
            _getSpacer(),
            _getHeader(Strings.of(context).page_settings_header_google_backup),
            _getCard(context, [
              SwitchListTile(
                value: AppManager.instance.data.googleBackupReminders,
                title: Text(Strings.of(context).page_settings_google_backup_reminders_title),
                subtitle: Text(Strings.of(context).page_settings_google_backup_reminders_subtitle),
                secondary: const Icon(Icons.cloud_upload),
                onChanged: (value) {
                  setState(() => AppManager.instance.data.googleBackupReminders = value);
                  AppManager.instance.saveSettings();
                },
              ),
              SwitchListTile(
                value: AppManager.instance.data.googleBackupSettings,
                title: Text(Strings.of(context).page_settings_google_backup_settings_title),
                subtitle: Text(Strings.of(context).page_settings_google_backup_settings_subtitle),
                secondary: const Icon(Icons.settings_backup_restore),
                onChanged: (value) {
                  setState(() => AppManager.instance.data.googleBackupSettings = value);
                  AppManager.instance.saveSettings();
                },
              ),
              if (_hasGooglePlayServices)
                ListTile(
                  title: Text(Strings.of(context).page_settings_google_backup_open_title),
                  subtitle: Text(Strings.of(context).page_settings_google_backup_open_subtitle),
                  leading: const Icon(Icons.backup),
                  trailing: const Icon(Icons.open_in_new),
                  minVerticalPadding: 12,
                  onTap: () => _launchUrl(_googleBackupSettings),
                ),
            ]),
            _getSpacer(),
            _getHeader(Strings.of(context).page_settings_header_backup),
            _getCard(context, [
              _getAutoBackupTile(context),
              ListTile(
                title: Text(Strings.of(context).page_settings_backup_export_title),
                subtitle: Text(Strings.of(context).page_settings_backup_export_subtitle),
                leading: const Icon(Icons.upload_file),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 12,
                onTap: _exportReminders,
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_backup_import_title),
                subtitle: Text(Strings.of(context).page_settings_backup_import_subtitle),
                leading: const Icon(Icons.file_open),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 12,
                onTap: _importReminders,
              ),
            ]),
            _getSpacer(),
            _getHeader(Strings.of(context).page_settings_header_about),
            _getCard(context, [
              ListTile(
                title: Text(Strings.of(context).page_settings_about_donation_title),
                leading: const Icon(Icons.coffee),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  var uri = Uri.parse('https://ko-fi.com/tomchapman128');
                  await _launchUrl(uri);
                },
              ),
            ]),
            _getSpacer(),
            _getCard(context, [
              ListTile(
                title: Text(Strings.of(context).page_settings_about_version_title),
                subtitle: Builder(
                  builder: (BuildContext context) {
                    if (BuildInfo.releaseType == ReleaseType.stable) return const Text(BuildInfo.appVersion);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${BuildInfo.releaseType.name} release', style: const TextStyle(color: Colors.amber)),
                        const Text('${BuildInfo.appVersion} (${BuildInfo.branch})'),
                      ],
                    );
                  },
                ),
                leading: const Icon(Icons.info),
                minVerticalPadding: 12,
                onTap: () async {
                  _easterEggCount++;

                  var newTime = DateTime.now().millisecondsSinceEpoch;
                  if (newTime - _lastTapTime > _millisBeforeReset) {
                    _easterEggCount = 0;
                  }
                  _lastTapTime = newTime;

                  if (_easterEggCount == 7) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(Strings.of(context).dialog_easterEgg_title),
                        content: Text(Strings.of(context).dialog_easterEgg_text),
                        actions: [
                          TextButton(
                            onPressed: () {
                              setState(() => _debugOptions = true);
                              Navigator.of(context).pop();
                            },
                            child: Text(Strings.of(context).dialog_easterEgg_action_showDebugOptions),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(Strings.of(context).general_close),
                          ),
                        ],
                      ),
                      barrierDismissible: false,
                    );
                  }
                },
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_about_copyright_title),
                subtitle: Text(Strings.of(context).page_settings_about_copyright_text),
                leading: const Icon(Icons.copyright),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 12,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Column(
                          children: [
                            Text('Noterly', style: Theme.of(context).textTheme.titleLarge),
                            if (BuildInfo.releaseType != ReleaseType.stable)
                              Text('${BuildInfo.releaseType.name} release',
                                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                        color: Colors.amber,
                                      )),
                            Text(
                              BuildInfo.releaseType == ReleaseType.stable ? BuildInfo.appVersion : '${BuildInfo.appVersion} (${BuildInfo.branch})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(Strings.of(context).page_settings_about_licenses_page_legalese),
                              const SizedBox(height: 8),
                              Text(Strings.of(context).page_settings_about_licenses_page_openSourceSoftware),
                              const SizedBox(height: 16),
                              Text(Strings.of(context).dialog_about_translations_title, style: Theme.of(context).textTheme.titleMedium),
                              const Text(_copyrightText),
                              const SizedBox(height: 16),
                              ButtonBar(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      showLicensePage(
                                        context: context,
                                        applicationLegalese: Strings.of(context).page_settings_about_licenses_page_legalese,
                                        applicationVersion: BuildInfo.appVersion,
                                      );
                                    },
                                    child: Text(Strings.of(context).dialog_about_action_showLicenses),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(Strings.of(context).general_close),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_about_tutorial_title),
                leading: const Icon(Icons.school),
                trailing: const Icon(Icons.chevron_right),
                minVerticalPadding: 12,
                onTap: () async {
                  showDialog(
                    context: context,
                    builder: (context) => FirstLaunchDialog(
                      onComplete: () {},
                    ),
                    barrierDismissible: false,
                  );
                },
              ),
            ]),
            _getSpacer(),
            _getCard(context, [
              ListTile(
                title: Text(Strings.of(context).page_settings_about_github_title),
                leading: const Icon(Icons.favorite),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  var uri = Uri.parse('https://github.com/tomc128/noterly');
                  await _launchUrl(uri);
                },
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_about_privacyPolicy_title),
                leading: const Icon(Icons.privacy_tip),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  var uri = Uri.parse('https://tdsstudios.co.uk/privacy');
                  await _launchUrl(uri);
                },
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_about_feedback_title),
                leading: const Icon(Icons.comment),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  var uri = Uri.parse('https://forms.gle/5HZNjmr5wF1t4r8q6');
                  await _launchUrl(uri);
                },
              ),
              ListTile(
                title: Text(Strings.of(context).page_settings_about_translate_title),
                leading: const Icon(Icons.translate),
                trailing: const Icon(Icons.open_in_new),
                minVerticalPadding: 12,
                onTap: () async {
                  var uri = Uri.parse('https://crowdin.com/project/noterly/invite?h=5831212784abb6a4b04739214cb7a1a91820487');
                  await _launchUrl(uri);
                },
              ),
            ]),
            if (kDebugMode || _debugOptions) ..._getDebugOptions(context),
          ],
        ),
      ),
    );
  }

  String _swipeActionLabel(BuildContext context, SwipeAction action) => switch (action) {
        SwipeAction.archive => Strings.of(context).swipeAction_archive,
        SwipeAction.delete => Strings.of(context).swipeAction_delete,
        SwipeAction.none => Strings.of(context).swipeAction_none,
      };

  Widget _getSwipeActionTile(BuildContext context, {required bool right}) {
    final data = AppManager.instance.data;
    final title = right ? Strings.of(context).page_settings_swipe_right : Strings.of(context).page_settings_swipe_left;
    final current = right ? data.swipeRightAction : data.swipeLeftAction;

    return ListTile(
      title: Text(title),
      subtitle: Text(_swipeActionLabel(context, current)),
      leading: Icon(right ? Icons.east : Icons.west),
      trailing: const Icon(Icons.chevron_right),
      minVerticalPadding: 12,
      onTap: () async {
        final selected = await showDialog<SwipeAction>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            content: RadioGroup<SwipeAction>(
              groupValue: current,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in SwipeAction.values)
                    RadioListTile<SwipeAction>(value: action, title: Text(_swipeActionLabel(context, action))),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(Strings.of(context).general_cancel),
              ),
            ],
          ),
        );
        if (selected == null || selected == current) return;

        setState(() {
          if (right) {
            data.swipeRightAction = selected;
          } else {
            data.swipeLeftAction = selected;
          }
        });
        await AppManager.instance.saveSettings();
      },
    );
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Without Google Play services the link would only open Google One in the browser, so the item is left out.
  Future<void> _checkGooglePlayServices() async {
    try {
      final has = await NoterlyBackup.hasGooglePlayServices();
      if (mounted) setState(() => _hasGooglePlayServices = has);
    } catch (e, s) {
      Log.logger.w('Could not check for Google Play services', error: e, stackTrace: s);
    }
  }

  Widget _getAutoBackupTile(BuildContext context) {
    final strings = Strings.of(context);
    final data = AppManager.instance.data;
    final isOn = data.autoBackupFolderUri != null;
    final folderName = data.autoBackupFolderName ?? '';
    final hasProblem = isOn && !_autoBackupWritable;

    return ListTile(
      title: Text(strings.page_settings_backup_auto_title),
      subtitle: Text(
        !isOn
            ? strings.page_settings_backup_auto_subtitle_off
            : hasProblem
                ? strings.page_settings_backup_auto_subtitle_error(folderName)
                : strings.page_settings_backup_auto_subtitle_on(AutoBackup.fileName, folderName),
        style: hasProblem ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
      ),
      leading: const Icon(Icons.backup),
      trailing: Switch(
        value: isOn,
        onChanged: (value) => value ? _chooseAutoBackupFolder() : _turnOffAutoBackup(),
      ),
      minVerticalPadding: 12,
      onTap: _chooseAutoBackupFolder,
    );
  }

  /// The app loses access to the folder when it is reinstalled, while the setting can come back with the data.
  Future<void> _checkAutoBackupFolder() async {
    final folder = AppManager.instance.data.autoBackupFolderUri;
    if (folder == null) return;
    final writable = AutoBackup.lastWriteSucceeded != false && await NoterlyBackup.canWrite(folder);
    if (mounted) setState(() => _autoBackupWritable = writable);
  }

  /// Turns automatic backup on, or moves it to another folder, and writes the first backup there.
  Future<void> _chooseAutoBackupFolder() async {
    final strings = Strings.of(context);

    final BackupFolder? folder;
    try {
      folder = await NoterlyBackup.pickFolder();
    } catch (e, s) {
      Log.logger.e('Failed to pick a backup folder', error: e, stackTrace: s);
      _showSnackBar(strings.snackbar_auto_backup_failed);
      return;
    }
    if (folder == null) return;

    final data = AppManager.instance.data;
    final previous = data.autoBackupFolderUri;
    data.autoBackupFolderUri = folder.uri;
    data.autoBackupFolderName = folder.name;
    await AppManager.instance.saveSettings(); // Writes the backup too
    if (previous != null && previous != folder.uri) await NoterlyBackup.release(previous);

    final succeeded = AutoBackup.lastWriteSucceeded == true;
    if (!mounted) return;
    setState(() => _autoBackupWritable = succeeded);
    _showSnackBar(succeeded ? strings.snackbar_auto_backup_done(folder.name) : strings.snackbar_auto_backup_failed);
  }

  Future<void> _turnOffAutoBackup() async {
    final data = AppManager.instance.data;
    final folder = data.autoBackupFolderUri;
    if (folder == null) return;

    data.autoBackupFolderUri = null;
    data.autoBackupFolderName = null;
    await AppManager.instance.saveSettings();
    await NoterlyBackup.release(folder);
    if (mounted) setState(() => _autoBackupWritable = true);
  }

  Future<void> _exportReminders() async {
    final strings = Strings.of(context);
    final items = List<NotificationItem>.from(AppManager.instance.notifier.value);

    try {
      if (!await BackupManager.exportToFile(items)) return;
      _showSnackBar(strings.snackbar_export_done(items.length));
    } catch (e, s) {
      Log.logger.e('Failed to export reminders', error: e, stackTrace: s);
      _showSnackBar(strings.snackbar_export_failed);
    }
  }

  Future<void> _importReminders() async {
    final strings = Strings.of(context);

    final List<NotificationItem>? items;
    try {
      items = await BackupManager.pickAndRead();
    } catch (e, s) {
      Log.logger.e('Failed to read reminders file', error: e, stackTrace: s);
      _showSnackBar(strings.snackbar_import_failed);
      return;
    }

    if (items == null || !mounted) return;
    if (items.isEmpty) {
      _showSnackBar(strings.snackbar_import_empty);
      return;
    }

    final count = items.length;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.dialog_import_title),
        content: Text(strings.dialog_import_text(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.general_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.dialog_import_action_replace),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.dialog_import_action_merge),
          ),
        ],
      ),
    );
    if (replace == null) return;

    try {
      final result = await AppManager.instance.importItems(items, replace: replace);
      _showSnackBar(strings.snackbar_import_done(result.added, result.updated, result.removed));
    } catch (e, s) {
      Log.logger.e('Failed to import reminders', error: e, stackTrace: s);
      _showSnackBar(strings.snackbar_import_failed);
    }
  }

  Future<void> _launchUrl(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Failed to launch URL: $uri');
      }
    } on Exception catch (e) {
      Log.logger.e('Failed to launch URL: $uri [$e]');
    }
  }

  List<Widget> _getDebugOptions(BuildContext context) => [
        _getSpacer(),
        _getHeader(
          Strings.of(context).page_settings_header_debug,
          subtitle: Strings.of(context).page_settings_header_debug_disclaimer,
        ),
        _getCard(
          context,
          [
            ListTile(
              title: const Text('Generate 10 random items'),
              trailing: const Icon(Icons.chevron_right),
              minVerticalPadding: 12,
              leading: const Icon(Icons.generating_tokens),
              onTap: () {
                String randomString() {
                  const chars = 'abcdefghijklmnopqrstuvwxyz';
                  return List.generate(10, (index) => chars[Random().nextInt(chars.length)]).join();
                }

                for (var i = 0; i < 10; i++) {
                  bool shouldHaveBody = Random().nextBool();
                  bool shouldBeScheduled = Random().nextBool();
                  bool shouldBeRepeating = Random().nextBool();

                  DateTime? scheduledTime;
                  RepetitionData? repetitionData;

                  if (shouldBeRepeating) {
                    scheduledTime = DateTime.now().add(Duration(days: Random().nextInt(10) + 1));
                    repetitionData = RepetitionData(
                      number: Random().nextInt(5) + 1,
                      type: Repetition.values[Random().nextInt(Repetition.values.length)],
                    );
                  } else if (shouldBeScheduled) {
                    scheduledTime = DateTime.now().add(Duration(days: Random().nextInt(10) + 1));
                    repetitionData = null;
                  } else {
                    scheduledTime = null;
                    repetitionData = null;
                  }

                  Color colour = Colors.primaries[Random().nextInt(Colors.primaries.length)];

                  var item = NotificationItem(
                    id: const Uuid().v4(),
                    title: randomString(),
                    body: shouldHaveBody ? randomString() : '',
                    dateTime: scheduledTime,
                    repetitionData: repetitionData,
                    colour: colour,
                  );
                  AppManager.instance.addItem(item);
                }
              },
            ),
            ListTile(
              title: const Text('Force update notifications'),
              trailing: const Icon(Icons.chevron_right),
              leading: const Icon(Icons.notification_important),
              minVerticalPadding: 12,
              onTap: () {
                NotificationManager.instance.forceUpdateAllNotifications();
              },
            ),
            ListTile(
              title: const Text('Log items to console'),
              trailing: const Icon(Icons.chevron_right),
              leading: const Icon(Icons.document_scanner),
              minVerticalPadding: 12,
              onTap: () {
                AppManager.instance.printItems();
              },
            ),
            ListTile(
              title: const Text('Delete all app data'),
              trailing: const Icon(Icons.chevron_right),
              leading: const Icon(Icons.delete_forever),
              minVerticalPadding: 12,
              onTap: () {
                FileManager.delete().then((value) => AppManager.instance.fullUpdate());
              },
            ),
          ],
        ),
      ];

  Widget _getCard(BuildContext context, List<Widget> children) => ExpressiveListGroup(children: children);

  Widget _getHeader(String title, {String? subtitle}) => ExpressiveSectionHeader(title, subtitle: subtitle);

  Widget _getSpacer() => const SizedBox(height: 8);
}
