import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'data/gurbani_database.dart';
import 'data/preferences.dart';
import 'presenter/presenter.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

/// Desktop, where windowing applies. window_manager is desktop-only.
bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

Future<void> main() async {
  // Marionette lets an AI agent drive the running app in debug. No-op in release.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // Open maximized, like STTM - a presenter wants the whole screen. Hidden until
  // maximized so it never flashes at the default size first.
  if (_isDesktop) {
    await windowManager.ensureInitialized();
    unawaited(
      windowManager.waitUntilReadyToShow(
        const WindowOptions(
          title: 'Gurbani Live',
          titleBarStyle: TitleBarStyle.normal,
        ),
        () async {
          await windowManager.maximize();
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );
  }

  // Open the on-device corpus once, app-scoped. A failed 46 MB copy/open shows
  // an error screen rather than throwing into the widget tree.
  GurbaniDatabase? database;
  Object? error;
  try {
    database = await GurbaniDatabase.open();
  } catch (e) {
    error = e;
  }
  // On-device settings + history store, so a restart resumes where it left off.
  final prefs = await Preferences.load();
  runApp(GurbaniLiveApp(database: database, prefs: prefs, error: error));
}

class GurbaniLiveApp extends StatelessWidget {
  const GurbaniLiveApp({
    required this.database,
    required this.prefs,
    this.error,
    super.key,
  });

  final GurbaniDatabase? database;
  final Preferences prefs;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    // ThemeCubit sits above the MaterialApp so the Light/Dark setting flips
    // the whole app live - a Cubit like everything else, not a ValueNotifier.
    return BlocProvider(
      create: (_) => ThemeCubit(prefs),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) => MaterialApp(
          title: 'Gurbani Live',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: database == null
              ? _CorpusError(error: error)
              : MultiRepositoryProvider(
                  providers: [
                    RepositoryProvider.value(value: database!),
                    RepositoryProvider.value(value: prefs),
                  ],
                  // The ThemeCubit created above is already in scope for the
                  // subtree, so the settings screen reads it directly.
                  child: const PresenterPage(),
                ),
        ),
      ),
    );
  }
}

class _CorpusError extends StatelessWidget {
  const _CorpusError({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('Could not load the Gurbani corpus.'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text('$error', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
