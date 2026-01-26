import 'package:chaser/models/player.dart';
import 'package:chaser/models/player_profile.dart'; // Added
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
  
  Stream<PlayerProfile?> watchPlayerProfile(String userId) {
      return _firestore.collection('player_profiles').doc(userId).snapshots().map((doc) {
          if (!doc.exists) return null;
          return PlayerProfile.fromFirestore(doc);
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

  Future<void> startGame(String sessionId, SessionModel session) async {
    // 1. Fetch current members
    final membersSnapshot = await _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .get();

    if (membersSnapshot.docs.length < 2) {
      throw Exception('Need at least 2 players to start.');
    }

    final members = membersSnapshot.docs.toList();
    
    // 2. Shuffle
    members.shuffle();

    // 3. Determine Chaser Count
    // Use settings, but ensure at least 1 and leave at least 1 runner
    int chaserCount = session.numChasers;
    if (chaserCount < 1) chaserCount = 1;
    if (chaserCount >= members.length) chaserCount = members.length - 1;

    // 4. Batch Update
    final batch = _firestore.batch();
    
    // Update Members
    for (int i = 0; i < members.length; i++) {
        final role = i < chaserCount ? 'chaser' : 'runner';
        final initialDistance = role == 'runner' ? session.headstartDistance : 0.0;
        
        batch.update(members[i].reference, {
            'role': role,
            'capture_state': 'free', // Reset capture state just in case
            'current_distance': initialDistance,
            'total_steps': 0,
            // 'joined_at' is preserved
        });
    }

    // Update Session
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(days: session.durationDays));
    
    batch.update(_firestore.collection('sessions').doc(sessionId), {
        'status': 'active',
        'actual_start_time': Timestamp.fromDate(startTime),
        'end_time': Timestamp.fromDate(endTime),
    });

    await batch.commit();
  }

  Future<void> triggerCaptureCheck(String sessionId) async {
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) return;
      final session = SessionModel.fromFirestore(sessionDoc);
      
      final membersSnap = await _firestore
          .collection('session_members')
          .where('session_id', isEqualTo: sessionId)
          .get();
          
      final players = membersSnap.docs.map((d) => PlayerModel.fromFirestore(d)).toList();
      
      final batch = _firestore.batch();
      _runGameLogic(session, players, batch, null, null); // No specific user update
      await batch.commit();
  }

  Future<void> updatePlayerDistance(String sessionId, String userId, double newDistance) async {
      // 1. Fetch Session & Players to check rules
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) return;
      final session = SessionModel.fromFirestore(sessionDoc);
      
      final membersSnap = await _firestore
          .collection('session_members')
          .where('session_id', isEqualTo: sessionId)
          .get();
          
      final players = membersSnap.docs.map((d) => PlayerModel.fromFirestore(d)).toList();
      
      // 2. Identify Current State & Update Distance
      final updatedPlayerIndex = players.indexWhere((p) => p.userId == userId);
      if (updatedPlayerIndex == -1) return;
      
      final updatedPlayer = players[updatedPlayerIndex];
      
      final batch = _firestore.batch();
      
      // Update the player's distance specifically
      final myDocRef = _firestore.collection('session_members').doc(updatedPlayer.sessionMemberId);
      batch.update(myDocRef, {'current_distance': newDistance});

      // 3. Run Logic
      _runGameLogic(session, players, batch, userId, newDistance);
      
      await batch.commit();
  }

  void _runGameLogic(SessionModel session, List<PlayerModel> players, WriteBatch batch, String? updatingUserId, double? newDistance) {
      // Calculate maxChaserDistance
      double maxChaserDistance = 0;
      for (var p in players) {
          if (p.role == 'chaser') {
              double dist = (updatingUserId != null && p.userId == updatingUserId) ? newDistance! : p.currentDistance;
              if (dist > maxChaserDistance) maxChaserDistance = dist;
          }
      }

      // Variables to track game end condition
      int activeRunnerCount = 0;
      bool captureHappened = false;
      final now = DateTime.now();

      for (var p in players) {
          if (p.role == 'runner' && p.captureState != 'captured') { 
              // Only check ACTIVE runners
              
              // Determine this runner's distance
              double runnerDist = (updatingUserId != null && p.userId == updatingUserId) ? newDistance! : p.currentDistance;
              
              // Check Capture Condition
              // "If the chaser has that runner difference behind or if they have greater distance"
              // Chaser >= Runner - ResistanceDistance
              // If captureResistanceDistance is 0, then Chaser >= Runner
              bool caught = maxChaserDistance >= (runnerDist - session.captureResistanceDistance);
              
              if (caught) {
                  if (session.instantCapture) {
                      // Instant Capture
                      batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                          'capture_state': 'captured',
                          'role': 'spectator',
                          'capture_deadline': FieldValue.delete(),
                      });
                      captureHappened = true;
                      // DO NOT increment activeRunnerCount
                  } else {
                      // Resistance Time
                      if (p.captureState == 'free') {
                           // Start being chased
                           final deadline = now.add(Duration(minutes: session.captureResistanceDuration));
                           batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                              'capture_state': 'being_chased',
                              'capture_deadline': Timestamp.fromDate(deadline),
                           });
                           activeRunnerCount++; // Still a runner (being chased is active)
                      } else if (p.captureState == 'being_chased') {
                          // Check if deadline passed
                          if (p.captureDeadline != null && now.isAfter(p.captureDeadline!.toDate())) {
                                   batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                                      'capture_state': 'captured',
                                      'role': 'spectator',
                                      'capture_deadline': FieldValue.delete(),
                                   });
                                   captureHappened = true;
                                   // DO NOT increment activeRunnerCount
                          } else {
                               // Still being chased (or fix missing deadline)
                              if (p.captureDeadline == null) {
                                   final deadline = now.add(Duration(minutes: session.captureResistanceDuration));
                                   batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                                      'capture_deadline': Timestamp.fromDate(deadline), 
                                   });
                              }
                              activeRunnerCount++; // Still a runner
                          }
                      } else {
                           activeRunnerCount++;
                      }
                  }
              } else {
                  // Not Caught (Escaped or Ahead)
                  if (p.captureState == 'being_chased') {
                      // Escaped!
                      batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                          'capture_state': 'free',
                          'capture_deadline': FieldValue.delete(),
                      });
                  }
                  activeRunnerCount++; // Still a runner
              }
          }
      }
      
      // If we are processing updates and it results in 0 active runners, end the game.
      if (activeRunnerCount == 0 && players.isNotEmpty && session.status == 'active') { // Only stop if active
           batch.update(_firestore.collection('sessions').doc(session.id), {
             'status': 'completed',
             'end_time': FieldValue.serverTimestamp(),
           });
      }
  }

  Future<void> stopGame(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'completed',
      'end_time': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetGame(String sessionId) async {
      // 1. Fetch current members
    final membersSnapshot = await _firestore
        .collection('session_members')
        .where('session_id', isEqualTo: sessionId)
        .get();

    final batch = _firestore.batch();
    
    // Reset players
    for (var doc in membersSnapshot.docs) {
        batch.update(doc.reference, {
            'role': 'spectator',
            'current_distance': 0,
            'total_steps': 0,
            'capture_state': 'free',
        });
    }
    
    // Reset session
    batch.update(_firestore.collection('sessions').doc(sessionId), {
        'status': 'pending',
        'actual_start_time': FieldValue.delete(),
        'end_time': FieldValue.delete(),
    });
    
    await batch.commit();
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
