import 'dart:math';
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
    // note: ideally we'd use a deterministic ID like "${sessionId}_$userId" to strictly prevent duplicates
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

    // Assign Targets (Round Robin) if Target Mode
    if (session.gameMode == 'target') {
        final actualRunners = <QueryDocumentSnapshot>[];
        final actualChasers = <QueryDocumentSnapshot>[];
        
        for (int i = 0; i < members.length; i++) {
           // Re-derive role based on index logic used above
           final isChaser = i < chaserCount;
           if (isChaser) actualChasers.add(members[i]);
           else actualRunners.add(members[i]);
        }

        if (actualRunners.isNotEmpty && actualChasers.isNotEmpty) {
           for (int i = 0; i < actualChasers.length; i++) {
               final targetSnapshot = actualRunners[i % actualRunners.length];
               // Find target userId
               final targetUserId = targetSnapshot['user_id'];
               
               batch.update(actualChasers[i].reference, {
                   'target_user_id': targetUserId,
               });
           }
        }
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
      final result = await _runGameLogic(session, players, batch, null, null);
      
      if (result.endReason != null) {
          await _calculateAndSaveResults(session, result.finalPlayers, batch, result.endReason!);
      }
      
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
      final result = await _runGameLogic(session, players, batch, userId, newDistance);
      
      if (result.endReason != null) {
          await _calculateAndSaveResults(session, result.finalPlayers, batch, result.endReason!);
      }
      
      await batch.commit();

  }

  Future<GameLogicResult> _runGameLogic(SessionModel session, List<PlayerModel> players, WriteBatch batch, String? updatingUserId, double? newDistance) async {

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
      final now = DateTime.now();

      // Working copy of players to track updates
      // This is crucial because batch updates don't reflect in 'players' list immediately
      List<PlayerModel> workingPlayers = List.from(players);

      for (int i = 0; i < workingPlayers.length; i++) {
          final p = workingPlayers[i];
          if (p.role == 'runner' && p.captureState != 'captured') { 
              // Only check ACTIVE runners
              
              // Determine this runner's distance
              double runnerDist = (updatingUserId != null && p.userId == updatingUserId) ? newDistance! : p.currentDistance;
              
              // Check Capture Condition
              // "If the chaser has that runner difference behind or if they have greater distance"
              // Chaser >= Runner - ResistanceDistance
              // If captureResistanceDistance is 0, then Chaser >= Runner
              
              bool caught = false;
              String? catcherId;

              if (session.gameMode == 'target') {
                  // TARGET MODE: Only the assigned chaser can catch this runner
                  // Find Chaser assigned to this runner
                  final assignedChaser = players.where((c) => c.role == 'chaser' && c.targetUserId == p.userId).firstOrNull;
                  
                  if (assignedChaser != null) {
                       double chaserDist = (updatingUserId != null && assignedChaser.userId == updatingUserId) ? newDistance! : assignedChaser.currentDistance;
                       if (chaserDist >= (runnerDist - session.captureResistanceDistance)) {
                           caught = true;
                           catcherId = assignedChaser.userId;
                       }
                  }
              } else {
                  // ORIGINAL MODE: Any chaser can catch (based on max distance usually)
                  caught = maxChaserDistance >= (runnerDist - session.captureResistanceDistance);
              }
              
              if (caught) {
                  if (session.instantCapture) {
                      // Instant Capture
                      // Find WHO caught them (Max Distance Chaser - simplified attribution)
                      // Ideally we'd know which specific chaser triggered it, but here we just take the leader or the one updating if they are a chaser.
                      String capturerId = 'unknown';
                      
                      // Best guess attribution:
                      // If the *updater* is a chaser and active, they probably did it.
                      // Else, attribute to the Chaser with max distance (leading chaser).
                      
                       if (catcherId != null) {
                          capturerId = catcherId;
                       } else {
                           // Existing logic for Classic Mode fallback
                           final updater = players.firstWhere((p) => p.userId == updatingUserId, orElse: () => players.first);
                           if (updater.role == 'chaser') {
                              capturerId = updater.userId;
                           } else {
                              // Find chaser with max distance
                              double maxD = -1;
                              for(var c in players) {
                                 if (c.role == 'chaser' && c.currentDistance > maxD) {
                                     maxD = c.currentDistance;
                                     capturerId = c.userId;
                                 }
                              }
                           }
                       }

                      final newCapturedPlayer = p.copyWith(
                          captureState: 'captured',
                          role: 'spectator',
                          // captureDeadline: FieldValue.delete(), // Cannot represent delete in model easily, set null
                          capturedBy: capturerId,
                          captureTime: Timestamp.now(),
                      );
                      
                      workingPlayers[i] = newCapturedPlayer;

                      batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                          'capture_state': 'captured',
                          'role': 'spectator',
                          'capture_deadline': FieldValue.delete(),
                          'captured_by': capturerId,
                          'capture_time': FieldValue.serverTimestamp(),
                      });
                      // DO NOT increment activeRunnerCount
                  } else {
                      // Resistance Time
                      if (p.captureState == 'free') {
                           // Start being chased
                           final deadline = now.add(Duration(minutes: session.captureResistanceDuration));
                           
                           final chasedPlayer = p.copyWith(
                               captureState: 'being_chased',
                               captureDeadline: Timestamp.fromDate(deadline),
                           );
                           workingPlayers[i] = chasedPlayer;

                           batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                              'capture_state': 'being_chased',
                              'capture_deadline': Timestamp.fromDate(deadline),
                           });
                           activeRunnerCount++; // Still a runner (being chased is active)
                      } else if (p.captureState == 'being_chased') {
                          // Check if deadline passed
                          if (p.captureDeadline != null && now.isAfter(p.captureDeadline!.toDate())) {
                                   // DELAYED CAPTURE (Timeout)
                                   // Attribute to the chaser who *initiated* the chase? 
                                   // Or the one currently leading?
                                   // Simplified: Attribute to leading chaser at time of capture.
                                    String capturerId = 'unknown';
                                    
                                     if (session.gameMode == 'target') {
                                         final assigned = players.where((c) => c.role == 'chaser' && c.targetUserId == p.userId).firstOrNull;
                                         if (assigned != null) capturerId = assigned.userId;
                                     } else {
                                         double maxD = -1;
                                         for(var c in players) {
                                            if (c.role == 'chaser' && c.currentDistance > maxD) {
                                                maxD = c.currentDistance;
                                                capturerId = c.userId;
                                            }
                                         }
                                     }

                                     final newCapturedPlayer = p.copyWith(
                                          captureState: 'captured',
                                          role: 'spectator',
                                          capturedBy: capturerId,
                                          captureTime: Timestamp.now(),
                                     );
                                     workingPlayers[i] = newCapturedPlayer;

                                    batch.update(_firestore.collection('session_members').doc(p.sessionMemberId), {
                                      'capture_state': 'captured',
                                      'role': 'spectator',
                                      'capture_deadline': FieldValue.delete(),
                                      'captured_by': capturerId, 
                                      'capture_time': FieldValue.serverTimestamp(),
                                   });
                                   // DO NOT increment activeRunnerCount
                          } else {
                               // Still being chased (or fix missing deadline)
                              if (p.captureDeadline == null) {
                                   final deadline = now.add(Duration(minutes: session.captureResistanceDuration));
                                   
                                   final updatedDeadlinePlayer = p.copyWith(
                                      captureDeadline: Timestamp.fromDate(deadline),
                                   );
                                   workingPlayers[i] = updatedDeadlinePlayer;
                                   
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
                      final escapedPlayer = p.copyWith(
                          captureState: 'free',
                      );
                      workingPlayers[i] = escapedPlayer;

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
      if (activeRunnerCount == 0 && workingPlayers.isNotEmpty && session.status == 'active') { // Only stop if active
           // Chasers Win (or everyone captured)
           return GameLogicResult('chasers_win', workingPlayers);
      }
      
      // Check Time limit (Runners Win) (Only if scheduled/actual start time exists)
      final start = session.actualStartTime?.toDate();
      if (start != null && session.status == 'active') {
          final end = start.add(Duration(days: session.durationDays));
          if (now.isAfter(end) && activeRunnerCount > 0) {
              return GameLogicResult('runners_win', workingPlayers);
          }
      }

      return GameLogicResult(null, workingPlayers);
  }

  Future<void> _calculateAndSaveResults(SessionModel session, List<PlayerModel> players, WriteBatch batch, String endReason) async {
      // 1. Determine Winner Role
      String winnerRole = 'none';
      if (endReason == 'chasers_win') winnerRole = 'chaser';
      else if (endReason == 'runners_win') winnerRole = 'runner';
      
      final playerResults = <String, dynamic>{};
      
      // Calculate Session Duration in Hours (or planned duration if session is still 'active' but forced stop)
      // Actually, use actual duration.
      final startTime = session.actualStartTime?.toDate() ?? DateTime.now(); // Fallback if not started
      final endTime = DateTime.now(); // End time is NOW
      final durationHours = endTime.difference(startTime).inHours;
      final safeDurationHours = durationHours < 1 ? 1 : durationHours; // Minimum 1 hour for modifiers
      
      // Long Session Efficiency Factor
      // Caps at 1.35 for >= 72 hours.
      // Formula: 1.0 + (min(hours, 72) / 72) * 0.35
      final cappedHours = safeDurationHours > 72 ? 72 : safeDurationHours;
      final longSessionFactor = 1.0 + (cappedHours / 72.0) * 0.35;
      
      // Pre-process Chaser Capture Counts for Streaks
      final chaserCaptureCounts = <String, int>{};
      for(var p in players) {
          if (p.captureState == 'captured' && p.capturedBy != null) {
              chaserCaptureCounts[p.capturedBy!] = (chaserCaptureCounts[p.capturedBy!] ?? 0) + 1;
          }
      }
      
      for (var p in players) {
          final pDoc = await _firestore.collection('player_profiles').doc(p.userId).get();
          PlayerProfile profile;
          if (pDoc.exists) {
              profile = PlayerProfile.fromFirestore(pDoc);
          } else {
              profile = PlayerProfile(
                  userId: p.userId,
                  level: 1,
                  totalXP: 0,
                  totalCoins: 0,
                  totalDistance: 0,
                  totalGamesPlayed: 0,
                  createdAt: DateTime.now(),
              );
          }
          
          // --- SCORING LOGIC ---
          double totalPoints = 0.0;
          Map<String, dynamic> pointsBreakdown = {};
          
          if (p.role == 'runner') {
              // RUNNER SCORING
              
              // 1. Survival Points: 2 pts per hour survived
              // If captured, use time until capture. If won/survived, use session duration.
              int hoursSurvived = safeDurationHours;
              if (p.captureState == 'captured' && p.captureTime != null && session.actualStartTime != null) {
                   final livedDuration = p.captureTime!.toDate().difference(session.actualStartTime!.toDate()).inHours;
                   hoursSurvived = livedDuration < 0 ? 0 : livedDuration;
              }
              double survivalPoints = hoursSurvived * 2.0;
              
              // 2. Distance Points: 1 pt per 250m
              // Daily Cap: 100 pts/day (approx 25km/day). 
              // Cap = 100 * (DurationHours / 24)
              double maxDistPoints = 100.0 * (safeDurationHours / 24.0);
              if (maxDistPoints < 10) maxDistPoints = 10; // Minimum cap buffer
              
              double distPoints = p.currentDistance / 250.0;
              if (distPoints > maxDistPoints) distPoints = maxDistPoints;
              
              double basePoints = survivalPoints + distPoints;
              
              if (p.captureState == 'captured') {
                  // CAPTURED PENALTY: 50% of accumulated points, NO bonus.
                  totalPoints = basePoints * 0.5;
                  pointsBreakdown = {
                      'survival': survivalPoints,
                      'distance': distPoints,
                      'penalty': '50% (Captured)',
                  };
              } else {
                  // SURVIVOR BONUS
                  // 12.5 * PlannedSessionLength (Hours) * LongSessionFactor
                  // Note: User said "Planned Session Length". We have session.durationDays.
                  double plannedHours = session.durationDays * 24.0;
                  double completionBonus = 12.5 * plannedHours * longSessionFactor;
                  
                  // Only award completion bonus if they actually WON (timeout reached)
                  // If chasers gave up or game stopped manually, maybe reduced bonus?
                  // Rule: "if they survive until timeout"
                  if (winnerRole == 'runner') {
                       totalPoints = basePoints + completionBonus;
                       pointsBreakdown = {
                          'survival': survivalPoints,
                          'distance': distPoints,
                          'completion_bonus': completionBonus,
                       };
                  } else {
                       // Game stopped early, no completion bonus but full base points?
                       totalPoints = basePoints;
                       pointsBreakdown = {
                          'survival': survivalPoints,
                          'distance': distPoints,
                          'note': 'No completion bonus (Manual Stop)',
                       };
                  }
              }
              
          } else if (p.role == 'chaser') {
              // CHASER SCORING
              
              // 1. Distance Points: 1 pt per 400m
              // Lower Daily Cap: 50 pts/day (approx 20km/day)? User said "lower daily cap". Let's assume 60.
              double maxDistPoints = 60.0 * (safeDurationHours / 24.0);
              if (maxDistPoints < 10) maxDistPoints = 10;
              
              double distPoints = p.currentDistance / 400.0;
              if (distPoints > maxDistPoints) distPoints = maxDistPoints;
              
              // 2. Capture Rewards
              // Base Bonus: 15 * SessionLength (Hours)
              // Multiplier: 0.5 * RunnerLongSessionFactor (which is just 'longSessionFactor' here)
              // Streak Multiplier: Grows with each capture cap 1.40.
              // Formula implies per-capture calc? Or total?
              // "per-session capture streak multiplier that grows with each additional capture"
              
              int myCaptures = chaserCaptureCounts[p.userId] ?? 0;
              double capturePoints = 0.0;
              
              // Let's assume simple linear growth for streak: 1.0, 1.1, 1.2, 1.3, 1.4 (Cap)
              // Or just `1.0 + (count * 0.1)` capped at 1.4?
              // double currentStreakMult = 1.0; 
              
              // Calculate points for EACH capture (if we tracked them individually we could do sequential)
              // Since we just have total count, we can simulate the sequence.
              for (int i = 0; i < myCaptures; i++) {
                   // Streak multiplier for THIS capture
                   // 1st capture: 1.0? Or starts with bonus?
                   // "grows *with each additional capture*". So 1st is base, 2nd is higher.
                   // Let's say: 1st=1.0, 2nd=1.1, 3rd=1.2...
                   double streak = 1.0 + (i * 0.1);
                   if (streak > 1.40) streak = 1.40;
                   
                   // Points for this capture
                   // 15 * SessionHours * (0.5 * LongSessionFactor) * Streak
                   double plannedHours = session.durationDays * 24.0;
                   double oneCaptureVal = 15.0 * plannedHours * (0.5 * longSessionFactor) * streak;
                   capturePoints += oneCaptureVal;
              }
              
              totalPoints = distPoints + capturePoints;
              
              // Fallback Reward
              if (myCaptures == 0 && winnerRole == 'chaser') {
                  // They didn't capture anyone but team won? Or just timeout reached?
                  // "chasers who fail to capture anyone by timeout receive at most a small fallback reward"
                  totalPoints += 50.0; // Small consolation
              }
              
              pointsBreakdown = {
                  'distance': distPoints,
                  'captures': myCaptures,
                  'capture_points': capturePoints,
              };
          }
          
          // CONVERT TO XP
          // 1 XP per 10 Session Points
          int xpEarned = (totalPoints / 10.0).floor();
          if (xpEarned < 0) xpEarned = 0; // Safety
          
          // Win/Loss Stat Update logic
          bool isWinner = (p.role == winnerRole);
          
          // Update Stats
          int newLevel = profile.level;
          int currentXP = profile.totalXP + xpEarned;
          
          // Dynamic Level Up Logic
          // Formula: Threshold = 100 * (1.1 ^ (level - 1))
          while (true) {
              int threshold = (100 * pow(1.1, newLevel - 1)).round();
              if (currentXP >= threshold) {
                  currentXP -= threshold;
                  newLevel++;
              } else {
                  break;
              }
          }
          
          // Stats
          int wins = profile.totalWins + (isWinner ? 1 : 0);
          int losses = profile.totalLosses + (!isWinner && winnerRole != 'none' ? 1 : 0);
          double totalDist = profile.totalDistance + p.currentDistance;
          
          playerResults[p.userId] = {
              'role': p.role,
              'outcome': isWinner ? 'won' : (winnerRole != 'none' ? 'lost' : 'neutral'),
              'xp_earned': xpEarned,
              'session_points': totalPoints.round(), // Save raw points too for display
              'old_level': profile.level,
              'new_level': newLevel,
              'new_total_xp': currentXP, // Added for accurate progress display
              'stats': {
                  'distance': p.currentDistance,
              },
              'breakdown': pointsBreakdown,
          };
          
          // Add Profile Update to Batch
          final profileRef = _firestore.collection('player_profiles').doc(p.userId);
          batch.set(profileRef, {
              'level': newLevel,
              'total_xp': currentXP,
              // 'xp_to_next_level': threshold, // Removed, dynamic now
              'total_games_played': FieldValue.increment(1),
              'total_wins': wins,
              'total_losses': losses,
              'total_distance': totalDist,
              'last_game_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      }
      
      // 4. Update Session Status & Results
      batch.update(_firestore.collection('sessions').doc(session.id), {
          'status': 'completed',
          'end_time': FieldValue.serverTimestamp(),
          'results': {
              'winner_role': winnerRole,
              'end_reason': endReason,
              'player_results': playerResults,
          }
      });
  }


  Future<void> stopGame(String sessionId) async {
    final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
    if(!sessionDoc.exists) return;
    final session = SessionModel.fromFirestore(sessionDoc);

    // Fetch players for stats
    final membersSnap = await _firestore.collection('session_members').where('session_id', isEqualTo: sessionId).get();
    final players = membersSnap.docs.map((d) => PlayerModel.fromFirestore(d)).toList();

    final batch = _firestore.batch();
    
    // Calculate partial results (End Reason: stopped)
    await _calculateAndSaveResults(session, players, batch, 'stopped');
    
    await batch.commit();
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
                
            sessions.addAll(
                sessionSnap.docs.map((doc) => SessionModel.fromFirestore(doc))
            );
          }
          
          return sessions;
        });
  }
}

class GameLogicResult {
  final String? endReason;
  final List<PlayerModel> finalPlayers;
  GameLogicResult(this.endReason, this.finalPlayers);
}
