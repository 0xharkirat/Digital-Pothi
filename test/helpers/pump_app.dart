import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/theme/app_theme.dart';

extension PumpApp on WidgetTester {
  // Wrap in the real app theme so widgets that read the GurbaniTheme extension
  // (context.gurbani) behave as they do in the app.
  Future<void> pumpApp(Widget widget) {
    return pumpWidget(MaterialApp(theme: AppTheme.dark(), home: widget));
  }
}
