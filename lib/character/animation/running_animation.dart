import 'dart:math';
import '../../models/character/character_profile.dart';
import 'character_animation.dart';

/// Calculates rotation angles for a running animation cycle.
/// 
/// Running is faster and more exaggerated than walking, with:
/// - Higher leg lift
/// - More arm swing
/// - Forward body lean
/// - Both feet off ground at peak stride
class RunningAnimation implements CharacterAnimation {
  /// Maximum rotation angle for upper legs (in radians) - higher than walk
  static const double maxUpperLegAngle = 0.65; // ~37 degrees
  
  /// Maximum rotation angle for lower legs (in radians)
  static const double maxLowerLegAngle = 0.7; // ~40 degrees
  
  /// Maximum rotation angle for feet (in radians)
  static const double maxFootAngle = 0.4; // ~23 degrees
  
  /// Maximum rotation angle for upper arms (in radians) - more swing
  static const double maxUpperArmAngle = 0.55; // ~31 degrees
  
  /// Maximum rotation angle for lower arms (in radians)
  static const double maxLowerArmAngle = 0.45; // ~26 degrees
  
  /// Maximum rotation angle for hands (in radians)
  static const double maxHandAngle = 0.2; // ~11 degrees
  
  /// Head bob amount (in radians)
  static const double maxHeadAngle = 0.04; // ~2.3 degrees
  
  /// Forward lean for torso
  static const double torsoLean = 0.2; // ~12 degrees forward lean
  
  /// Progress through the run cycle (0.0 to 1.0)
  final double progress;
  
  const RunningAnimation(this.progress);
  
  /// Signed power function for sharper extremes.
  double _signedPow(double x, double exp) =>
      x >= 0 ? pow(x, exp).toDouble() : -pow(-x, exp).toDouble();
  
  /// Get the rotation angle for a specific body part.
  double getRotation(CharacterPart part, {bool isBack = false}) {
    // Phase offset: back limbs are 180° out of phase
    final phaseOffset = isBack ? 0.5 : 0.0;
    final phase = (progress + phaseOffset) % 1.0;
    
    // Sharper motion curve for running
    final sineValue = sin(phase * 2 * pi);
    
    switch (part) {
      case CharacterPart.head:
        // Simple bob during run (inherits torso lean from hierarchy)
        return sin(progress * 2 * pi + pi / 2) * maxHeadAngle;
        
      case CharacterPart.torso:
        // Forward lean + slight bounce
        final bounce = sin(progress * 4 * pi) * 0.02; // Double frequency bounce
        return torsoLean + bounce;
        
      case CharacterPart.upperArm:
        // Bigger arm swing when running
        final v = _signedPow(sineValue, 1.3);
        return -v * maxUpperArmAngle * 0.8;
        
      case CharacterPart.lowerArm:
        // Lower arm perpendicular to upper arm + elbow flex during run
        final delayedPhase = (phase - 0.05) % 1.0;
        final delayedSine = sin(delayedPhase * 2 * pi);
        // Base rotation to make arm perpendicular (~90 degrees forward)
        const baseRotation = -pi / 2;
        // Additional bend when arm swings
        final bend = delayedSine.clamp(0.0, 1.0) * maxLowerArmAngle * 0.4;
        return baseRotation - bend;
        
      case CharacterPart.hand:
        final delayedPhase = (phase - 0.08) % 1.0;
        final delayedSine = sin(delayedPhase * 2 * pi);
        return -delayedSine * maxHandAngle * 0.6;
        
      case CharacterPart.upperLeg:
        // Higher knee lift when running
        final v = _signedPow(sineValue, 1.4);
        // More forward swing (higher knee lift), decent back swing
        final forward = v.clamp(-1.0, 0.0) * 1.6;  // increased for higher lift
        final back = v.clamp(0.0, 1.0) * 0.5;
        return (forward + back) * maxUpperLegAngle;
        
      case CharacterPart.lowerLeg:
        // Knee bend during run - both legs should bend
        final v = _signedPow(sineValue, 1.2);
        
        // Both front and back legs need to bend at the knee
        // Bend happens when leg swings (forward swing = knee comes up and bends)
        final forwardBend = (-v).clamp(0.0, 1.0);  // knee bends when leg lifts forward
        final backBend = v.clamp(0.0, 1.0) * 0.5;  // slight bend on back swing too
        return (forwardBend + backBend) * maxLowerLegAngle * 0.8;
        
      case CharacterPart.foot:
        // Active foot motion during run
        final v = sin(phase * 2 * pi);
        return -v * maxFootAngle * 0.6;
    }
  }
  
  /// Get all rotations for the front limbs
  Map<CharacterPart, double> get frontRotations => {
    for (final part in CharacterPart.values)
      part: getRotation(part, isBack: false),
  };
  
  /// Get all rotations for the back limbs
  Map<CharacterPart, double> get backRotations => {
    for (final part in CharacterPart.values)
      part: getRotation(part, isBack: true),
  };
}
