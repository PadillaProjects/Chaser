import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Handle web Google Sign-In if needed, but keeping simple for now
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          return null; // User canceled
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        await _handleUserCreation(userCredential, 'google');
        return userCredential;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update last login
      await _updateLastLogin(userCredential.user!);
      return userCredential;
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      rethrow;
    }
  }

  /// Register with Email and Password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(displayName);

      await _handleUserCreation(userCredential, 'email');
      return userCredential;
    } catch (e) {
      debugPrint('Registration Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Handle user creation in Firestore
  Future<void> _handleUserCreation(
      UserCredential userCredential, String provider) async {
    final user = userCredential.user!;
    
    // Check if user doc exists
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      await _createUserProfile(user, provider);
    } else {
      await _updateLastLogin(user);
    }
  }

  Future<void> _createUserProfile(User user, String provider) async {
    final batch = _firestore.batch();
    
    final userRef = _firestore.collection('users').doc(user.uid);
    batch.set(userRef, {
      'email': user.email,
      'display_name': user.displayName ?? 'Unknown',
      'photo_url': user.photoURL,
      'auth_provider': provider,
      'created_at': FieldValue.serverTimestamp(),
      'last_login': FieldValue.serverTimestamp(),
    });

    // Create initial player profile
    final playerRef = _firestore.collection('player_profiles').doc(user.uid);
    batch.set(playerRef, {
      'user_id': user.uid,
      'level': 1,
      'total_xp': 0,
      'total_coins': 0,
      'total_distance': 0,
      'total_games_played': 0,
      'unit_preference': 'metric',
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _updateLastLogin(User user) async {
    await _firestore.collection('users').doc(user.uid).update({
      'last_login': FieldValue.serverTimestamp(),
    });
  }
}
