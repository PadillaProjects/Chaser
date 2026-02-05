import 'package:cloud_firestore/cloud_firestore.dart';
import 'character/character_profile.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String authProvider;
  final DateTime createdAt;
  final DateTime lastLogin;
  final CharacterProfile character;
  final int level;
  final int currentXp;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.authProvider,
    required this.createdAt,
    required this.lastLogin,
    CharacterProfile? character,
    this.level = 1,
    this.currentXp = 0,
  }) : character = character ?? CharacterProfile.defaultProfile();

  /// XP needed for next level (simple formula: 100 * current level)
  int get xpForNextLevel => level * 100;
  
  /// Progress towards next level (0.0 to 1.0)
  double get xpProgress => (currentXp / xpForNextLevel).clamp(0.0, 1.0);

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? 'Unknown',
      photoUrl: data['photo_url'],
      authProvider: data['auth_provider'] ?? 'unknown',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
      character: data['character'] != null
          ? CharacterProfile.fromMap(data['character'] as Map<String, dynamic>)
          : null,
      level: (data['level'] as int?) ?? 1,
      currentXp: (data['current_xp'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'auth_provider': authProvider,
      'created_at': Timestamp.fromDate(createdAt),
      'last_login': Timestamp.fromDate(lastLogin),
      'character': character.toMap(),
      'level': level,
      'current_xp': currentXp,
    };
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? authProvider,
    DateTime? createdAt,
    DateTime? lastLogin,
    CharacterProfile? character,
    int? level,
    int? currentXp,
  }) {
    return UserProfile(
      uid: this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      character: character ?? this.character,
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
    );
  }
}
