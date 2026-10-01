import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myuniapp/src/presentation/theme/app_theme.dart';

void main() {
  testWidgets(
    'application dark theme builds correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Text('BGCTUB Companion'),
          ),
        ),
      );

      expect(
        find.text('BGCTUB Companion'),
        findsOneWidget,
      );

      final materialApp =
      tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );

      expect(
        materialApp.theme?.brightness,
        Brightness.dark,
      );
    },
  );
}