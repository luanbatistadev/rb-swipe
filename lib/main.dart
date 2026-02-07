import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'screens/gallery_screen.dart';
import 'services/kept_media_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      tz.initializeTimeZones();
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));

      await Future.wait([
        KeptMediaService().init(),
        NotificationService().initialize(),
      ]);

      await NotificationService().scheduleRecurringNotifications();

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );

      runApp(const SwipeCleanerApp());
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class SwipeCleanerApp extends StatelessWidget {
  const SwipeCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RB Swipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f0f1a),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFFA29BFE),
          surface: Color(0xFF1a1a2e),
          error: Color(0xFFFF4757),
        ),
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      ),
      home: const GalleryScreen(),
    );
  }
}
