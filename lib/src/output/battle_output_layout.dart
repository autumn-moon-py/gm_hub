import 'package:flutter/material.dart';

class BattleOutputLayoutMetrics {
  const BattleOutputLayoutMetrics({
    required this.leftClusterAlignment,
    required this.rightClusterAlignment,
    required this.heroWidth,
    required this.heroHeight,
    required this.hudWidth,
    required this.clusterSpacing,
  });

  final Alignment leftClusterAlignment;
  final Alignment rightClusterAlignment;
  final double heroWidth;
  final double heroHeight;
  final double hudWidth;
  final double clusterSpacing;
}

BattleOutputLayoutMetrics computeBattleOutputLayout(BoxConstraints constraints) {
  final shortestSide = constraints.biggest.shortestSide;
  final clampedHeroWidth = (shortestSide * 0.3).clamp(220.0, 380.0);
  final clampedHeroHeight = (constraints.maxHeight * 0.62).clamp(280.0, 620.0);
  final hudWidth = (shortestSide * 0.22).clamp(180.0, 240.0);
  return BattleOutputLayoutMetrics(
    leftClusterAlignment: const Alignment(-0.72, 0.9),
    rightClusterAlignment: const Alignment(0.72, 0.9),
    heroWidth: clampedHeroWidth,
    heroHeight: clampedHeroHeight,
    hudWidth: hudWidth,
    clusterSpacing: 12,
  );
}
