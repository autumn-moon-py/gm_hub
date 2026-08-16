import 'dart:ffi' hide Size;
import 'dart:io' show Platform;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DiceWindowApp extends StatefulWidget {
  final int windowId;

  const DiceWindowApp({super.key, required this.windowId});

  @override
  State<DiceWindowApp> createState() => _DiceWindowAppState();
}

class _DiceWindowAppState extends State<DiceWindowApp> {
  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _fateBonusController =
      TextEditingController(text: '0');
  String _fateModifierMode = 'none';
  String _lastResult = '';
  bool _darkDice = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setAlwaysOnTop();
    });
  }

  Future<void> _initState() async {
    try {
      final state =
          await DesktopMultiWindow.invokeMethod(0, 'dice_get_state', {});
      if (state is Map) {
        _darkDice = state['darkDice'] == true;
        _lastResult = state['lastResult'] ?? '';
        final bonus = state['fateDefaultBonus'];
        if (bonus != null) {
          _fateBonusController.text = bonus.toString();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  void _setAlwaysOnTop() {
    if (!Platform.isWindows) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final getForegroundWindow = user32
          .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');
      final setWindowPos = user32.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');

      final hwnd = getForegroundWindow();
      if (hwnd != 0) {
        const hwndTopmost = -1;
        const swpNomove = 0x0002;
        const swpNosize = 0x0001;
        setWindowPos(hwnd, hwndTopmost, 0, 0, 0, 0, swpNomove | swpNosize);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _formulaController.dispose();
    _fateBonusController.dispose();
    super.dispose();
  }

  Future<void> _rollPreset(int sides) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        0,
        'dice_roll_preset',
        {'sides': sides},
      );
      final text = _extractString(result, 'result');
      if (mounted) {
        setState(() {
          _lastResult = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = '投掷失败: $e';
        });
      }
    }
  }

  Future<void> _rollFate() async {
    try {
      final bonus = int.tryParse(_fateBonusController.text.trim()) ?? 0;
      final result = await DesktopMultiWindow.invokeMethod(
        0,
        'dice_roll_fate',
        {'bonus': bonus, 'modifierMode': _fateModifierMode},
      );
      final text = _extractString(result, 'result');
      if (mounted) {
        setState(() {
          _lastResult = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = '投掷失败: $e';
        });
      }
    }
  }

  Future<void> _rollCustom() async {
    final expr = _formulaController.text.trim();
    if (expr.isEmpty) return;
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        0,
        'dice_roll_custom',
        {'expression': expr},
      );
      final text = _extractString(result, 'result');
      if (mounted) {
        setState(() {
          _lastResult = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = '投掷失败: $e';
        });
      }
    }
  }

  Future<void> _setDarkDice(bool enabled) async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        0,
        'dice_set_dark',
        {'enabled': enabled},
      );
      if (result is Map) {
        _darkDice = result['darkDice'] == true;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clearResult() async {
    try {
      await DesktopMultiWindow.invokeMethod(0, 'dice_clear_flow', {});
    } catch (_) {}
    if (mounted) {
      setState(() {
        _lastResult = '';
      });
    }
  }

  void _setFateModifierMode(String mode, bool enabled) {
    setState(() {
      _fateModifierMode = enabled ? mode : 'none';
    });
  }

  void _adjustFateBonus(int delta) {
    final current = int.tryParse(_fateBonusController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 9999);
    _fateBonusController.value = TextEditingValue(
      text: next.toString(),
      selection: TextSelection.collapsed(offset: next.toString().length),
    );
  }

  String _extractString(dynamic data, String key) {
    if (data is Map) {
      final v = data[key];
      if (v is String) return v;
    }
    if (data is String) return data;
    return data?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      title: '骰子区',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F9FC),
        body: _initialized ? _buildPanel() : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '骰子区',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetButton(4),
                      _buildPresetButton(6),
                      _buildPresetButton(8),
                      _buildPresetButton(10),
                      _buildPresetButton(12),
                      _buildPresetButton(20),
                      _buildPresetButton(100),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 58,
                            height: 32,
                            child: OutlinedButton(
                              onPressed: _rollFate,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('命运'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 24,
                            child: TextField(
                              controller: _fateBonusController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              textAlignVertical: const TextAlignVertical(y: -0.5),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9]*')),
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                hintText: '0',
                                contentPadding: EdgeInsets.only(
                                  left: 3, right: 0, top: 6, bottom: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          OutlinedButton(
                            onPressed: () => _adjustFateBonus(1),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(34, 34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('+', style: TextStyle(fontSize: 14)),
                          ),
                          OutlinedButton(
                            onPressed: () => _adjustFateBonus(-1),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(34, 34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('-', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      _buildCompactCheckItem(
                        label: '暗骰',
                        value: _darkDice,
                        onChanged: _setDarkDice,
                      ),
                      _buildCompactCheckItem(
                        label: '优势',
                        value: _fateModifierMode == 'advantage',
                        onChanged: (v) =>
                            _setFateModifierMode('advantage', v),
                      ),
                      _buildCompactCheckItem(
                        label: '劣势',
                        value: _fateModifierMode == 'disadvantage',
                        onChanged: (v) =>
                            _setFateModifierMode('disadvantage', v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _formulaController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _formulaController,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          labelText: '自定义公式',
                          hintText: '例如：2d6+1',
                          suffixIcon: value.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空',
                                  onPressed: () {
                                    _formulaController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                        onSubmitted: (_) => _rollCustom(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _rollCustom,
                          child: const Text('投掷'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _clearResult,
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _lastResult.isEmpty
                          ? (_darkDice
                              ? '暗骰已开启，完整结果仅保留在骰子区。'
                              : '投掷结果会输出到展示端。')
                          : _lastResult,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(int sides) {
    return SizedBox(
      width: 58,
      height: 32,
      child: OutlinedButton(
        onPressed: () => _rollPreset(sides),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 13),
        ),
        child: Text('d$sides'),
      ),
    );
  }

  Widget _buildCompactCheckItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
