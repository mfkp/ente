import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import "package:background_fetch/background_fetch.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:home_widget/home_widget.dart' as hw;
import 'package:logging/logging.dart';
import 'package:media_extension/media_extension_action_types.dart';
import 'package:photos/ente_theme_data.dart';
import "package:photos/generated/l10n.dart";
import "package:photos/l10n/l10n.dart";
import "package:photos/main.dart";
import "package:photos/service_locator.dart";
import 'package:photos/services/app_lifecycle_service.dart';
import "package:photos/services/home_widget_service.dart";
import 'package:photos/services/sync_service.dart';
import 'package:photos/ui/tabs/home_widget.dart';
import "package:photos/ui/viewer/actions/file_viewer.dart";
import "package:photos/utils/intent_util.dart";
import "package:workmanager/workmanager.dart" as workmanager;

class EnteApp extends StatefulWidget {
  final AdaptiveThemeMode? savedThemeMode;
  final Locale? locale;

  const EnteApp(
    this.locale,
    this.savedThemeMode, {
    super.key,
  });

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_EnteAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<EnteApp> createState() => _EnteAppState();
}

class _EnteAppState extends State<EnteApp> with WidgetsBindingObserver {
  late Locale? locale;
  final _logger = Logger("EnteAppState");

  @override
  void initState() {
    _logger.info('init App');
    super.initState();
    locale = widget.locale;
    setupIntentAction();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForWidgetLaunch();
  }

  void _checkForWidgetLaunch() {
    if (Platform.isIOS) {
      return;
    }
    hw.HomeWidget.initiallyLaunchedFromHomeWidget().then(
      (uri) => HomeWidgetService.instance.onLaunchFromWidget(uri, context),
    );
    hw.HomeWidget.widgetClicked.listen(
      (uri) => HomeWidgetService.instance.onLaunchFromWidget(uri, context),
    );
  }

  setLocale(Locale newLocale) {
    setState(() {
      locale = newLocale;
    });
  }

  void setupIntentAction() async {
    final mediaExtentionAction = Platform.isAndroid
        ? await initIntentAction()
        : MediaExtentionAction(action: IntentAction.main);
    AppLifecycleService.instance.setMediaExtensionAction(mediaExtentionAction);
    if (mediaExtentionAction.action == IntentAction.main) {
      if (!enableWorkManager) {
        _configureBackgroundFetch();
        return;
      }
      _configureWorkManager();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || kDebugMode) {
      return Listener(
        onPointerDown: (event) {
          machineLearningController.onUserInteraction();
        },
        child: AdaptiveTheme(
          light: lightThemeData,
          dark: darkThemeData,
          initial: widget.savedThemeMode ?? AdaptiveThemeMode.system,
          builder: (lightTheme, dartTheme) => MaterialApp(
            title: "ente",
            themeMode: ThemeMode.system,
            theme: lightTheme,
            darkTheme: dartTheme,
            home: AppLifecycleService.instance.mediaExtensionAction.action ==
                    IntentAction.view
                ? const FileViewer()
                : const HomeWidget(),
            debugShowCheckedModeBanner: false,
            builder: EasyLoading.init(),
            locale: locale,
            supportedLocales: appSupportedLocales,
            localeListResolutionCallback: localResolutionCallBack,
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              S.delegate,
            ],
          ),
        ),
      );
    } else {
      return Listener(
        onPointerDown: (event) {
          machineLearningController.onUserInteraction();
        },
        child: MaterialApp(
          title: "ente",
          themeMode: ThemeMode.system,
          theme: lightThemeData,
          darkTheme: darkThemeData,
          home: const HomeWidget(),
          debugShowCheckedModeBanner: false,
          builder: EasyLoading.init(),
          locale: locale,
          supportedLocales: appSupportedLocales,
          localeListResolutionCallback: localResolutionCallBack,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            S.delegate,
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final String stateChangeReason = 'app -> $state';
    if (state == AppLifecycleState.resumed) {
      AppLifecycleService.instance
          .onAppInForeground(stateChangeReason + ': sync now');
      SyncService.instance.sync();
    } else {
      AppLifecycleService.instance.onAppInBackground(stateChangeReason);
    }
  }

  void _configureWorkManager() {
    workmanager.Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    workmanager.Workmanager().registerPeriodicTask(
      'backgroundFetchTask',
      'backgroundTaskType',
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 1),
      constraints: workmanager.Constraints(
        networkType: workmanager.NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: workmanager.ExistingWorkPolicy.keep,
      backoffPolicy: workmanager.BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }
}

final _logger = Logger("BackgroundInitializer");

void _configureBackgroundFetch() {
  BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        forceAlarmManager: false,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        requiresBatteryNotLow: true,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.ANY,
      ), (String taskId) async {
    await runBackgroundTask(taskId);
  }, (taskId) {
    _logger.info("BG task timeout taskID: $taskId");
    killBGTask(taskId);
  }).then((int status) {
    _logger.info('[BackgroundFetch] configure success: $status');
  }).catchError((e) {
    _logger.info('[BackgroundFetch] configure ERROR: $e');
  });
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  workmanager.Workmanager().executeTask((taskName, inputData) async {
    try {
      await runBackgroundTask(taskName);
      return true;
    } catch (e) {
      _logger.info('[WorkManager] task error: $e');
      await killBGTask(taskName);
      return false;
    }
  });
}
