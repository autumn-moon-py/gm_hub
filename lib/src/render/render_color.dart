import 'dart:math' as math;

import 'package:flutter/material.dart';

Color colorFromSeed(String id) {
  final seed = id.runes.fold<int>(0, (a, b) => a + b);
  final random = math.Random(seed);
  return Color.fromARGB(
    255,
    90 + random.nextInt(120),
    90 + random.nextInt(120),
    90 + random.nextInt(120),
  );
}
