import 'package:flutter/material.dart';
import '../../character/layout/character_layout.dart';

class CharacterPartWidget extends StatelessWidget {
  final String assetPath;
  final PartLayout layout;
  final double scale;
  final double rotation;
  final bool mirror;

  const CharacterPartWidget({
    super.key,
    required this.assetPath,
    required this.layout,
    required this.scale,
    this.rotation = 0,
    this.mirror = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      assetPath,
      fit: BoxFit.contain,
      // Ignore errors gracefully; show placeholder if asset is missing
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.red.withOpacity(0.3),
          child: const Center(child: Icon(Icons.error, color: Colors.white)),
        );
      },
    );

    // Apply mirroring for left-side limbs
    if (mirror) {
      imageWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
        child: imageWidget,
      );
    }

    // Apply rotation around pivot
    if (rotation != 0) {
      imageWidget = Transform(
        alignment: Alignment(
          layout.pivot.dx * 2 - 1, // Convert 0-1 to -1 to 1
          layout.pivot.dy * 2 - 1,
        ),
        transform: Matrix4.identity()..rotateZ(rotation),
        child: imageWidget,
      );
    }

    return Positioned(
      left: layout.position.dx * scale,
      top: layout.position.dy * scale,
      width: layout.size.width * scale,
      height: layout.size.height * scale,
      child: imageWidget,
    );
  }
}

/// Helper function to build character parts.
Widget buildCharacterPart({
  required String assetPath,
  required PartLayout layout,
  required double scale,
  double rotation = 0,
  bool mirror = false,
}) {
  return CharacterPartWidget(
    assetPath: assetPath,
    layout: layout,
    scale: scale,
    rotation: rotation,
    mirror: mirror,
  );
}
