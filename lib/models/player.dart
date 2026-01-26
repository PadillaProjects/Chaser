import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerModel {
  final String sessionMemberId;
  final String sessionId;
  final String userId;
  final String role; // 'chaser', 'runner', 'spectator'
  final bool isOwner;
  final bool readyStatus;
  final double currentDistance;
  final int totalSteps;
  final String captureState; // 'free', 'being_chased', 'captured'
  final Timestamp? captureDeadline; // Added
  final Timestamp? joinedAt; // Added back

  PlayerModel({
    required this.sessionMemberId,
    required this.sessionId,
    required this.userId,
    required this.role,
    this.isOwner = false,
    this.readyStatus = false,
    this.currentDistance = 0,
    this.totalSteps = 0,
    this.captureState = 'free',
    this.joinedAt,
    this.captureDeadline,
  });

  factory PlayerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerModel(
      sessionMemberId: doc.id,
      sessionId: data['session_id'] ?? '',
      userId: data['user_id'] ?? '',
      role: data['role'] ?? 'spectator',
      isOwner: data['is_owner'] ?? false,
      readyStatus: data['ready_status'] ?? false,
      currentDistance: (data['current_distance'] ?? 0).toDouble(),
      totalSteps: data['total_steps'] ?? 0,
      captureState: data['capture_state'] ?? 'free',
      joinedAt: data['joined_at'] as Timestamp?,
      captureDeadline: data['capture_deadline'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'role': role,
      'is_owner': isOwner,
      'ready_status': readyStatus,
      'current_distance': currentDistance,
      'total_steps': totalSteps,
      'capture_state': captureState,
      'joined_at': joinedAt ?? FieldValue.serverTimestamp(),
      'capture_deadline': captureDeadline,
    };
  }
}
