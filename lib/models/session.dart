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
  final String? password;

  // Stats
  final int memberCount;
  
  // Game Settings
  final int durationDays;
  final int numChasers;
  
  // Rest Hours
  final int restStartHour; // 0-23
  final int restEndHour;   // 0-23
  
  // Headstart
  final double headstartDistance; // in meters
  final int headstartDuration;    // in minutes
  
  // Target Mode Specifics
  final int switchCooldown; // in minutes
  
  // Capture Settings
  final bool instantCapture;
  final int captureResistanceDuration; // in minutes
  final double captureResistanceDistance; // in meters

  final Timestamp? scheduledStartTime;
  final Timestamp? createdAt;

  SessionModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdBy,
    this.status = 'pending',
    this.gameMode = 'original',
    this.maxMembers = 8,
    this.visibility = 'private',
    this.joinCode,
    this.password,
    this.memberCount = 0,
    this.durationDays = 7,
    this.numChasers = 1,
    this.restStartHour = 0,
    this.restEndHour = 0,
    this.headstartDistance = 0,
    this.headstartDuration = 0,
    this.switchCooldown = 0,
    this.instantCapture = false,
    this.captureResistanceDuration = 0,
    this.captureResistanceDistance = 0,
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
      maxMembers: data['max_members'] ?? 8,
      visibility: data['visibility'] ?? 'private',
      joinCode: data['join_code'],
      password: data['password'],
      memberCount: data['member_count'] ?? 0,
      
      // Settings
      durationDays: settings['duration_days'] ?? 7,
      numChasers: settings['num_chasers'] ?? 1,
      restStartHour: settings['rest_start_hour'] ?? 0,
      restEndHour: settings['rest_end_hour'] ?? 0,
      headstartDistance: (settings['headstart_distance'] as num?)?.toDouble() ?? 0.0,
      headstartDuration: settings['headstart_duration'] ?? 0,
      switchCooldown: settings['switch_cooldown'] ?? 0,
      instantCapture: settings['instant_capture'] ?? false,
      captureResistanceDuration: settings['capture_resistance_duration'] ?? 0,
      captureResistanceDistance: (settings['capture_resistance_distance'] as num?)?.toDouble() ?? 0.0,
      
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
      'password': password,
      'member_count': memberCount,
      'settings': {
        'duration_days': durationDays,
        'num_chasers': numChasers,
        'rest_start_hour': restStartHour,
        'rest_end_hour': restEndHour,
        'headstart_distance': headstartDistance,
        'headstart_duration': headstartDuration,
        'switch_cooldown': switchCooldown,
        'instant_capture': instantCapture,
        'capture_resistance_duration': captureResistanceDuration,
        'capture_resistance_distance': captureResistanceDistance,
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
      password: password,
      durationDays: durationDays,
      numChasers: numChasers,
      restStartHour: restStartHour,
      restEndHour: restEndHour,
      headstartDistance: headstartDistance,
      headstartDuration: headstartDuration,
      switchCooldown: switchCooldown,
      instantCapture: instantCapture,
      captureResistanceDuration: captureResistanceDuration,
      captureResistanceDistance: captureResistanceDistance,
      scheduledStartTime: scheduledStartTime,
      createdAt: createdAt,
    );
  }
}
