import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String authProvider;
  final DateTime createdAt;
  final DateTime lastLogin;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.authProvider,
    required this.createdAt,
    required this.lastLogin,
  });

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
    };
  }
}
