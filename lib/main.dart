import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/error/global_exception_handler.dart';
import 'src/dice_window_app.dart';
import 'src/output_window_app.dart';

Future<void> main(List<String> args) async {
  final navigatorKey = GlobalKey<NavigatorState>();

  final multiWindowIndex = args.indexOf('multi_window');
  final isOutputMarker = args.contains('output');
  final isDiceMarker = args.contains('dice');
  final isOutputWindow = multiWindowIndex >= 0 || isOutputMarker;
  final isDiceWindow = isDiceMarker;

  final exceptionHandler = GlobalExceptionHandler(
    navigatorKey: navigatorKey,
    windowLabel: isOutputWindow
        ? '输出窗口'
        : isDiceWindow
            ? '骰子窗口'
            : '主窗口',
  );

  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    exceptionHandler.install();

    if (isDiceWindow) {
      var windowId = 0;
      if (multiWindowIndex >= 0 && multiWindowIndex + 1 < args.length) {
        windowId = int.tryParse(args[multiWindowIndex + 1]) ?? 0;
      }
      runApp(DiceWindowApp(windowId: windowId));
    } else if (isOutputWindow) {
      var windowId = 0;
      if (multiWindowIndex >= 0 && multiWindowIndex + 1 < args.length) {
        windowId = int.tryParse(args[multiWindowIndex + 1]) ?? 0;
      }
      runApp(OutputWindowApp(windowId: windowId, navigatorKey: navigatorKey));
    } else {
      String? startupProjectPath;
      if (args.isNotEmpty) {
        final first = args.first;
        if (first.startsWith('--project=')) {
          startupProjectPath = first.substring('--project='.length);
        } else if (!first.startsWith('--')) {
          startupProjectPath = first;
        }
      }
      runApp(
        GmHubApp(
          initialProjectFilePath: startupProjectPath,
          navigatorKey: navigatorKey,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      exceptionHandler.tryShowPending();
    });
  }, exceptionHandler.handleZoneError);
}
