import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../facade/project_ui_facade.dart';
import 'dice/dice_preset_button.dart';

class DicePanel extends StatefulWidget {
  final DiceControlFacade facade;

  const DicePanel({super.key, required this.facade});

  @override
  State<DicePanel> createState() => _DicePanelState();
}

class _DicePanelState extends State<DicePanel> {
  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _fateBonusController =
      TextEditingController(text: '0');
  String _lastResult = '';

  @override
  void dispose() {
    _formulaController.dispose();
    _fateBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.facade.dicePanelCollapsed;
    return Container(
      width: collapsed ? 46 : 250,
      margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
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
                    IconButton(
                      onPressed: widget.facade.toggleDicePanelCollapsed,
                      tooltip: '折叠骰子面板',
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ],
                ),
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
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: '0',
                              contentPadding: EdgeInsets.only(
                                left: 3,
                                right: 0,
                                top: 6,
                                bottom: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 31,
                          height: 32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF9DB0BF),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: _bonusStepButton(
                                    label: '+',
                                    onPressed: () => _adjustFateBonus(1),
                                    top: true,
                                    offsetY: -3,
                                  ),
                                ),
                                const Divider(height: 1, thickness: 1),
                                Expanded(
                                  child: _bonusStepButton(
                                    label: '-',
                                    onPressed: () => _adjustFateBonus(-1),
                                    top: false,
                                    offsetY: -7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 0),
                InkWell(
                  onTap: () {
                    widget.facade.setDarkDiceEnabled(!darkDiceEnabled);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: darkDiceEnabled,
                        onChanged: (value) {
                          widget.facade.setDarkDiceEnabled(value ?? false);
                          setState(() {});
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 1),
                      const Text(
                        '暗骰',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
    final result = widget.facade.rollFateDice(bonus: bonus);
    setState(() {
      _lastResult = result;
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

  Widget _bonusStepButton({
    required String label,
    required VoidCallback onPressed,
    required bool top,
    required double offsetY,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.vertical(
          top: top ? const Radius.circular(5) : Radius.zero,
          bottom: top ? Radius.zero : const Radius.circular(5),
        ),
        child: SizedBox.expand(
          child: Center(
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2B3C47),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
