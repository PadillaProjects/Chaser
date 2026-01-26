import 'package:chaser/models/player.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/models/user_profile.dart';
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

  Future<void> updateSession(String sessionId, Map<String, dynamic> data) async {
    await _firestore.collection('sessions').doc(sessionId).update(data);
  }

  // --- Users ---

  Stream<UserProfile> watchUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
            if (!doc.exists) {
                // Return a dummy profile or handle error? 
                // For now returning a partial profile with 'Unknown'
                return UserProfile(
                    uid: userId, 
                    email: '', 
                    displayName: 'Unknown', 
                    authProvider: '', 
                    createdAt: DateTime.now(), 
                    lastLogin: DateTime.now()
                );
            }
            return UserProfile.fromFirestore(doc);
        });
  }

  // --- Players ---

  Future<void> joinSession(String sessionId, String userId, {bool isOwner = false}) async {
    final memberRef = _firestore.collection('session_members').doc(); 
    // ^ note: ideally we'd use a deterministic ID like "${sessionId}_$userId" to strictly prevent duplicates
    // but a transaction query check is also fine if standardized.
    // Let's use a deterministic ID for absolute safety.
    final deterministicId = "${sessionId}_$userId";
    final docRef = _firestore.collection('session_members').doc(deterministicId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      if (snapshot.exists) {
        // Already joined
        return;
      }

      final player = PlayerModel(
        sessionMemberId: deterministicId,
        sessionId: sessionId,
        userId: userId,
        role: 'spectator',
        isOwner: isOwner,
        joinedAt: Timestamp.now(),
      );

      transaction.set(docRef, player.toMap());
      
      // Increment count
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      transaction.update(sessionRef, {
        'member_count': FieldValue.increment(1),
      });
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
  // --- Session Management ---

  Future<void> deleteSession(String sessionId) async {
    // 1. Delete all members
    final membersSnapshot = await _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .get();
    
    for (var doc in membersSnapshot.docs) {
      await doc.reference.delete();
    }

    // 2. Delete session doc
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  Future<void> leaveSession(String sessionId, String userId) async {
    // 1. Get actual member count
    final membersSnapshot = await _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .get();
    
    final int realMemberCount = membersSnapshot.docs.length;

    // 2. Check if user is actually in the session
    final leaverDoc = membersSnapshot.docs.firstWhere(
      (doc) => doc['user_id'] == userId,
      orElse: () => throw Exception('User not in session') // Handle gracefully in real app
    );
    
    // Safety check if not found (though firstWhere throws, we can wrap or use try/catch in caller)
    // For now assuming found if we reached here.

    if (realMemberCount <= 1) {
      // Last person leaving -> Delete session completely
      await deleteSession(sessionId);
    } else {
      // Determine if leaver is the owner
      final bool isOwner = leaverDoc['is_owner'] ?? false;

      if (isOwner) {
        // HOST MIGRATION
        // Find candidates (everyone except leaver)
        final candidates = membersSnapshot.docs.where((doc) => doc.id != leaverDoc.id).toList();
        
        if (candidates.isNotEmpty) {
          // Sort by joined_at ASC (Oldest first)
          candidates.sort((a, b) {
            Timestamp tA = a['joined_at'] ?? Timestamp.now();
            Timestamp tB = b['joined_at'] ?? Timestamp.now();
            return tA.compareTo(tB);
          });
          
          final newHostDoc = candidates.first;
          
          // Transaction to safely migrate
          await _firestore.runTransaction((transaction) async {
             // 1. Promote new host
             transaction.update(newHostDoc.reference, {'is_owner': true});
             
             // 2. Update session owner_id
             transaction.update(_firestore.collection('sessions').doc(sessionId), {
               'owner_id': newHostDoc['user_id'],
               'member_count': FieldValue.increment(-1), // Decrement for the leaver
             });
             
             // 3. Delete leaver
             transaction.delete(leaverDoc.reference);
          });
        } else {
          // Should have been covered by realMemberCount <= 1, but safety net
          await deleteSession(sessionId);
        }
      } else {
        // Normal leave (not host)
        await leaverDoc.reference.delete();
        
        await _firestore.collection('sessions').doc(sessionId).update({
          'member_count': FieldValue.increment(-1),
        });
      }
    }
  }
  Future<void> joinSessionByCode(String code, String userId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('join_code', isEqualTo: code)
        .where('status', isEqualTo: 'pending') // Only pending games? Or active too if mid-game join allowed?
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Session not found with code: $code');
    }

    // Join the first one found (codes should be unique enough)
    final sessionDoc = snapshot.docs.first;
    await joinSession(sessionDoc.id, userId);
  }

  Stream<List<SessionModel>> watchUserSessions(String userId) {
    // This requires a tricky query or a composite index/array contains.
    // Simpler for now: Query 'session_members' for my userId, then fetch sessions.
    // Or: watch 'session_members' and use a specialized provider/stream transformer.
    // 
    // BUT Firestore's 'array-contains' is best if we store userIds array on the session.
    // We aren't doing that (we have subcollection/separate collection).
    // 
    // Option A: Two-step stream (Member list -> Session list).
    // Option B: Store `member_ids` array on Session document (Denormalization).
    //
    // Let's implement Option B (add member_ids to Session) for easier querying? 
    // OR stick to what we have:
    // Query 'session_members' stream, then combine.
    // 
    // For this prototype, let's keep it simple: 
    // We'll watch `session_members` where userId == me.
    
    return _firestore
        .collection('session_members')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final sessionIds = snapshot.docs.map((d) => d['session_id'] as String).toList();
          if (sessionIds.isEmpty) return [];

          // Firestore 'in' query supports up to 10 items. 
          // If >10, we'd need to batch. For prototype, 10 is fine.
          
          List<SessionModel> sessions = [];
          
          // Chunk into 10s
          for (var i = 0; i < sessionIds.length; i += 10) {
            final end = (i + 10 < sessionIds.length) ? i + 10 : sessionIds.length;
            final chunk = sessionIds.sublist(i, end);
            
            final sessionSnap = await _firestore
                .collection('sessions')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
                
            sessions.addAll(sessionSnap.docs.map((d) => SessionModel.fromFirestore(d)));
          }
          
          return sessions;
        });
  }
}
