import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controller/project_controller.dart';
import '../../store/project_store.dart';
import '../facade/project_ui_facade.dart';
import 'dice/dice_preset_button.dart';

enum DicePanelMode { scene, battle }

class DicePanel extends StatefulWidget {
  final DiceControlFacade facade;
  final EdgeInsetsGeometry margin;
  final DicePanelMode mode;
  final int fateDefaultBonus;

  const DicePanel({
    super.key,
    required this.facade,
    this.margin = const EdgeInsets.fromLTRB(12, 12, 0, 12),
    this.mode = DicePanelMode.scene,
    this.fateDefaultBonus = 0,
  });

  @override
  State<DicePanel> createState() => _DicePanelState();
}

class _DicePanelState extends State<DicePanel> {
  final TextEditingController _formulaController = TextEditingController();
  late final TextEditingController _fateBonusController;
  FateDiceModifierMode _fateModifierMode = FateDiceModifierMode.none;
  String _lastResult = '';

  @override
  void initState() {
    super.initState();
    _fateBonusController = TextEditingController(
      text: widget.fateDefaultBonus.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant DicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fateDefaultBonus != oldWidget.fateDefaultBonus) {
      _fateBonusController.text = widget.fateDefaultBonus.toString();
    }
  }

  @override
  void dispose() {
    _formulaController.dispose();
    _fateBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBattle = widget.mode == DicePanelMode.battle;
    final collapsed = isBattle ? false : widget.facade.dicePanelCollapsed;
    return Container(
      width: collapsed ? 46 : 250,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCEDAE3)),
      ),
      child: collapsed ? _collapsedPanel() : _expandedPanel(),
    );
  }

  Widget _collapsedPanel() {
    return Column(
      children: [
        IconButton(
          onPressed: widget.facade.toggleDicePanelCollapsed,
          tooltip: '展开骰子面板',
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 8),
        const Text(
          '骰\n子\n区',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.25),
        ),
      ],
    );
  }

  Widget _expandedPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryNarrow = constraints.maxWidth < 140;
        final darkDiceEnabled = widget.facade.darkDiceEnabled;
        final isBattle = widget.mode == DicePanelMode.battle;
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isVeryNarrow ? '骰子区' : '骰子区',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!isBattle) ...[
                      IconButton(
                        onPressed: () => Get.find<ProjectController>().openDiceWindow(),
                        tooltip: '弹出为独立窗口',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: widget.facade.toggleDicePanelCollapsed,
                        tooltip: '折叠骰子面板',
                        icon: const Icon(Icons.chevron_left),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (isBattle) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                            contentPadding: EdgeInsets.only(left: 3, right: 0, top: 6, bottom: 6),
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _adjustFateBonus(1),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(34, 34),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('-', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _formulaController,
                      builder: (context, value, child) {
                        return TextField(
                          controller: _formulaController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            hintText: 'd20 / 2d6+3',
                            contentPadding: const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 6),
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
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactCheckItem(
                        label: '暗骰',
                        value: darkDiceEnabled,
                        onChanged: (value) {
                          widget.facade.setDarkDiceEnabled(value);
                          setState(() {});
                        },
                      ),
                      _buildCompactCheckItem(
                        label: '优势',
                        value: _fateModifierMode == FateDiceModifierMode.advantage,
                        onChanged: (value) => _setFateModifierMode(FateDiceModifierMode.advantage, value),
                      ),
                      _buildCompactCheckItem(
                        label: '劣势',
                        value: _fateModifierMode == FateDiceModifierMode.disadvantage,
                        onChanged: (value) => _setFateModifierMode(FateDiceModifierMode.disadvantage, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                ] else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    DicePresetButton(sides: 4, onRoll: _rollPreset),
                    DicePresetButton(sides: 6, onRoll: _rollPreset),
                    DicePresetButton(sides: 8, onRoll: _rollPreset),
                    DicePresetButton(sides: 10, onRoll: _rollPreset),
                    DicePresetButton(sides: 12, onRoll: _rollPreset),
                    DicePresetButton(sides: 20, onRoll: _rollPreset),
                    DicePresetButton(sides: 100, onRoll: _rollPreset),
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
                              contentPadding: EdgeInsets.only(left: 3, right: 0, top: 6, bottom: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        OutlinedButton(
                          onPressed: () => _adjustFateBonus(1),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(34, 34),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('-', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 0),
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    _buildCompactCheckItem(
                      label: '暗骰',
                      value: darkDiceEnabled,
                      onChanged: (value) {
                        widget.facade.setDarkDiceEnabled(value);
                        setState(() {});
                      },
                    ),
                    _buildCompactCheckItem(
                      label: '优势',
                      value: _fateModifierMode == FateDiceModifierMode.advantage,
                      onChanged: (value) => _setFateModifierMode(FateDiceModifierMode.advantage, value),
                    ),
                    _buildCompactCheckItem(
                      label: '劣势',
                      value: _fateModifierMode == FateDiceModifierMode.disadvantage,
                      onChanged: (value) => _setFateModifierMode(FateDiceModifierMode.disadvantage, value),
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
                ],
                Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _lastResult.isEmpty
                        ? (darkDiceEnabled
                            ? '暗骰已开启，完整结果仅保留在骰子区。'
                            : '投掷结果会输出到展示端。')
                        : _lastResult,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _rollCustom() {
    final expr = _formulaController.text.trim();
    if (expr.isEmpty) {
      return;
    }
    final result = widget.facade.rollDice(expr);
    setState(() {
      _lastResult = result;
    });
  }

  void _clearResult() {
    widget.facade.clearFlowMessages();
    setState(() {
      _lastResult = '';
    });
  }

  void _rollPreset(int sides) {
    final result = widget.facade.rollPresetDice(sides);
    setState(() {
      _lastResult = result;
    });
  }

  void _rollFate() {
    final bonus = int.tryParse(_fateBonusController.text.trim()) ?? 0;
    final result = widget.facade.rollFateDice(
      bonus: bonus,
      modifierMode: _fateModifierMode,
    );
    setState(() {
      _lastResult = result;
    });
  }

  void _setFateModifierMode(FateDiceModifierMode mode, bool enabled) {
    setState(() {
      _fateModifierMode = enabled ? mode : FateDiceModifierMode.none;
    });
  }

  void _adjustFateBonus(int delta) {
    final current = int.tryParse(_fateBonusController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 9999);
    _fateBonusController.value = TextEditingValue(
      text: next.toString(),
      selection: TextSelection.collapsed(
        offset: next.toString().length,
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
