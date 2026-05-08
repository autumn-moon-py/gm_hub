import 'package:flutter/material.dart';

class DicePresetButton extends StatelessWidget {
  const DicePresetButton({
    super.key,
    required this.sides,
    required this.onRoll,
  });

  final int sides;
  final ValueChanged<int> onRoll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 32,
      child: OutlinedButton(
        onPressed: () => onRoll(sides),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text('d$sides'),
      ),
    );
  }
}
