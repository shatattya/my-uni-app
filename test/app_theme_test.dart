import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:myuniapp/src/presentation/widgets/home_feature_tile.dart';

void main() {
  Widget buildTestWidget({
    required Widget child,
  }) {
    return ScreenUtilInit(
      designSize: const Size(440, 960),
      minTextAdapt: true,
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF1877F2),
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 100,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'enabled feature tile displays label and responds to tap',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: HomeFeatureTile(
            icon: Icons.menu_book_outlined,
            label: 'Books',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      expect(find.text('Books'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);

      await tester.tap(find.text('Books'));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'disabled feature tile remains visible without navigation affordance',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const HomeFeatureTile(
            icon: Icons.calendar_month_outlined,
            label: 'Academic Calendar',
          ),
        ),
      );

      expect(
        find.text('Academic Calendar'),
        findsOneWidget,
      );

      expect(
        find.byIcon(Icons.chevron_right_rounded),
        findsNothing,
      );
    },
  );

  testWidgets(
    'future label displays resolved value',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: HomeFeatureTile(
            icon: Icons.emoji_events_outlined,
            labelBuilder: Future.value('Events'),
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Events'),
        findsOneWidget,
      );
    },
  );
}