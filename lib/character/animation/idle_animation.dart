import 'dart:math';
import '../../models/character/character_profile.dart';
import 'character_animation.dart';

/// Calculates rotation angles for an idle/standing animation cycle.
/// 
/// Idle is a subtle animation with:
/// - Gentle breathing motion (torso rises/falls)
/// - Slight head movement
/// - Arms hanging naturally with subtle sway
/// - Legs stationary with minor weight shift
class IdleAnimation implements CharacterAnimation {
  /// Breathing intensity for torso (in radians)
  static const double breathAmount = 0.02; // ~1.1 degrees
  
  /// Head subtle movement (in radians)
  static const double headSway = 0.03; // ~1.7 degrees
  
  /// Arm gentle sway (in radians)
  static const double armSway = 0.04; // ~2.3 degrees
  
  /// Weight shift amount for legs (in radians)
  static const double legSway = 0.015; // ~0.9 degrees
  
  /// Progress through the idle cycle (0.0 to 1.0)
  final double progress;
  
  const IdleAnimation(this.progress);
  
  /// Get the rotation angle for a specific body part.
  @override
  double getRotation(CharacterPart part, {bool isBack = false}) {
    // Slow, smooth sine wave for breathing
    final breathPhase = sin(progress * 2 * pi);
    
    // Even slower wave for subtle weight shifting
    final swayPhase = sin(progress * 2 * pi + pi / 3);
    
    // Slight variation for back limbs
    final limbOffset = isBack ? 0.2 : 0.0;
    
    switch (part) {
      case CharacterPart.head:
        // Subtle look around / bob with breathing
        return breathPhase * headSway * 0.5 + swayPhase * headSway * 0.3;
        
      case CharacterPart.torso:
        // Breathing motion - slight rise and fall
        return breathPhase * breathAmount;
        
      case CharacterPart.upperArm:
        // Arms hang with gentle sway
        final armPhase = sin((progress + limbOffset) * 2 * pi);
        return armPhase * armSway * 0.5;
        
      case CharacterPart.lowerArm:
        // Slight natural bend, subtle movement
        final armPhase = sin((progress + limbOffset + 0.1) * 2 * pi);
        return -0.15 + armPhase * armSway * 0.3; // Slight bend + sway
        
      case CharacterPart.hand:
        // Minimal hand movement
        final handPhase = sin((progress + limbOffset + 0.15) * 2 * pi);
        return handPhase * 0.02;
        
      case CharacterPart.upperLeg:
        // Very subtle weight shift
        return swayPhase * legSway * (isBack ? -1 : 1);
        
      case CharacterPart.lowerLeg:
        // Legs straight, minimal motion
        return swayPhase * legSway * 0.3;
        
      case CharacterPart.foot:
        // Feet planted, very minimal
        return swayPhase * 0.01;
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
