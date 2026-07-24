import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/main.dart';
import 'package:patrol/patrol.dart';

/// Patrol integration tests. Native automation (the file-picker dialog) needs a
/// real device/emulator: `patrol test -t integration_test/app_test.dart`.
void main() {
  late GurbaniDatabase database;
  late Preferences prefs;

  setUpAll(() async {
    database = await GurbaniDatabase.open();
    prefs = await Preferences.load();
  });
  tearDownAll(() => database.dispose());

  patrolTest('launches and shows the presenter', ($) async {
    await $.pumpWidgetAndSettle(
      GurbaniLiveApp(
        database: database,
        prefs: prefs,
      ),
    );

    expect($('Gurbani Live'), findsOneWidget);
    expect($(#search_field), findsOneWidget);
    expect($('Start AI follow (mic)'), findsOneWidget);
  });

  patrolTest('search finds a shabad and shows it', ($) async {
    await $.pumpWidgetAndSettle(
      GurbaniLiveApp(
        database: database,
        prefs: prefs,
      ),
    );

    await $(#search_field).enterText('sdvsd');
    await $.pumpAndSettle();

    // First-letter search for Saajan Des Videsiarre (ang 1111).
    expect($('Ang 1111'), findsWidgets);
  });
}
