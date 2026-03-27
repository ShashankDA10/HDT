// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class AvatarGlbView extends StatefulWidget {
  final double size;

  const AvatarGlbView({super.key, this.size = 140});

  @override
  State<AvatarGlbView> createState() => _AvatarGlbViewState();
}

class _AvatarGlbViewState extends State<AvatarGlbView> {
  static const String _viewId = 'avatar-glb-view';
  static bool _registered = false;

  @override
  void initState() {
    super.initState();
    if (_registered) return;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (_) {
        final baseUrl = html.window.location.origin;
        return html.IFrameElement()
          ..srcdoc = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script type="module"
 src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.3.0/model-viewer.min.js">
</script>
<style>
html, body {
  margin: 0;
  width: 100%;
  height: 100%;
  background: transparent;
}
model-viewer {
  width: 100%;
  height: 100%;
  background: transparent;
  pointer-events: none;
}
</style>
</head>
<body>
<model-viewer
 src="$baseUrl/assets/images/avatar.glb"
 camera-orbit="0deg 70deg 55%"
 camera-target="0m 1.45m 0m"
 field-of-view="22deg">
</model-viewer>
</body>
</html>
'''
          ..style.border = 'none'
          ..style.pointerEvents = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
      },
    );
    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewId);
  }
}
