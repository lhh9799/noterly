import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_fetch/background_fetch.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:noterly/l10n/app_localisations.dart';
import 'package:logger/logger.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/managers/isolate_manager.dart';
import 'package:noterly/managers/log.dart';
import 'package:noterly/managers/notification_manager.dart';
import 'package:noterly/managers/wear_sync.dart';
import 'package:noterly_wear/noterly_wear.dart';
import 'package:noterly/pages/create_notification_page.dart';
import 'package:noterly/pages/main_page.dart';
import 'package:noterly/theme/app_theme.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;

  if (isTimeout) {
    // Immediately finish the task if it's timed-out.
    Log.logger.w('[BackgroundFetch] Headless task timed-out: $taskId');
    BackgroundFetch.finish(taskId);
    return;
  }

  Log.logger.d('[BackgroundFetch] Headless event received.');

  await AppManager.instance.ensureInitialised();
  await AppManager.instance.fullUpdate();
  await NotificationManager.instance.updateAllNotifications();

  BackgroundFetch.finish(taskId);
}

/// Run by the watch sync service in a headless engine when the watch app sends commands or asks for the list, also
/// while the app is closed. Follows the pattern of the notification buttons' background handler.
@pragma('vm:entry-point')
Future<void> wearCommandEntryPoint() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppManager.instance.ensureInitialised();
    await AppManager.instance.fullUpdate();

    final changed = await WearSync.applyQueuedCommands();
    // A sync request without commands still gets a fresh snapshot (the repeat times move on with the clock)
    if (!changed) await WearSync.sendSnapshot(AppManager.instance.data);
    await WearSync.applyBridgeTags(AppManager.instance.notifier.value);

    if (changed) {
      var sendPort = IsolateNameServer.lookupPortByName(IsolateManager.mainPortName);
      sendPort?.send('update');
    }
  } catch (e, s) {
    Log.logger.e('Failed to handle watch commands', error: e, stackTrace: s);
  } finally {
    await NoterlyWear.headlessDone();
  }
}

Future<void> main(List<String> args) async {
  // Allow async initialisation to complete before running the app
  WidgetsFlutterBinding.ensureInitialized();

  Log.logger.d("Starting app with args: $args");

  // Log all uncaught errors from the framework
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Log.logger.e('Uncaught Flutter error: ${details.exceptionAsString()}', error: details.exception, stackTrace: details.stack);
  };
  // Log all uncaught asynchronous errors that aren't handled by the Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    Log.logger.e('Uncaught platform error', error: error, stackTrace: stack);
    return true;
  };

  // Ensure the app renders behind the system UI.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  // Initialise the isolate manager, which handles messages sent from a background task to the main UI isolate
  try {
    IsolateManager.init();
  } on IsolateSpawnException catch (e) {
    Log.logger.e('Failed to initialise isolate manager: $e');
  }

  // Add the Google Fonts license to the license registry
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['assets/google_fonts'], license);
  });

  // Run the app
  runApp(MyApp(launchMessage: args.isNotEmpty ? args[0] : null));

  // Register the background task
  await BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  // Set up quick actions
  const quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    if (shortcutType == 'action_new') {
      MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const CreateNotificationPage()),
        (route) => route.isFirst,
      );
    }
  });

  quickActions.setShortcutItems(<ShortcutItem>[
    const ShortcutItem(type: 'action_new', localizedTitle: 'New note', icon: 'ic_shortcut_add'),
  ]);
}

class MyApp extends StatefulWidget {
  final String? launchMessage;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey(debugLabel: "Main Navigator");

  const MyApp({
    super.key,
    this.launchMessage,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _shareIntentDataStreamSubscription;
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();

    if (widget.launchMessage == 'launchFromQuickTile') {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CreateNotificationPage()),
          (route) => route.isFirst,
        );
      });
    }

    // SHARING INTENT
    handleSharedText(List media) {
      if (media.isEmpty) return;

      var text = media.first.toString();

      // Show create notification page with the shared text as the title
      MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => CreateNotificationPage(initialTitle: text)),
        (route) => route.isFirst,
      );
    }

    handleShareError(Object error) {
      Log.logger.e("getLinkStream error: $error");
    }

    // Share sheet listener, while app is open
    _shareIntentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(handleSharedText, onError: handleShareError);

    // Share sheet listener, when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then(handleSharedText, onError: handleShareError);

    // GENERAL INTENT
    handleIntent(receive_intent.Intent? intent) {
      if (intent == null) return;
      Log.logger.log(Level.debug, "Received intent: $intent");

      if (intent.action == 'uk.co.tdsstudios.noterly.ACTION_CREATE_NOTE') {
        // Show create notification page
        MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CreateNotificationPage()),
          (route) => route.isFirst,
        );
      }
    }

    handleIntentError(Object error) {
      Log.logger.e("getLinkStream error: $error");
    }

    // Intent listener, while app is open
    _intentDataStreamSubscription = ReceiveIntent.receivedIntentStream.listen(handleIntent, onError: handleIntentError);

    // Intent listener, when app is closed
    ReceiveIntent.getInitialIntent().then(handleIntent, onError: handleIntentError);
  }

  @override
  void dispose() {
    _shareIntentDataStreamSubscription?.cancel();
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          startOnBoot: true,
          forceAlarmManager: false,
          requiredNetworkType: NetworkType.NONE),
      (String taskId) async {
        // <-- Event handler
        Log.logger.d('[BackgroundFetch] Event received $taskId');

        await AppManager.instance.ensureInitialised();
        await AppManager.instance.fullUpdate();
        await NotificationManager.instance.updateAllNotifications();

        BackgroundFetch.finish(taskId); // Signal the task is complete. IMPORTANT
      },
      (String taskId) async {
        // <-- Task timeout handler.
        Log.logger.w('[BackgroundFetch] Task timeout: $taskId');
        BackgroundFetch.finish(taskId);
      },
    );
    Log.logger.d('[BackgroundFetch] configure success: $status');

    await NotificationManager.instance.updateAllNotifications();

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      ColorScheme lightColorScheme, darkColorScheme;

      if (lightDynamic != null && darkDynamic != null) {
        Log.logger.d('Using dynamic color scheme.');

        lightColorScheme = AppTheme.completeDynamicScheme(lightDynamic.harmonized());
        darkColorScheme = AppTheme.completeDynamicScheme(darkDynamic.harmonized());
      } else {
        Log.logger.d('No dynamic color scheme, using fallback.');

        lightColorScheme = AppTheme.fallbackScheme(Brightness.light);
        darkColorScheme = AppTheme.fallbackScheme(Brightness.dark);
      }

      return MaterialApp(
        navigatorKey: MyApp.navigatorKey,
        title: 'Noterly',
        localizationsDelegates: AppLocalisations.localizationsDelegates,
        supportedLocales: AppLocalisations.supportedLocales,
        theme: AppTheme.build(lightColorScheme),
        darkTheme: AppTheme.build(darkColorScheme),
        themeMode: ThemeMode.system,
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}
