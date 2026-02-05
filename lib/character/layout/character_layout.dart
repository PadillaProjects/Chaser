import 'dart:math';
import 'dart:ui';
import '../../models/character/character_profile.dart';

const double DESIGN_SIZE = 512.0;

class PartLayout {
  final Offset position; // top-left in 512 space (where art is drawn inside PNG)
  final Size size;       // actual art size in 512 space
  final Offset pivot;    // rotation origin (0–1 normalized within the art bounds)

  const PartLayout({
    required this.position,
    required this.size,
    this.pivot = const Offset(0.5, 0.5),
  });

  /// Get the absolute pivot point in 512 space
  Offset get absolutePivot => Offset(
    position.dx + size.width * pivot.dx,
    position.dy + size.height * pivot.dy,
  );

  /// Get the attachment point (bottom center of the part) for chaining
  Offset get attachmentPoint => Offset(
    position.dx + size.width * 0.5,
    position.dy + size.height, // bottom of the art
  );
}

// --- Head & Torso (absolute positioned) ---

const headLayout = PartLayout(
  position: Offset(144, 64),
  size: Size(224, 224),
  pivot: Offset(0.5, 0.6),
);

const torsoLayout = PartLayout(
  position: Offset(126, 256),
  size: Size(260, 200),
  pivot: Offset(0.5, 0.4),
);

// --- Arm parts (will be chained) ---
const upperArmLayout = PartLayout(
  position: Offset(226, 200),
  size: Size(80, 180),
  pivot: Offset(0.5, 0.12), // Inside blob, not exact top
);

const lowerArmLayout = PartLayout(
  position: Offset(221, 240),  // moved left (231->221) and down (220->240)
  size: Size(70, 160),
  pivot: Offset(0.5, 0.10),
);

const handLayout = PartLayout(
  position: Offset(228, 260),
  size: Size(72, 72),
  pivot: Offset(0.5, 0.15),
);

// --- Leg parts (will be chained) ---
// Upper leg attaches at hip (torso bottom area)
const upperLegLayout = PartLayout(
  position: Offset(221, 300),
  size: Size(70, 170),
  pivot: Offset(0.5, 0.0), // pivot at top (hip)
);

const lowerLegLayout = PartLayout(
  position: Offset(226, 330),
  size: Size(60, 150),
  pivot: Offset(0.5, 0.0), // pivot at top (knee)
);

const footLayout = PartLayout(
  position: Offset(211, 390),
  size: Size(90, 45),
  pivot: Offset(0.5, 0.0), // pivot at top (ankle)
);

// Canonical Part Map
const characterLayout = {
  CharacterPart.head: headLayout,
  CharacterPart.torso: torsoLayout,
  CharacterPart.upperArm: upperArmLayout,
  CharacterPart.lowerArm: lowerArmLayout,
  CharacterPart.hand: handLayout,
  CharacterPart.upperLeg: upperLegLayout,
  CharacterPart.lowerLeg: lowerLegLayout,
  CharacterPart.foot: footLayout,
};

// --- Joint Offsets for Chaining ---
// These define how child parts attach to parent parts in 512 space

/// Shoulder position relative to torso (where arm attaches)
const Offset shoulderOffset = Offset(256, 280); // Near top-right of torso

/// Hip position relative to torso (where leg attaches)  
const Offset hipOffset = Offset(256, 440); // Near bottom of torso

/// How far down from parent's attachment point the child should be placed
const double armChainGap = 0; // No gap, parts touch
const double legChainGap = 0;

double scaleFor(Size renderSize) {
  return min(
    renderSize.width / DESIGN_SIZE,
    renderSize.height / DESIGN_SIZE,
  );
}
