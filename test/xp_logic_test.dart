import 'package:test/test.dart';
import 'package:chaser/models/player_profile.dart'; // Adjust path if needed when testing in isolate
import 'dart:math';

// Copied logic for testing without full flutter context if needed,
// but let's try to import directly relative to project root.
// If direct import fails due to package structure, we will copy the class here.

void main() {
  group('PlayerProfile XP Logic', () {
    test('Level 1 baseline', () {
      // Level 1 starts at 0 total XP.
      // Next level needs 100 * 1.1^0 = 100 XP.
      expect(PlayerProfile.cumulativeXpForLevel(1), 0);
      
      final p = PlayerProfile(
          userId: 'test', level: 1, totalXP: 50,
          totalCoins: 0, totalDistance: 0, totalGamesPlayed: 0, createdAt: DateTime.now()
      );
      
      expect(p.xpRequiredForNextLevel, 100);
      expect(p.xpSinceCurrentLevelStart, 50); // 50 - 0
      expect(p.currentLevelProgress, 0.5);
    });

    test('Level 2 baseline', () {
      // Level 1 -> 2 needed 100 XP.
      // Cumulative for Level 2 start = 100.
      expect(PlayerProfile.cumulativeXpForLevel(2), 100);
      
      // Level 2 -> 3 needs 100 * 1.1^1 = 110 XP.
      final p = PlayerProfile(
          userId: 'test', level: 2, totalXP: 155,
          totalCoins: 0, totalDistance: 0, totalGamesPlayed: 0, createdAt: DateTime.now()
      );
      
      expect(p.xpRequiredForNextLevel, 110);
      
      // XP in level 2: Total(155) - Level2Start(100) = 55.
      expect(p.xpSinceCurrentLevelStart, 55);
      
      // Progress: 55 / 110 = 0.5
      expect(p.currentLevelProgress, 0.5);
    });

    test('Level 3 baseline', () {
      // Level 1->2 (100) + Level 2->3 (110) = 210 cumulative.
      expect(PlayerProfile.cumulativeXpForLevel(3), 210);
      
      // Level 3->4 needs 100 * 1.1^2 = 121 XP.
      final p = PlayerProfile(
          userId: 'test', level: 3, totalXP: 210, // Just reached level 3
           totalCoins: 0, totalDistance: 0, totalGamesPlayed: 0, createdAt: DateTime.now()
      );
      
      expect(p.xpRequiredForNextLevel, 121);
      expect(p.xpSinceCurrentLevelStart, 0);
      expect(p.currentLevelProgress, 0.0);
    });
  });
}
