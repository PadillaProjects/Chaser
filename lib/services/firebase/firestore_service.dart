import 'package:chaser/models/player.dart';
import 'package:chaser/models/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Sessions ---

  Future<String> createSession(SessionModel session) async {
    final docRef = await _firestore.collection('sessions').add(session.toMap());
    
    // Auto-join owner
    await joinSession(docRef.id, session.ownerId, isOwner: true);
    
    return docRef.id;
  }

  Stream<List<SessionModel>> watchPublicSessions() {
    return _firestore
        .collection('sessions')
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'pending')
        // .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromFirestore(doc))
            .toList());
  }

  Stream<SessionModel> watchSession(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => SessionModel.fromFirestore(doc));
  }

  // --- Players ---

  Future<void> joinSession(String sessionId, String userId, {bool isOwner = false}) async {
    // Check if already joined
    final existing = await _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .where('user_id', isEqualTo: userId)
        .get();

    if (existing.docs.isNotEmpty) return;

    final player = PlayerModel(
      sessionMemberId: '', // Auto-generated
      sessionId: sessionId,
      userId: userId,
      role: 'spectator', // Default until game starts
      isOwner: isOwner,
      joinedAt: Timestamp.now(),
    );

    await _firestore.collection('session_members').add(player.toMap());
    
    // Update member count (should be cloud function ideally, but client for now)
    await _firestore.collection('sessions').doc(sessionId).update({
      'member_count': FieldValue.increment(1),
    });
  }

  Stream<List<PlayerModel>> watchSessionPlayers(String sessionId) {
    return _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlayerModel.fromFirestore(doc))
            .toList());
  }
}
