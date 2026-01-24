import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/date_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(const SwipeCleanerApp());
}

class SwipeCleanerApp extends StatelessWidget {
  const SwipeCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swipe Cleaner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0f0f1a),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFFA29BFE),
          surface: const Color(0xFF1a1a2e),
          error: const Color(0xFFFF4757),
        ),
        fontFamily: 'SF Pro Display',
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      ),
      home: const DateSelectionScreen(),
    );
  }
}
