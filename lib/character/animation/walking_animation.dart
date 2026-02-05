import 'dart:math';
import '../../models/character/character_profile.dart';
import 'character_animation.dart';

/// Calculates rotation angles for a walking animation cycle.
/// 
/// The walk cycle is represented by a progress value from 0.0 to 1.0,
/// where 0.0 and 1.0 represent the same pose (one complete walk cycle).
class WalkingAnimation implements CharacterAnimation {
  /// Maximum rotation angle for upper legs (in radians)
  static const double maxUpperLegAngle = 0.45; // ~26 degrees
  
  /// Maximum rotation angle for lower legs (in radians)
  static const double maxLowerLegAngle = 0.55; // ~31 degrees
  
  /// Maximum rotation angle for feet (in radians)
  static const double maxFootAngle = 0.3; // ~17 degrees
  
  /// Maximum rotation angle for upper arms (in radians)
  static const double maxUpperArmAngle = 0.4; // ~23 degrees
  
  /// Maximum rotation angle for lower arms (in radians)
  static const double maxLowerArmAngle = 0.3; // ~17 degrees
  
  /// Maximum rotation angle for hands (in radians)
  static const double maxHandAngle = 0.15; // ~9 degrees
  
  /// Slight head bob amount (in radians)
  static const double maxHeadAngle = 0.025; // ~1.5 degrees
  
  /// Progress through the walk cycle (0.0 to 1.0)
  final double progress;
  
  const WalkingAnimation(this.progress);
  
  /// Clamp motion to a specific phase window with eased in/out motion.
  /// Returns 0 outside [start, end], smooth 0→1→0 arc inside.
  double _clampToPhase(double phase, double start, double end) {
    double p = (phase - start) / (end - start);
    if (p < 0 || p > 1) return 0;
    return 0.5 - 0.5 * cos(p * pi); // ease in/out
  }
  
  /// Signed power function for sharper extremes.
  /// Preserves sign while applying power.
  double _signedPow(double x, double exp) =>
      x >= 0 ? pow(x, exp).toDouble() : -pow(-x, exp).toDouble();
  
  /// Get the rotation angle for a specific body part.
  /// 
  /// [part] - The body part to get rotation for
  /// [isBack] - Whether this is the back limb (opposite phase from front)
  /// 
  /// Returns rotation in radians. Positive = clockwise, Negative = counter-clockwise.
  double getRotation(CharacterPart part, {bool isBack = false}) {
    // Phase offset: back limbs are 180° out of phase with front limbs
    final phaseOffset = isBack ? 0.5 : 0.0;
    final phase = (progress + phaseOffset) % 1.0;
    
    // Main sinusoidal motion with sharper extremes
    final sineValue = sin(phase * 2 * pi);
    
    switch (part) {
      case CharacterPart.head:
        // Single clean bob per step, not nervous double-bob
        return sin(progress * 2 * pi + pi / 2) * maxHeadAngle;
        
      case CharacterPart.torso:
        // Small forward/back lean once per step
        return sin(progress * 2 * pi) * 0.02;
        
      case CharacterPart.upperArm:
        // Arms swing opposite to legs - gentler motion
        final v = _signedPow(sineValue, 1.5);
        return -v * maxUpperArmAngle * 0.6;  // Reduced swing
        
      case CharacterPart.lowerArm:
        // Lower arms follow upper arms with slight delay
        final delayedPhase = (phase - 0.08) % 1.0;
        final delayedSine = sin(delayedPhase * 2 * pi);
        final v = _signedPow(delayedSine, 1.3);
        return -v * maxLowerArmAngle * 0.5;  // Reduced swing
        
      case CharacterPart.hand:
        // Hands follow lower arms with slight additional delay
        final delayedPhase = (phase - 0.12) % 1.0;
        final delayedSine = sin(delayedPhase * 2 * pi);
        return -delayedSine * maxHandAngle * 0.4;  // Reduced swing
        
      case CharacterPart.upperLeg:
        // Legs drive the walk with sharper extremes
        final v = _signedPow(sineValue, 1.5);
        
        // Swing forward (negative) with slight back swing (positive, 20% max)
        // Phase offset handles the alternation timing
        final forward = v.clamp(-1.0, 0.0) * 1.2;  // full forward swing
        final back = v.clamp(0.0, 1.0) * 0.2;       // subtle back swing
        return (forward + back) * maxUpperLegAngle;
        
      case CharacterPart.lowerLeg:
        // Lower leg follows upper leg with knee bend during swing
        final v = _signedPow(sineValue, 1.3);
        
        if (isBack) {
          // Back lower leg: bends when upper leg swings back
          // Small positive bend follows the backward swing
          final bend = v.clamp(0.0, 1.0);
          return bend * maxLowerLegAngle * 0.6;
        } else {
          // Front lower leg: bends during forward swing
          // Knee bends backward (positive) when leg swings forward
          final swing = (-v).clamp(0.0, 1.0);  // Convert forward motion to bend
          return swing * maxLowerLegAngle * 0.5;
        }
        
      case CharacterPart.foot:
        // Foot follows leg motion with gentle flex
        // Simple sine motion that matches leg swing timing
        final v = sin(phase * 2 * pi);
        // Slight toe-up when leg swings forward, toe-down on back swing
        return -v * maxFootAngle * 0.5;
    }
  }
  
  /// Convenience: Get all rotations for the front limbs
  Map<CharacterPart, double> get frontRotations => {
    for (final part in CharacterPart.values)
      part: getRotation(part, isBack: false),
  };
  
  /// Convenience: Get all rotations for the back limbs
  Map<CharacterPart, double> get backRotations => {
    for (final part in CharacterPart.values)
      part: getRotation(part, isBack: true),
  };
}

