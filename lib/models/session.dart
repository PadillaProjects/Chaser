import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String name;
  final String ownerId;
  final String createdBy;
  final String status; // 'pending', 'in_progress', 'completed'
  final String gameMode; // 'original', 'target'
  final int maxMembers;
  final String visibility; // 'public', 'private'
  final String? joinCode;
  
  // Stats
  final int memberCount;
  
  // Settings
  final int durationDays;
  final int numChasers;

  final Timestamp? scheduledStartTime;
  final Timestamp? createdAt;

  SessionModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdBy,
    this.status = 'pending',
    this.gameMode = 'original',
    this.maxMembers = 20,
    this.visibility = 'public',
    this.joinCode,
    this.memberCount = 1,
    this.durationDays = 7,
    this.numChasers = 1,
    this.scheduledStartTime,
    this.createdAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final settings = data['settings'] as Map<String, dynamic>? ?? {};

    return SessionModel(
      id: doc.id,
      name: data['session_name'] ?? 'Untitled Session',
      ownerId: data['owner_id'] ?? '',
      createdBy: data['created_by'] ?? '',
      status: data['status'] ?? 'pending',
      gameMode: data['game_mode'] ?? 'original',
      maxMembers: data['max_members'] ?? 20,
      visibility: data['visibility'] ?? 'public',
      joinCode: data['join_code'],
      memberCount: data['member_count'] ?? 1,
      durationDays: settings['duration_days'] ?? 7,
      numChasers: settings['num_chasers'] ?? 1,
      scheduledStartTime: data['scheduled_start_time'] as Timestamp?,
      createdAt: data['created_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_name': name,
      'owner_id': ownerId,
      'created_by': createdBy,
      'status': status,
      'game_mode': gameMode,
      'max_members': maxMembers,
      'visibility': visibility,
      'join_code': joinCode,
      'member_count': memberCount,
      'settings': {
        'duration_days': durationDays,
        'num_chasers': numChasers,
      },
      'scheduled_start_time': scheduledStartTime,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
  
  SessionModel copyWith({String? id}) {
    return SessionModel(
      id: id ?? this.id,
      name: name,
      ownerId: ownerId,
      createdBy: createdBy,
      status: status,
      gameMode: gameMode,
      maxMembers: maxMembers,
      visibility: visibility,
      joinCode: joinCode,
      durationDays: durationDays,
      numChasers: numChasers,
      scheduledStartTime: scheduledStartTime,
      createdAt: createdAt,
    );
  }
}
