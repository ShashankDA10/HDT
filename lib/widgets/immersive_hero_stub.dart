import 'package:flutter/material.dart';
import 'immersive_hero_config.dart';

class ImmersiveHero extends StatelessWidget {
  final String sceneUrl;
  final BorderRadius borderRadius;

  const ImmersiveHero({
    super.key,
    this.sceneUrl = kSplineSceneUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          '3D unavailable',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
