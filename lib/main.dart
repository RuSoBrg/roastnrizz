import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:roast_n_rizz/config/app_config.dart';
import 'package:roast_n_rizz/l10n/app_localizations.dart';
import 'package:roast_n_rizz/pages/homePage/home_page_widget.dart';

/// Starts the application.
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      
      // Initialize App Check for security
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
      
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      if (kDebugMode) debugPrint("Firebase initialization failed: $e");
    }

    await AppConfig.loadEnv();
    
    // Initialize AdMob
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint("AdMob initialization failed: $e");
    }

    runApp(const RoastNRizzApp());
  } catch (e, stack) {
    if (kDebugMode) debugPrint("Critical startup error: $e\n$stack");
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Error: $e")))));
  }
}

/// Root widget containing the app-wide visual theme and home route.
class RoastNRizzApp extends StatelessWidget {
  const RoastNRizzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoastNRizz',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB23AE8),
          brightness: Brightness.dark, 
        ),
        scaffoldBackgroundColor: Colors.black, 
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white10, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x14000000)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x14000000)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomePageWidget(),
    );
  }
}
