import 'dart:convert';

import 'package:flutter/material.dart';

/// Retains one image provider per mounted icon, not per library refresh.
/// SQLite reloads create new models; unchanged PNG content must keep its
/// provider/decoded frame instead of briefly going blank on every timer tick.
class ApplicationIconImage extends StatefulWidget {
  const ApplicationIconImage({
    super.key,
    required this.encoded,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String encoded;
  final double? width, height;
  final String? semanticLabel;

  @override
  State<ApplicationIconImage> createState() => _ApplicationIconImageState();
}

class _ApplicationIconImageState extends State<ApplicationIconImage> {
  MemoryImage? image;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ApplicationIconImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encoded != widget.encoded) load();
  }

  void load() {
    try {
      image = MemoryImage(base64Decode(widget.encoded));
    } on FormatException {
      image = null;
    }
  }

  Widget unavailable() => SizedBox(
    width: widget.width,
    height: widget.height,
    child: const Icon(Icons.broken_image_outlined),
  );

  @override
  Widget build(BuildContext context) {
    final provider = image;
    if (provider == null) return unavailable();
    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      semanticLabel: widget.semanticLabel,
      // Do not retain another application's old image when content changes.
      gaplessPlayback: false,
      errorBuilder: (_, _, _) => unavailable(),
    );
  }
}
