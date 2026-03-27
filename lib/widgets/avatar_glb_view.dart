import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'avatar_file_loader_stub.dart'
    if (dart.library.io) 'avatar_file_loader_io.dart';

class AvatarGlbView extends StatefulWidget {
  final String? avatarUrl;
  final double size;

  const AvatarGlbView({super.key, this.avatarUrl, this.size = 140});

  @override
  State<AvatarGlbView> createState() => _AvatarGlbViewState();
}

class _AvatarGlbViewState extends State<AvatarGlbView> {
  String? _resolvedSrc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveSrc();
  }

  @override
  void didUpdateWidget(AvatarGlbView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _resolveSrc();
    }
  }

  Future<void> _resolveSrc() async {
    setState(() => _loading = true);
    final url = widget.avatarUrl;

    // Local file path (mobile only) — convert to base64 data URI
    if (url != null && url.isNotEmpty && !url.startsWith('http') && !url.startsWith('assets')) {
      final dataUri = await readLocalGlbAsDataUri(url);
      if (mounted) {
        setState(() {
          _resolvedSrc = dataUri ?? 'assets/images/avatar.glb';
          _loading = false;
        });
      }
      return;
    }

    // Remote URL or default asset
    if (mounted) {
      setState(() {
        _resolvedSrc = (url != null && url.startsWith('http')) ? url : 'assets/images/avatar.glb';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _resolvedSrc == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blueAccent),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ModelViewer(
        src: _resolvedSrc!,
        alt: "Your 3D Avatar",
        autoRotate: false,
        autoRotateDelay: 0,
        rotationPerSecond: "6deg",
        cameraControls: false,
        cameraOrbit: "0deg 78deg auto",
        cameraTarget: "0m 0.9m 0m",
        fieldOfView: "28deg",
        interactionPrompt: InteractionPrompt.none,
        autoPlay: false,
        disableZoom: true,
        disablePan: true,
        shadowIntensity: 0,
        exposure: 0.9,
      ),
    );
  }
}
