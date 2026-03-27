import 'package:flutter/material.dart';

class AvatarGlbView extends StatelessWidget {
  final double size;

  const AvatarGlbView({super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.person, size: size, color: Colors.white54),
    );
  }
}
