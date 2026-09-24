import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'src/presentation/routes/app_router.dart';
import 'src/presentation/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp();
  debugPrint(
    'Background notice received: ${message.notification?.title}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  await _requestNotificationPermissions();

  runApp(
    const ProviderScope(
      child: ScreenUtilInit(
        designSize: Size(440, 960),
        minTextAdapt: true,
        splitScreenMode: true,
        child: MyApp(),
      ),
    ),
  );
}

Future<void> _requestNotificationPermissions() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  switch (settings.authorizationStatus) {
    case AuthorizationStatus.authorized:
      debugPrint('User granted notification permissions');
      break;

    case AuthorizationStatus.provisional:
      debugPrint(
        'User granted provisional notification permissions',
      );
      break;

    case AuthorizationStatus.denied:
    case AuthorizationStatus.notDetermined:
      debugPrint(
        'User declined or has not accepted notification permissions',
      );
      break;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BGCTUB Companion',

      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      initialRoute: AppRoutes.auth,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}