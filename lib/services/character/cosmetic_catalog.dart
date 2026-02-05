import '../../models/character/cosmetic_item.dart';

class CosmeticCatalog {
  // Singleton pattern
  static final CosmeticCatalog _instance = CosmeticCatalog._internal();
  factory CosmeticCatalog() => _instance;
  CosmeticCatalog._internal();

  /// The complete registry of all cosmetic items in the game.
  static final List<CosmeticItem> _items = [
    // --- Appearance: Heads ---
    const CosmeticItem(
      id: "head_runner_blue",
      name: "Runner Blue Head",
      description: "Standard issue runner helmet.",
      slot: CosmeticSlot.head,
      assetPath: "assets/Chaser Starter Assets/Runner_Blue/head.png",
    ),
    const CosmeticItem(
      id: "head_pulse_red",
      name: "Pulse Red Head",
      description: "High visibility combat helmet.",
      slot: CosmeticSlot.head,
      assetPath: "assets/Chaser Starter Assets/Pulse_Red/head.png",
    ),
    const CosmeticItem(
      id: "head_drift_green",
      name: "Drift Green Head",
      description: "Aerodynamic green helmet.",
      slot: CosmeticSlot.head,
      assetPath: "assets/Chaser Starter Assets/Drift_Green/head.png",
    ),
    const CosmeticItem(
      id: "head_neon_yellow",
      name: "Neon Yellow Head",
      description: "Bright yellow helmet.",
      slot: CosmeticSlot.head,
      assetPath: "assets/Chaser Starter Assets/Neon_Yellow/head.png",
    ),

    const CosmeticItem(
      id: "head_character1",
      name: "Bonus Head 1",
      description: "A unique collector's head.",
      slot: CosmeticSlot.head,
      assetPath: "assets/Chaser Starter Assets/head/Character1.png",
    ),

    // --- Appearance: Bodies ---
    const CosmeticItem(
      id: "body_runner_blue",
      name: "Runner Blue Body",
      description: "Standard issue runner suit.",
      slot: CosmeticSlot.body,
      assetPath: "assets/Chaser Starter Assets/Runner_Blue/body.png",
    ),
    const CosmeticItem(
      id: "body_pulse_red",
      name: "Pulse Red Body",
      description: "Aggressive red suit.",
      slot: CosmeticSlot.body,
      assetPath: "assets/Chaser Starter Assets/Pulse_Red/body.png",
    ),
    const CosmeticItem(
      id: "body_drift_green",
      name: "Drift Green Body",
      description: "Lightweight green suit.",
      slot: CosmeticSlot.body,
      assetPath: "assets/Chaser Starter Assets/Drift_Green/body.png",
    ),
    const CosmeticItem(
      id: "body_neon_yellow",
      name: "Neon Yellow Body",
      description: "High-contrast yellow suit.",
      slot: CosmeticSlot.body,
      assetPath: "assets/Chaser Starter Assets/Neon_Yellow/body.png",
    ),

    // --- Appearance: Feet ---
    const CosmeticItem(
      id: "feet_runner_blue",
      name: "Runner Blue Boots",
      description: "Standard grip boots.",
      slot: CosmeticSlot.feet,
      assetPath: "assets/Chaser Starter Assets/Runner_Blue/feet.png",
    ),
    const CosmeticItem(
      id: "feet_pulse_red",
      name: "Pulse Red Boots",
      description: "Heavy duty red boots.",
      slot: CosmeticSlot.feet,
      assetPath: "assets/Chaser Starter Assets/Pulse_Red/feet.png",
    ),
    const CosmeticItem(
      id: "feet_drift_green",
      name: "Drift Green Boots",
      description: "Speed grip green boots.",
      slot: CosmeticSlot.feet,
      assetPath: "assets/Chaser Starter Assets/Drift_Green/feet.png",
    ),
    const CosmeticItem(
      id: "feet_neon_yellow",
      name: "Neon Yellow Boots",
      description: "Flashy yellow boots.",
      slot: CosmeticSlot.feet,
      assetPath: "assets/Chaser Starter Assets/Neon_Yellow/feet.png",
    ),

    // --- Animations: Idle ---
    // (Keeping placeholder animations for now as they are code-driven or placeholders)
    const CosmeticItem(
      id: "idle_bob_soft",
      name: "Soft Bob",
      description: "Gentle floating motion.",
      animationType: AnimationType.idle,
      assetPath: "", 
    ),
    const CosmeticItem(
      id: "idle_pulse",
      name: "Pulse Idle",
      description: "Rhythmic size changes.",
      animationType: AnimationType.idle,
      assetPath: "",
    ),

    // --- Animations: Run ---
    const CosmeticItem(
      id: "run_bounce_standard",
      name: "Standard Bounce",
      description: "Classic movement.",
      animationType: AnimationType.run,
      assetPath: "",
    ),
    
    // --- Animations: Celebration ---
    const CosmeticItem(
      id: "celebrate_spin_small",
      name: "Small Spin",
      description: "A modest victory twirl.",
      animationType: AnimationType.celebration,
      assetPath: "",
    ),

    // --- Extras: Aura ---
    const CosmeticItem(
      id: "none",
      name: "None",
      description: "No effect.",
      slot: CosmeticSlot.extra,
      assetPath: "",
    ),
    const CosmeticItem(
      id: "aura_pulse_red",
      name: "Red Pulse Aura",
      description: "Emits red waves.",
      slot: CosmeticSlot.extra,
      assetPath: "",
    ),

    // --- Extras: Sounds ---
    const CosmeticItem(
      id: "beep_soft",
      name: "Soft Beep",
      description: "Standard proximity warning.",
      slot: CosmeticSlot.extra,
      assetPath: "assets/audio/beep_soft.mp3",
    ),
  ];

  // Optimize lookup with a Map
  static final Map<String, CosmeticItem> _itemMap = {
    for (var item in _items) item.id: item
  };

  /// Get a cosmetic item by its unique ID.
  /// Returns null if not found.
  CosmeticItem? getItem(String id) {
    return _itemMap[id];
  }

  /// Get all items for a specific appearance slot.
  List<CosmeticItem> getItemsForSlot(CosmeticSlot slot) {
    return _items.where((item) => item.slot == slot).toList();
  }

  /// Get all items for a specific animation type.
  List<CosmeticItem> getItemsForAnimation(AnimationType type) {
    return _items.where((item) => item.animationType == type).toList();
  }
  
  /// Validates a cosmetic ID. Returns true if it exists in the catalog.
  bool isValidId(String id) {
    return _itemMap.containsKey(id);
  }
}
