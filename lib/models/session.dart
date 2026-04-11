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
  // durationDays stores the raw user-entered value; durationUnit tells us its unit.
  final int durationDays;
  final String durationUnit; // 'min', 'hours', 'days'
  final int numChasers;

  // Computed: canonical duration in minutes (used by game logic & timers)
  int get durationInMinutes {
    switch (durationUnit) {
      case 'min':
        return durationDays;
      case 'hours':
        return durationDays * 60;
      case 'days':
      default:
        return durationDays * 60 * 24;
    }
  }

  // Rest Hours
  final int restStartHour; // 0-23
  final int restEndHour;   // 0-23

  // Headstart
  final double headstartDistance;
  final String headstartDistanceUnit; // 'm', 'km', 'mi'
  final int headstartDuration;
  final String headstartDurationUnit; // 'min', 'hours', 'days'

  // Target Mode Specifics
  final int switchCooldown; // in minutes

  // Capture Settings
  final bool instantCapture;
  final int captureResistanceDuration;
  final String captureResistanceDurationUnit;
  final double captureResistanceDistance;
  final String captureResistanceDistanceUnit;

  final Timestamp? scheduledStartTime;
  final Timestamp? actualStartTime;
  final Timestamp? createdAt;

  // Endgame Results
  final Map<String, dynamic>? results;

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
    this.durationUnit = 'days',
    this.numChasers = 1,
    this.restStartHour = 0,
    this.restEndHour = 0,
    this.headstartDistance = 0,
    this.headstartDistanceUnit = 'm',
    this.headstartDuration = 0,
    this.headstartDurationUnit = 'min',
    this.switchCooldown = 0,
    this.instantCapture = false,
    this.captureResistanceDuration = 0,
    this.captureResistanceDurationUnit = 'min',
    this.captureResistanceDistance = 0,
    this.captureResistanceDistanceUnit = 'm',
    this.scheduledStartTime,
    this.actualStartTime,
    this.createdAt,
    this.results,
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
      durationUnit: settings['duration_unit'] ?? 'days',
      numChasers: settings['num_chasers'] ?? 1,
      restStartHour: settings['rest_start_hour'] ?? 0,
      restEndHour: settings['rest_end_hour'] ?? 0,
      headstartDistance: (settings['headstart_distance'] as num?)?.toDouble() ?? 0.0,
      headstartDistanceUnit: settings['headstart_distance_unit'] ?? 'm',
      headstartDuration: settings['headstart_duration'] ?? 0,
      headstartDurationUnit: settings['headstart_duration_unit'] ?? 'min',
      switchCooldown: settings['switch_cooldown'] ?? 0,
      instantCapture: settings['instant_capture'] ?? false,
      captureResistanceDuration: settings['capture_resistance_duration'] ?? 0,
      captureResistanceDurationUnit: settings['capture_resistance_duration_unit'] ?? 'min',
      captureResistanceDistance: (settings['capture_resistance_distance'] as num?)?.toDouble() ?? 0.0,
      captureResistanceDistanceUnit: settings['capture_resistance_distance_unit'] ?? 'm',

      scheduledStartTime: data['scheduled_start_time'] as Timestamp?,
      actualStartTime: data['actual_start_time'] as Timestamp?,
      createdAt: data['created_at'] as Timestamp?,
      results: data['results'] as Map<String, dynamic>?,
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
        'duration_unit': durationUnit,
        'num_chasers': numChasers,
        'rest_start_hour': restStartHour,
        'rest_end_hour': restEndHour,
        'headstart_distance': headstartDistance,
        'headstart_distance_unit': headstartDistanceUnit,
        'headstart_duration': headstartDuration,
        'headstart_duration_unit': headstartDurationUnit,
        'switch_cooldown': switchCooldown,
        'instant_capture': instantCapture,
        'capture_resistance_duration': captureResistanceDuration,
        'capture_resistance_duration_unit': captureResistanceDurationUnit,
        'capture_resistance_distance': captureResistanceDistance,
        'capture_resistance_distance_unit': captureResistanceDistanceUnit,
      },
      'scheduled_start_time': scheduledStartTime,
      'actual_start_time': actualStartTime,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'results': results,
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
      durationUnit: durationUnit,
      numChasers: numChasers,
      restStartHour: restStartHour,
      restEndHour: restEndHour,
      headstartDistance: headstartDistance,
      headstartDistanceUnit: headstartDistanceUnit,
      headstartDuration: headstartDuration,
      headstartDurationUnit: headstartDurationUnit,
      switchCooldown: switchCooldown,
      instantCapture: instantCapture,
      captureResistanceDuration: captureResistanceDuration,
      captureResistanceDurationUnit: captureResistanceDurationUnit,
      captureResistanceDistance: captureResistanceDistance,
      captureResistanceDistanceUnit: captureResistanceDistanceUnit,
      scheduledStartTime: scheduledStartTime,
      actualStartTime: actualStartTime,
      createdAt: createdAt,
      results: results,
    );
  }
}
