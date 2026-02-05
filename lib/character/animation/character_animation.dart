import '../../models/character/character_profile.dart';

/// Base interface for character animations.
/// Allows different animation types (walk, run, etc.) to be used interchangeably.
abstract class CharacterAnimation {
  /// Get the rotation angle for a specific body part.
  double getRotation(CharacterPart part, {bool isBack = false});
}
