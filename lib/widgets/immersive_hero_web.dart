// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'immersive_hero_config.dart';

class ImmersiveHero extends StatefulWidget {
  final String sceneUrl;
  final BorderRadius borderRadius;

  const ImmersiveHero({
    super.key,
    this.sceneUrl = kSplineSceneUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
  });

  @override
  State<ImmersiveHero> createState() => _ImmersiveHeroState();
}

class _ImmersiveHeroState extends State<ImmersiveHero> {
  late final String _viewId;
  static final Set<String> _registered = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.sceneUrl.isEmpty) {
      return;
    }
    _viewId = 'spline-hero-${widget.sceneUrl.hashCode}';
    if (_registered.add(_viewId)) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (_) {
          final htmlString = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script type="module" src="https://unpkg.com/@splinetool/viewer/build/spline-viewer.js"></script>
<style>
html, body { margin: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
spline-viewer { width: 100%; height: 100%; background: transparent; }
</style>
</head>
<body>
<spline-viewer url="${widget.sceneUrl}"></spline-viewer>
</body>
</html>
''';
          return html.IFrameElement()
            ..srcdoc = htmlString
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.borderRadius = '0';
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sceneUrl.isEmpty) {
      return Container(
        color: Colors.transparent,
      );
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
