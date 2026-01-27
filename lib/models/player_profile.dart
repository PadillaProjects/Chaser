import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PlayerProfile {
  final String userId;
  final int level;
  final int totalXP;
  // final int xpToNextLevel; // Removed stored field
  final int totalCoins;
  final int totalCoinsEarned;
  final int totalCoinsSpent;
  final double totalDistance;
  final int totalGamesPlayed;
  final int totalWins;
  final int totalLosses;
  final int totalCaptures;
  final int totalEscapes;
  final int totalTimesCaptured;
  final DateTime createdAt;
  final DateTime? lastGameAt;

  // Dynamic Getters for Level Progress
  
  // Total XP required to REACH a specific level (sum of previous levels)
  static int cumulativeXpForLevel(int targetLevel) {
    if (targetLevel <= 1) return 0;
    int total = 0;
    for (int i = 1; i < targetLevel; i++) {
        total += (100 * pow(1.1, i - 1)).round();
    }
    return total;
  }

  // XP needed to COMPLETE current level
  int get xpRequiredForNextLevel => (100 * pow(1.1, level - 1)).round();
  
  // XP accumulation strictly WITHIN the current level
  int get xpSinceCurrentLevelStart {
      final startXP = cumulativeXpForLevel(level);
      final diff = totalXP - startXP;
      return diff < 0 ? 0 : diff; // Safety
  }
  
  // Progress 0.0 to 1.0
  double get currentLevelProgress {
      final required = xpRequiredForNextLevel;
      if (required == 0) return 1.0;
      return xpSinceCurrentLevelStart / required;
  }
  
  // Deprecated/Legacy getter (kept for compatibility but logic moved)
  int get xpToNextLevel => xpRequiredForNextLevel;

  PlayerProfile({
    required this.userId,
    required this.level,
    required this.totalXP,
    // required this.xpToNextLevel, // Removed
    required this.totalCoins,
    required this.totalDistance,
    required this.totalGamesPlayed,
    // this.xpToNextLevel = 100, // Removed default
    this.totalCoinsEarned = 0,
    this.totalCoinsSpent = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalCaptures = 0,
    this.totalEscapes = 0,
    this.totalTimesCaptured = 0,
    required this.createdAt,
    this.lastGameAt,
  });

  factory PlayerProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerProfile(
      userId: doc.id,
      level: data['level'] ?? 1,
      totalXP: data['total_xp'] ?? 0,
      // xpToNextLevel: data['xp_to_next_level'] ?? 100, // Ignored
      totalCoins: data['total_coins'] ?? 0,
      totalCoinsEarned: data['total_coins_earned'] ?? 0,
      totalCoinsSpent: data['total_coins_spent'] ?? 0,
      totalDistance: (data['total_distance'] ?? 0).toDouble(),
      totalGamesPlayed: data['total_games_played'] ?? 0,
      totalWins: data['total_wins'] ?? 0,
      totalLosses: data['total_losses'] ?? 0,
      totalCaptures: data['total_captures'] ?? 0,
      totalEscapes: data['total_escapes'] ?? 0,
      totalTimesCaptured: data['total_times_captured'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastGameAt: (data['last_game_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'level': level,
      'total_xp': totalXP,
      'xp_to_next_level': xpToNextLevel, // We can still write it for other consumers/debugging, but we don't read it back.
      'total_coins': totalCoins,
      'total_coins_earned': totalCoinsEarned,
      'total_coins_spent': totalCoinsSpent,
      'total_distance': totalDistance,
      'total_games_played': totalGamesPlayed,
      'total_wins': totalWins,
      'total_losses': totalLosses,
      'total_captures': totalCaptures,
      'total_escapes': totalEscapes,
      'total_times_captured': totalTimesCaptured,
      'created_at': Timestamp.fromDate(createdAt),
      'last_game_at': lastGameAt != null ? Timestamp.fromDate(lastGameAt!) : null,
    };
  }
}
