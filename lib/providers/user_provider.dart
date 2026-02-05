import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/session.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return Stream.value(null);
  }

  return FirestoreService().watchUserProfile(user.uid);
});

final userSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream<List<SessionModel>>.empty();
  // Ensure this method exists in FirestoreService, otherwise this will fail
  // If it doesn't, we need to add it or use watchSessionPlayers query
  return FirestoreService().watchUserSessions(user.uid); 
});
