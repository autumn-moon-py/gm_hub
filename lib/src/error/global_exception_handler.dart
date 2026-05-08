import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlobalExceptionHandler {
  GlobalExceptionHandler({
    required this.navigatorKey,
    required this.windowLabel,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String windowLabel;

  FlutterExceptionHandler? _previousFlutterOnError;
  bool Function(Object error, StackTrace stackTrace)? _previousPlatformOnError;
  bool _dialogShowing = false;
  String? _pendingReport;

  void install() {
    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterOnError?.call(details);
      _report(
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        source: 'FlutterError',
      );
    };

    _previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _previousPlatformOnError?.call(error, stackTrace);
      _report(
        error: error,
        stackTrace: stackTrace,
        source: 'PlatformDispatcher',
      );
      return true;
    };
  }

  void handleZoneError(Object error, StackTrace stackTrace) {
    _report(error: error, stackTrace: stackTrace, source: 'runZonedGuarded');
  }

  void tryShowPending() {
    final pending = _pendingReport;
    if (pending == null) {
      return;
    }
    _pendingReport = null;
    _showDialogWithReport(pending);
  }

  void _report({
    required Object error,
    required StackTrace stackTrace,
    required String source,
  }) {
    final report = _buildReport(
      error: error,
      stackTrace: stackTrace,
      source: source,
    );
    debugPrint(report);
    _showDialogWithReport(report);
  }

  String _buildReport({
    required Object error,
    required StackTrace stackTrace,
    required String source,
  }) {
    final now = DateTime.now();
    return [
      'GM Hub 全局异常报告',
      '时间: ${now.toIso8601String()}',
      '窗口: $windowLabel',
      '来源: $source',
      '平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      '',
      '错误:',
      error.toString(),
      '',
      '堆栈:',
      stackTrace.toString(),
    ].join('\n');
  }

  void _showDialogWithReport(String report) {
    if (_dialogShowing) {
      _pendingReport = report;
      return;
    }
    final context = navigatorKey.currentContext;
    if (context == null) {
      _pendingReport = report;
      return;
    }
    _dialogShowing = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _ErrorDialog(
          report: report,
          onExport: () => _exportReport(dialogContext, report),
        ),
      ).whenComplete(() {
        _dialogShowing = false;
        tryShowPending();
      }),
    );
  }

  Future<void> _exportReport(BuildContext context, String report) async {
    try {
      final now = DateTime.now();
      final suggestedName = 'gm_hub_error_${_fileSafeTime(now)}.txt';
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Text', extensions: <String>['txt']),
        ],
      );
      if (location == null) {
        return;
      }
      final target = File(location.path);
      await target.writeAsString(report, encoding: utf8);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到: ${target.path}')));
    } catch (e, st) {
      debugPrint('导出异常报告失败: $e\n$st');
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  String _fileSafeTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$y$m$d-$hh$mm$ss';
  }
}

class _ErrorDialog extends StatelessWidget {
  const _ErrorDialog({required this.report, required this.onExport});

  final String report;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('发生未处理异常'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: SelectableText(report)),
      ),
      actions: [
        TextButton(onPressed: onExport, child: const Text('导出错误内容 TXT')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
