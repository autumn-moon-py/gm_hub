import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'router/app_pages.dart';
import 'router/app_routes.dart';

class GmHubApp extends StatelessWidget {
  final String? initialProjectFilePath;
  final GlobalKey<NavigatorState> navigatorKey;

  const GmHubApp({
    super.key,
    this.initialProjectFilePath,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
      ],
      navigatorKey: navigatorKey,
      title: '主持中枢',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
      ),
      initialRoute: AppRoutes.main,
      getPages: AppPages.routes(initialProjectFilePath: initialProjectFilePath),
    );
  }
}
