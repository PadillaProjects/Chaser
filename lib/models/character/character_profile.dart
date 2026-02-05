class CharacterProfile {
  // Appearance (legacy fields for backward compatibility)
  final String head;
  final String body;
  final String feet;

  // Animations
  final String idleAnim;
  final String runAnim;
  final String celebrationAnim;

  // Extras
  final String aura;
  final String proximitySound;

  final int version;

  // New: Per-part skin selection
  final Map<CharacterPart, String> partSkins;

  const CharacterProfile({
    required this.head,
    required this.body,
    required this.feet,
    required this.idleAnim,
    required this.runAnim,
    required this.celebrationAnim,
    required this.aura,
    required this.proximitySound,
    this.version = 1,
    this.partSkins = const {},
  });

  /// The specific "Runner Blue" default profile
  factory CharacterProfile.runnerBlue() {
    return CharacterProfile(
      head: 'head_runner_blue',
      body: 'body_runner_blue',
      feet: 'feet_runner_blue',
      idleAnim: 'idle_bob_soft',
      runAnim: 'run_bounce_standard',
      celebrationAnim: 'celebrate_spin_small',
      aura: 'none',
      proximitySound: 'beep_soft',
      partSkins: {for (var part in CharacterPart.values) part: 'default'},
    );
  }

  /// Default fallback (currently synonymous with Runner Blue)
  factory CharacterProfile.defaultProfile() => CharacterProfile.runnerBlue();

  /// Create from Map (Firestore)
  factory CharacterProfile.fromMap(Map<String, dynamic> map) {
    final appearance = map['appearance'] as Map<String, dynamic>? ?? {};
    final animations = map['animations'] as Map<String, dynamic>? ?? {};
    final extras = map['extras'] as Map<String, dynamic>? ?? {};
    final partSkinsRaw = map['partSkins'] as Map<String, dynamic>? ?? {};

    // Convert partSkins from String keys to CharacterPart keys
    final partSkins = <CharacterPart, String>{};
    for (final part in CharacterPart.values) {
      partSkins[part] = partSkinsRaw[part.name] as String? ?? 'default';
    }

    return CharacterProfile(
      head: appearance['head'] ?? 'head_runner_blue',
      body: appearance['body'] ?? 'body_runner_blue',
      feet: appearance['feet'] ?? 'feet_runner_blue',
      idleAnim: animations['idle'] ?? 'idle_bob_soft',
      runAnim: animations['run'] ?? 'run_bounce_standard',
      celebrationAnim: animations['celebration'] ?? 'celebrate_spin_small',
      aura: extras['aura'] ?? 'none',
      proximitySound: extras['proximitySound'] ?? 'beep_soft',
      version: map['version'] ?? 1,
      partSkins: partSkins,
    );
  }

  /// Convert to Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'appearance': {
        'head': head,
        'body': body,
        'feet': feet,
      },
      'animations': {
        'idle': idleAnim,
        'run': runAnim,
        'celebration': celebrationAnim,
      },
      'extras': {
        'aura': aura,
        'proximitySound': proximitySound,
      },
      'version': version,
      'partSkins': {for (var e in partSkins.entries) e.key.name: e.value},
    };
  }

  CharacterProfile copyWith({
    String? head,
    String? body,
    String? feet,
    String? idleAnim,
    String? runAnim,
    String? celebrationAnim,
    String? aura,
    String? proximitySound,
    Map<CharacterPart, String>? partSkins,
  }) {
    return CharacterProfile(
      head: head ?? this.head,
      body: body ?? this.body,
      feet: feet ?? this.feet,
      idleAnim: idleAnim ?? this.idleAnim,
      runAnim: runAnim ?? this.runAnim,
      celebrationAnim: celebrationAnim ?? this.celebrationAnim,
      aura: aura ?? this.aura,
      proximitySound: proximitySound ?? this.proximitySound,
      version: this.version,
      partSkins: partSkins ?? this.partSkins,
    );
  }

  /// Helper to update a single part's skin
  CharacterProfile withPartSkin(CharacterPart part, String skinId) {
    final newPartSkins = Map<CharacterPart, String>.from(partSkins);
    newPartSkins[part] = skinId;
    return copyWith(partSkins: newPartSkins);
  }

  /// Get asset path for a specific part
  String assetFor(CharacterPart part) {
    final skinId = partSkins[part] ?? 'default';
    return 'assets/characters/$skinId/${part.fileName}';
  }
}

enum CharacterPart {
  head,
  torso,
  upperArm,
  lowerArm,
  hand,
  upperLeg,
  lowerLeg,
  foot,
}

extension CharacterPartExtension on CharacterPart {
  String get fileName {
    switch (this) {
      case CharacterPart.head:
        return 'head.png';
      case CharacterPart.torso:
        return 'torso.png';
      case CharacterPart.upperArm:
        return 'upper_arm.png';
      case CharacterPart.lowerArm:
        return 'lower_arm.png';
      case CharacterPart.hand:
        return 'hand.png';
      case CharacterPart.upperLeg:
        return 'upper_leg.png';
      case CharacterPart.lowerLeg:
        return 'lower_leg.png';
      case CharacterPart.foot:
        return 'foot.png';
    }
  }

  String get displayName {
    switch (this) {
      case CharacterPart.head:
        return 'Head';
      case CharacterPart.torso:
        return 'Torso';
      case CharacterPart.upperArm:
        return 'Upper Arm';
      case CharacterPart.lowerArm:
        return 'Lower Arm';
      case CharacterPart.hand:
        return 'Hand';
      case CharacterPart.upperLeg:
        return 'Upper Leg';
      case CharacterPart.lowerLeg:
        return 'Lower Leg';
      case CharacterPart.foot:
        return 'Foot';
    }
  }
}

/// All available skin IDs
const availableSkins = ['default', 'red', 'black'];
