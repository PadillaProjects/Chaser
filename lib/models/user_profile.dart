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

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.authProvider,
    required this.createdAt,
    required this.lastLogin,
    CharacterProfile? character,
  }) : character = character ?? CharacterProfile.defaultProfile();


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
    );
  }
}
