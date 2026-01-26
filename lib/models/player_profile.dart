import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  final String userId;
  final int level;
  final int totalXP;
  final int xpToNextLevel;
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

  PlayerProfile({
    required this.userId,
    required this.level,
    required this.totalXP,
    required this.totalCoins,
    required this.totalDistance,
    required this.totalGamesPlayed,
    this.xpToNextLevel = 1000,
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
      xpToNextLevel: data['xp_to_next_level'] ?? 1000,
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
      'xp_to_next_level': xpToNextLevel,
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
