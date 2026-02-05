import 'package:flutter/material.dart';
import '../../models/character/character_profile.dart';
import '../layout/character_layout.dart';
import '../animation/character_animation.dart';
import '../animation/walking_animation.dart';
import '../animation/running_animation.dart';
import '../animation/idle_animation.dart';

/// Animation types available for the character
enum AnimationType { idle, walk, run }

/// Renders a character by stacking all part images on top of each other.
/// Each part PNG is 512x512 with the part drawn at its correct position,
/// so stacking them naturally forms the complete character.
/// 
/// When [animationProgress] is provided, applies animation rotations.
class CharacterAvatar extends StatelessWidget {
  final CharacterProfile profile;
  final double size;
  
  /// Animation progress from 0.0 to 1.0 (one complete cycle).
  /// If null, character is rendered in static pose.
  final double? animationProgress;
  
  /// Type of animation to play
  final AnimationType animationType;

  const CharacterAvatar({
    super.key,
    required this.profile,
    this.size = 256,
    this.animationProgress,
    this.animationType = AnimationType.walk,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = scaleFor(Size(size, size));
    
    CharacterAnimation? animation;
    if (animationProgress != null) {
      switch (animationType) {
        case AnimationType.idle:
          animation = IdleAnimation(animationProgress!);
          break;
        case AnimationType.walk:
          animation = WalkingAnimation(animationProgress!);
          break;
        case AnimationType.run:
          animation = RunningAnimation(animationProgress!);
          break;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Back limbs (behind body, with reduced opacity for depth)
          ..._buildLimbSet(scale, animation, isBack: true, opacity: 0.7),
          
          // Core body (torso with head and arms as children, so they follow torso rotation)
          _buildTorsoHierarchy(scale, animation),
          
          // Legs in front
          _buildLegHierarchy(scale, animation, isBack: false, opacity: 1.0),
        ],
      ),
    );
  }
  
  /// Build torso with head and front arms as children (they follow torso rotation)
  Widget _buildTorsoHierarchy(double scale, CharacterAnimation? animation) {
    final torsoLayout = characterLayout[CharacterPart.torso]!;
    final torsoRotation = animation?.getRotation(CharacterPart.torso, isBack: false) ?? 0.0;
    
    // Build torso with children
    Widget torso = Stack(
      clipBehavior: Clip.none,
      children: [
        _buildPartImage(CharacterPart.torso, scale, 1.0),
        // Front arm as child of torso
        _buildArmHierarchy(scale, animation, isBack: false, opacity: 1.0),
        // Head as child of torso
        _buildPart(CharacterPart.head, scale, animation, isBack: false),
      ],
    );
    
    // Apply torso rotation - head and arms will move with it
    torso = _applyRotation(torso, torsoRotation, torsoLayout);
    
    return Positioned(left: 0, top: 0, child: torso);
  }

  /// Build a complete set of limbs (arm and leg) with hierarchical transforms
  /// Each part inherits the transform of its parent
  List<Widget> _buildLimbSet(double scale, CharacterAnimation? animation, {
    required bool isBack,
    required double opacity,
  }) {
    return [
      // Leg hierarchy: upper leg -> lower leg -> foot
      _buildLegHierarchy(scale, animation, isBack: isBack, opacity: opacity),
      // Arm hierarchy: upper arm -> lower arm -> hand
      _buildArmHierarchy(scale, animation, isBack: isBack, opacity: opacity),
    ];
  }

  /// Build leg with hierarchical transforms (upper -> lower -> foot)
  Widget _buildLegHierarchy(double scale, CharacterAnimation? animation, {
    required bool isBack,
    required double opacity,
  }) {
    final upperLegLayout = characterLayout[CharacterPart.upperLeg]!;
    final lowerLegLayout = characterLayout[CharacterPart.lowerLeg]!;
    final footLayout = characterLayout[CharacterPart.foot]!;
    
    final upperLegRotation = animation?.getRotation(CharacterPart.upperLeg, isBack: isBack) ?? 0.0;
    final lowerLegRotation = animation?.getRotation(CharacterPart.lowerLeg, isBack: isBack) ?? 0.0;
    final footRotation = animation?.getRotation(CharacterPart.foot, isBack: isBack) ?? 0.0;

    // Build from innermost (foot) to outermost (upper leg)
    Widget foot = _buildPartImage(CharacterPart.foot, scale, opacity);
    foot = _applyRotation(foot, footRotation, footLayout);
    
    Widget lowerLeg = _buildPartImage(CharacterPart.lowerLeg, scale, opacity);
    lowerLeg = Stack(
      clipBehavior: Clip.none,
      children: [lowerLeg, foot],
    );
    lowerLeg = _applyRotation(lowerLeg, lowerLegRotation, lowerLegLayout);
    
    Widget upperLeg = _buildPartImage(CharacterPart.upperLeg, scale, opacity);
    upperLeg = Stack(
      clipBehavior: Clip.none,
      children: [upperLeg, lowerLeg],
    );
    upperLeg = _applyRotation(upperLeg, upperLegRotation, upperLegLayout);
    
    return Positioned(left: 0, top: 0, child: upperLeg);
  }

  /// Build arm with hierarchical transforms (upper -> lower -> hand)
  Widget _buildArmHierarchy(double scale, CharacterAnimation? animation, {
    required bool isBack,
    required double opacity,
  }) {
    final upperArmLayout = characterLayout[CharacterPart.upperArm]!;
    final lowerArmLayout = characterLayout[CharacterPart.lowerArm]!;
    final handLayout = characterLayout[CharacterPart.hand]!;
    
    final upperArmRotation = animation?.getRotation(CharacterPart.upperArm, isBack: isBack) ?? 0.0;
    final lowerArmRotation = animation?.getRotation(CharacterPart.lowerArm, isBack: isBack) ?? 0.0;
    final handRotation = animation?.getRotation(CharacterPart.hand, isBack: isBack) ?? 0.0;

    // Build from innermost (hand) to outermost (upper arm)
    Widget hand = _buildPartImage(CharacterPart.hand, scale, opacity);
    hand = _applyRotation(hand, handRotation, handLayout);
    
    Widget lowerArm = _buildPartImage(CharacterPart.lowerArm, scale, opacity);
    lowerArm = Stack(
      clipBehavior: Clip.none,
      children: [lowerArm, hand],
    );
    lowerArm = _applyRotation(lowerArm, lowerArmRotation, lowerArmLayout);
    
    Widget upperArm = _buildPartImage(CharacterPart.upperArm, scale, opacity);
    upperArm = Stack(
      clipBehavior: Clip.none,
      children: [upperArm, lowerArm],
    );
    upperArm = _applyRotation(upperArm, upperArmRotation, upperArmLayout);
    
    return Positioned(left: 0, top: 0, child: upperArm);
  }

  /// Build just the image for a part (no rotation)
  Widget _buildPartImage(CharacterPart part, double scale, double opacity) {
    Widget image = Image.asset(
      profile.assetFor(part),
      width: DESIGN_SIZE * scale,
      height: DESIGN_SIZE * scale,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: DESIGN_SIZE * scale,
        height: DESIGN_SIZE * scale,
      ),
    );
    
    // Darken back limbs instead of making them transparent
    if (opacity < 1.0) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.3),  // 30% darkening
          BlendMode.srcATop,
        ),
        child: image,
      );
    }
    
    return image;
  }

  /// Apply rotation around a part's pivot point
  Widget _applyRotation(Widget child, double rotation, PartLayout layout) {
    if (rotation == 0) return child;
    
    // Calculate pivot alignment from layout's absolute pivot
    final pivotX = layout.absolutePivot.dx / DESIGN_SIZE;
    final pivotY = layout.absolutePivot.dy / DESIGN_SIZE;
    
    // Convert to Alignment (-1 to 1 range)
    final alignment = Alignment(
      (pivotX - 0.5) * 2,
      (pivotY - 0.5) * 2,
    );
    
    return Transform.rotate(
      angle: rotation,
      alignment: alignment,
      child: child,
    );
  }

  Widget _buildPart(
    CharacterPart part, 
    double scale, 
    CharacterAnimation? animation, {
    required bool isBack,
    double opacity = 1.0,
  }) {
    final layout = characterLayout[part]!;
    final rotation = animation?.getRotation(part, isBack: isBack) ?? 0.0;
    
    Widget image = _buildPartImage(part, scale, opacity);
    image = _applyRotation(image, rotation, layout);
    
    return Positioned(
      left: 0,
      top: 0,
      child: image,
    );
  }
}

/// A self-animating character avatar that plays a looping animation.
class AnimatedCharacterAvatar extends StatefulWidget {
  final CharacterProfile profile;
  final double size;
  
  /// Duration of one complete animation cycle
  final Duration cycleDuration;
  
  /// Whether animation is currently playing
  final bool isAnimating;
  
  /// Type of animation to play (walk, run)
  final AnimationType animationType;

  const AnimatedCharacterAvatar({
    super.key,
    required this.profile,
    this.size = 256,
    this.cycleDuration = const Duration(milliseconds: 800),
    this.isAnimating = true,
    this.animationType = AnimationType.walk,
  });

  @override
  State<AnimatedCharacterAvatar> createState() => _AnimatedCharacterAvatarState();
}

class _AnimatedCharacterAvatarState extends State<AnimatedCharacterAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.cycleDuration,
      vsync: this,
    );
    
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedCharacterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
    
    if (widget.cycleDuration != oldWidget.cycleDuration) {
      _controller.duration = widget.cycleDuration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CharacterAvatar(
          profile: widget.profile,
          size: widget.size,
          animationProgress: widget.isAnimating ? _controller.value : null,
          animationType: widget.animationType,
        );
      },
    );
  }
}

