import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.sceneUrl.isEmpty) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadHtmlString(_buildHtml(widget.sceneUrl));
  }

  String _buildHtml(String url) {
    return '''
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
<spline-viewer url="$url"></spline-viewer>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sceneUrl.isEmpty) {
      return Container(color: Colors.transparent);
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: WebViewWidget(controller: _controller),
    );
  }
}
