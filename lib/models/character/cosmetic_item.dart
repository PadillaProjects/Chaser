enum CosmeticSlot {
  head,
  body,
  feet,
  extra, // Added for Auras, Sounds, etc.
}

enum AnimationType {
  idle,
  run,
  celebration,
  // Add others as needed: capture, release, etc.
}

enum CosmeticRarity {
  common,
  rare,
  epic,
  legendary,
}

class CosmeticItem {
  final String id;
  final String name;
  final String description;
  final CosmeticSlot? slot; // Null if it's an animation or extra
  final AnimationType? animationType; // Null if it's an appearance item
  final String assetPath;
  final CosmeticRarity rarity;
  final int unlockLevel;

  const CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    this.slot,
    this.animationType,
    required this.assetPath,
    this.rarity = CosmeticRarity.common,
    this.unlockLevel = 1,
  }) : assert(slot != null || animationType != null, 'Item must have a slot or animation type');
}
