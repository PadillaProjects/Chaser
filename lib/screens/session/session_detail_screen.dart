import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chaser/config/colors.dart';
import 'package:chaser/models/player.dart';
import 'package:chaser/models/player_profile.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/screens/session/edit_session_sheet.dart';
import 'package:chaser/services/pedometer_service.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:chaser/utils/unit_converter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaser/models/user_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:chaser/screens/session/game_results_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chaser/widgets/session/distance_track_widget.dart';

final sessionStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSession(sessionId);
});

final playersStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSessionPlayers(sessionId);
});

final userProfileFamily = StreamProvider.family<UserProfile, String>((ref, String userId) {
  return FirestoreService().watchUserProfile(userId);
});

final otherPlayerProfileFamily = StreamProvider.family<PlayerProfile?, String>((ref, String userId) {
   return FirestoreService().watchPlayerProfile(userId);
});

class LocalDistanceNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void update(double dist) => state = dist;
}

final localDistanceProvider = NotifierProvider<LocalDistanceNotifier, double?>(LocalDistanceNotifier.new);

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _firestoreService = FirestoreService();
  bool _showResults = true;

  Future<void> _pickScheduledTime(Timestamp? currentScheduledTime) async {
    final now = DateTime.now();
    final current = currentScheduledTime?.toDate() ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );

      if (time != null) {
        final newDateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute
        );

        await _firestoreService.updateSession(widget.sessionId, {
          'scheduled_start_time': Timestamp.fromDate(newDateTime),
        });
      }
    }
  }

  Future<void> _clearScheduledTime() async {
    await _firestoreService.updateSession(widget.sessionId, {
      'scheduled_start_time': null,
    });
  }

  Future<void> _leaveSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'TRY TO ESCAPE?',
          style: GoogleFonts.specialElite(fontSize: 24, color: AppColors.ghostWhite),
        ),
        content: Text(
          'Are you sure you want to leave them behind?',
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('STAY', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text('FLEE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final userId = AuthService().currentUser?.uid;
        if (userId != null) {
          await _firestoreService.leaveSession(widget.sessionId, userId);
          if (mounted) context.go('/');
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error leaving: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStreamProvider(widget.sessionId));
    final playersAsync = ref.watch(playersStreamProvider(widget.sessionId));
    final currentUser = AuthService().currentUser;
    final localDist = ref.watch(localDistanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'THE GROUNDS',
          style: GoogleFonts.specialElite(fontSize: 24, letterSpacing: 2, color: AppColors.ghostWhite),
        ),
        actions: [
          sessionAsync.when(
            data: (session) {
              final isOwner = session.ownerId == currentUser?.uid;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Settings button for active games (read-only view)
                  if (session.status == 'active')
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                      tooltip: 'Game Rules',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.fogGrey,
                          builder: (context) => _GameRulesSheet(session: session),
                        );
                      },
                    ),
                  if (session.status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: AppColors.bloodRed),
                      tooltip: 'Flee the Zone',
                      onPressed: _leaveSession,
                    ),
                  if (isOwner && session.status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.settings, color: AppColors.textSecondary),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: AppColors.fogGrey,
                          builder: (context) => EditSessionSheet(session: session),
                        );
                      },
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed)),
        ),
        data: (session) {
          if (session.status == 'completed' && _showResults && session.results != null) {
              return GameResultsView(
                  session: session,
                  currentUserId: currentUser?.uid ?? '',
                  onDismiss: () => setState(() => _showResults = false),
              );
          }

          // Different layouts for pending vs active games
          if (session.status == 'active') {
            return _buildActiveGameView(session, currentUser, playersAsync, localDist);
          }
          
          // Pending game layout (original)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                color: AppColors.fogGrey,
                child: Column(
                  children: [
                    Text(
                      session.name.toUpperCase(),
                      style: GoogleFonts.specialElite(
                        fontSize: 28,
                        color: AppColors.ghostWhite,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusChip(session.status),
                    const SizedBox(height: 12),
                    Text(
                      '${session.gameMode.toUpperCase()} • ${session.durationDays} ${session.durationUnit.toUpperCase()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                    if (session.joinCode != null) ...[
                       const SizedBox(height: 16),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                         decoration: BoxDecoration(
                           color: AppColors.voidBlack,
                           border: Border.all(color: AppColors.bloodRed, width: 2),
                           boxShadow: [
                             BoxShadow(
                               color: AppColors.bloodRed.withOpacity(0.3),
                               blurRadius: 10,
                             ),
                           ],
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(
                               'CODE: ',
                               style: GoogleFonts.jetBrainsMono(
                                 color: AppColors.textSecondary,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             Text(
                               session.joinCode!,
                               style: GoogleFonts.jetBrainsMono(
                                 color: AppColors.bloodRed,
                                 fontSize: 24,
                                 fontWeight: FontWeight.bold,
                                 letterSpacing: 4,
                               ),
                             ),
                           ],
                         ),
                       ),
                    ],
                     const SizedBox(height: 8),
                    Text(
                      '${session.memberCount} / ${session.maxMembers} SURVIVORS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.textMuted),

              // Game Rules Summary
              ExpansionTile(
                title: Text(
                  'GAME RULES',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ghostWhite,
                    letterSpacing: 2,
                  ),
                ),
                leading: const Icon(Icons.info_outline, color: AppColors.bloodRed),
                collapsedIconColor: AppColors.textSecondary,
                iconColor: AppColors.bloodRed,
                children: [
                  ListTile(
                    dense: true,
                    title: Text(
                      'Duration: ${session.durationDays} ${session.durationUnit}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.timer_outlined, color: AppColors.warningYellow, size: 20),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'Chasers: ${session.numChasers}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.gps_fixed, color: AppColors.bloodRed, size: 20),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'Headstart: ${(session.headstartDistance > 0 || session.headstartDuration > 0) ? "${UnitConverter.formatDistance(session.headstartDistance, session.headstartDistanceUnit)} / ${UnitConverter.formatDuration(session.headstartDuration, session.headstartDurationUnit)}" : "None"}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.run_circle_outlined, color: AppColors.pulseBlue, size: 20),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'Rest Hours: ${(session.restStartHour != session.restEndHour) ? "${session.restStartHour}:00 - ${session.restEndHour}:00" : "None"}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.bedtime_outlined, color: AppColors.textSecondary, size: 20),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'Capture: ${session.instantCapture ? "Instant Kill" : "Resist ${UnitConverter.formatDuration(session.captureResistanceDuration, session.captureResistanceDurationUnit)} / ${UnitConverter.formatDistance(session.captureResistanceDistance, session.captureResistanceDistanceUnit)}"}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.touch_app_outlined, color: AppColors.bloodRed, size: 20),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'Switch Cooldown: ${(session.gameMode == 'target') ? "${session.switchCooldown} min" : "None"}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                    ),
                    leading: const Icon(Icons.swap_horiz, color: AppColors.warningYellow, size: 20),
                  ),
                ],
              ),
              const Divider(height: 1, color: AppColors.textMuted),

              // Players List
              Expanded(
                child: playersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                  error: (e,s) => Center(
                    child: Text('Error loading players: $e', style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed)),
                  ),
                  data: (players) {
                    if (players.isEmpty) {
                      return Center(
                        child: Text(
                          'It\'s quiet. Too quiet...',
                          style: GoogleFonts.jetBrainsMono(color: AppColors.textMuted, fontStyle: FontStyle.italic),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        return SessionPlayerTile(
                          sessionId: widget.sessionId,
                          userId: player.userId,
                          role: player.role,
                          isOwner: player.isOwner,
                          currentDistance: player.currentDistance,
                        );
                      },
                    );
                  },
                ),
              ),

              // Action Buttons
              _buildActionButtons(session, currentUser?.uid),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppColors.warningYellow.withOpacity(0.2);
        textColor = AppColors.warningYellow;
        label = 'WAITING...';
        break;
      case 'active':
        bgColor = AppColors.bloodRed.withOpacity(0.2);
        textColor = AppColors.bloodRed;
        label = 'GAME ACTIVE';
        break;
      case 'completed':
        bgColor = AppColors.textMuted.withOpacity(0.2);
        textColor = AppColors.textSecondary;
        label = 'GAME ENDED';
        break;
      default:
        bgColor = AppColors.fogGrey;
        textColor = AppColors.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: bgColor,
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildActiveGameView(
    SessionModel session,
    User? currentUser,
    AsyncValue<List<PlayerModel>> playersAsync,
    double? localDist,
  ) {
    return playersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
      error: (e, s) => Center(
        child: Text('Error loading players: $e', style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed)),
      ),
      data: (players) {
        final myPlayer = players.where((p) => p.userId == currentUser?.uid).firstOrNull;
        final runnersLeft = players.where((p) => p.role == 'runner' && p.captureState != 'captured').length;
        final showCaptureWarning = myPlayer?.captureState == 'being_chased' && myPlayer?.captureDeadline != null;
        final isChaser = myPlayer?.role == 'chaser';
        final victims = players.where((p) => p.role == 'runner' && p.captureState == 'being_chased' && p.captureDeadline != null).toList();
        final showChaserStatus = isChaser && victims.isNotEmpty;

        return Stack(
          children: [
            _GameLoopMonitor(
              sessionId: widget.sessionId,
              players: players,
            ),
            if (session.actualStartTime != null || session.scheduledStartTime != null)
              _DistanceMonitor(
                sessionId: widget.sessionId,
                userId: currentUser?.uid,
                session: session,
                startTime: session.actualStartTime?.toDate() ?? session.scheduledStartTime?.toDate() ?? DateTime.now(),
                baseOffset: (myPlayer?.role == 'runner') ? session.headstartDistance : 0.0,
              ),
            Column(
              children: [
                // Game Stats Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.fogGrey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Time Remaining
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, color: AppColors.warningYellow, size: 18),
                              const SizedBox(width: 6),
                              _GameEndTimer(
                                endTime: (session.actualStartTime?.toDate() ?? DateTime.now())
                                    .add(Duration(minutes: session.durationInMinutes)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TIME LEFT',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: AppColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      // Headstart Timer (if active)
                      if (_isheadstartActive(session))
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.run_circle, color: AppColors.pulseBlue, size: 18),
                                const SizedBox(width: 6),
                                _HeadstartTimer(
                                  endTime: (session.actualStartTime?.toDate() ??
                                           session.scheduledStartTime?.toDate() ??
                                           DateTime.now())
                                          .add(Duration(minutes: session.headstartDuration)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'HEADSTART',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                color: AppColors.textMuted,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      // Runners Left
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.directions_run, color: AppColors.pulseBlue, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '$runnersLeft',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.toxicGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RUNNERS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: AppColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Capture Warnings
                if (showCaptureWarning)
                  _CaptureWarningPanel(
                    player: myPlayer!,
                    sessionId: widget.sessionId,
                  ),
                if (showChaserStatus)
                  _ChaserCaptureStatus(
                    victims: victims,
                    sessionId: widget.sessionId,
                  ),
                
                // Distance Track (expanded main area)
                Expanded(
                  child: DistanceTrackWidget(
                    sessionId: widget.sessionId,
                    players: players,
                    currentUserId: currentUser?.uid,
                    localDistance: localDist,
                  ),
                ),
                
                // Collapsible Player List
                Container(
                  color: AppColors.fogGrey,
                  child: ExpansionTile(
                    title: Text(
                      'PLAYERS (${players.length})',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: AppColors.ghostWhite,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    leading: const Icon(Icons.people, color: AppColors.bloodRed, size: 20),
                    collapsedIconColor: AppColors.textSecondary,
                    iconColor: AppColors.bloodRed,
                    initiallyExpanded: false,
                    children: players.map((player) => SessionPlayerTile(
                      sessionId: widget.sessionId,
                      userId: player.userId,
                      role: player.role,
                      isOwner: player.isOwner,
                      currentDistance: player.currentDistance,
                    )).toList(),
                  ),
                ),
                
                // Action Buttons
                _buildActionButtons(session, currentUser?.uid),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(SessionModel session, String? currentUserId) {
    final isOwner = session.ownerId == currentUserId;

    if (isOwner && session.status == 'active') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.warningYellow.withOpacity(0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _stopGame(session.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningYellow,
              foregroundColor: AppColors.voidBlack,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            icon: const Icon(Icons.stop),
            label: Text(
              'END GAME',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        ),
      );
    } else if (isOwner && session.status == 'pending') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'SCHEDULE GAME',
                style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite, letterSpacing: 2),
              ),
              subtitle: Text(
                session.scheduledStartTime == null
                    ? 'Not scheduled'
                    : 'Scheduled: ${session.scheduledStartTime!.toDate().toString().split('.')[0]}',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.scheduledStartTime != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.bloodRed),
                      onPressed: _clearScheduledTime,
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: AppColors.pulseBlue),
                    onPressed: () => _pickScheduledTime(session.scheduledStartTime),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bloodRed.withOpacity(0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _startGame(session),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodRed,
                  foregroundColor: AppColors.ghostWhite,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'LET THEM LOOSE',
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isOwner && session.status == 'completed') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => _resetGame(session.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningYellow,
                foregroundColor: AppColors.voidBlack,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                'RESET GAME',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _showResults = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ghostWhite,
                side: const BorderSide(color: AppColors.ghostWhite),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(
                'VIEW RESULTS',
                style: GoogleFonts.jetBrainsMono(letterSpacing: 2),
              ),
            ),
          ],
        ),
      );
    } else if (session.status == 'completed') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Text(
                'IT\'S OVER',
                style: GoogleFonts.specialElite(fontSize: 20, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() => _showResults = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ghostWhite,
                  side: const BorderSide(color: AppColors.ghostWhite),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'VIEW RESULTS',
                  style: GoogleFonts.jetBrainsMono(letterSpacing: 2),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            session.status == 'active' ? 'They\'re coming...' : 'Someone is watching...',
            style: GoogleFonts.jetBrainsMono(color: AppColors.textMuted, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
  }

  Future<void> _startGame(SessionModel session) async {
    try {
      await _firestoreService.startGame(widget.sessionId, session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'The Game Begins.',
              style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
            ),
            backgroundColor: AppColors.bloodRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting game: $e')),
        );
      }
    }
  }

  Future<void> _stopGame(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'END THE CHASE?',
          style: GoogleFonts.creepster(fontSize: 24, color: AppColors.ghostWhite),
        ),
        content: Text(
          'This will calculate results and end the session.',
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CONTINUE', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningYellow,
              foregroundColor: AppColors.voidBlack,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text('END CHASE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
        try {
            await _firestoreService.stopGame(sessionId);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chase Ended.')),
                );
              }
        } catch(e) {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error stopping game: $e')),
                );
              }
        }
    }
  }

  Future<void> _resetGame(String sessionId) async {
      final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'RESET CHASE?',
          style: GoogleFonts.creepster(fontSize: 24, color: AppColors.ghostWhite),
        ),
        content: Text(
          'This will reset the game to pending state.',
          style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningYellow,
              foregroundColor: AppColors.voidBlack,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text('RESET', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
         try {
            await _firestoreService.resetGame(sessionId);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chase Reset.')),
                );
              }
        } catch(e) {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error resetting game: $e')),
                );
              }
        }
    }
  }

  bool _isheadstartActive(SessionModel session) {
    if (session.headstartDuration <= 0) return false;
    final start = session.actualStartTime?.toDate() ?? session.scheduledStartTime?.toDate();
    if (start == null) return false;

    final end = start.add(Duration(minutes: session.headstartDuration));
    return DateTime.now().isBefore(end);
  }
}

class _CaptureWarningPanel extends StatelessWidget {
  final PlayerModel player;
  final String sessionId;

  const _CaptureWarningPanel({required this.player, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bloodRed.withOpacity(0.15),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.bloodRed.withOpacity(0.3),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.bloodRed, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAPTURE IMMINENT',
                  style: GoogleFonts.creepster(
                    color: AppColors.bloodRed,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Escape by increasing your distance!',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                ),
                const SizedBox(height: 8),
                _CaptureTimer(
                    endTime: player.captureDeadline!.toDate(),
                    onExpired: () => FirestoreService().triggerCaptureCheck(sessionId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SessionPlayerTile extends ConsumerWidget {
  final String sessionId;
  final String userId;
  final String role;
  final bool isOwner;
  final double currentDistance;

  const SessionPlayerTile({
    super.key,
    required this.sessionId,
    required this.userId,
    required this.role,
    this.isOwner = false,
    this.currentDistance = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileFamily(userId));
    final localDist = ref.watch(localDistanceProvider);
    final currentUser = AuthService().currentUser;
    final isMe = currentUser?.uid == userId;

    double effectiveDistance = currentDistance;
    if (isMe && localDist != null) {
        effectiveDistance = localDist;
    }

    final isChaser = role == 'chaser';
    final roleColor = isChaser ? AppColors.bloodRed : AppColors.pulseBlue;
    final roleIcon = isChaser ? Icons.gps_fixed : Icons.directions_run;
    final roleLabel = isChaser ? 'CHASER' : 'RUNNER';

    return userProfileAsync.when(
      data: (user) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.fogGrey,
            border: Border(
              left: BorderSide(color: roleColor, width: 4),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: roleColor.withOpacity(0.2),
              child: Icon(roleIcon, color: roleColor),
            ),
            title: Text(
              user.displayName.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                color: AppColors.ghostWhite,
                letterSpacing: 1,
              ),
            ),
            subtitle: Row(
              children: [
                  Text(
                    roleLabel,
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: roleColor, letterSpacing: 1),
                  ),
                  if (effectiveDistance >= 0) ...[
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '${effectiveDistance.toStringAsFixed(0)}m',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          color: AppColors.toxicGreen,
                        ),
                      ),
                  ]
              ],
            ),
            trailing: isOwner
                ? const Icon(Icons.star, color: AppColors.warningYellow)
                : Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => _showPlayerStats(context, ref, user.displayName),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: AppColors.fogGrey,
        child: const ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.voidBlack,
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bloodRed)),
          ),
          title: Text('Loading...'),
        ),
      ),
      error: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: AppColors.fogGrey,
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.bloodRed,
            child: Icon(Icons.error, color: AppColors.ghostWhite),
          ),
          title: Text(
            'Unknown User',
            style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Future<void> _showPlayerStats(BuildContext context, WidgetRef ref, String displayName) async {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: AppColors.fogGrey,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Text(
              '${displayName.toUpperCase()}\'S STATS',
              style: GoogleFonts.creepster(fontSize: 20, color: AppColors.ghostWhite),
            ),
            content: Consumer(
                builder: (context, ref, child) {
                    final otherPlayerStats = ref.watch(otherPlayerProfileFamily(userId));
                    final sessionPlayersAsync = ref.watch(playersStreamProvider(sessionId));

                    final livePlayer = sessionPlayersAsync.asData?.value
                        .where((p) => p.userId == userId)
                        .firstOrNull;
                    final liveDistance = livePlayer?.currentDistance ?? 0.0;

                    return otherPlayerStats.when(
                        data: (stats) {
                            if (stats == null) {
                              return Text(
                                'No stats available.',
                                style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
                              );
                            }
                            return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                    _statRow('Games Played', '${stats.totalGamesPlayed}'),
                                    _statRow('Wins', '${stats.totalWins}'),
                                    _statRow('Captures', '${stats.totalCaptures}'),
                                    _statRow('Escapes', '${stats.totalEscapes}'),
                                    _statRow('Total Distance', '${stats.totalDistance.toStringAsFixed(1)}m'),
                                    const SizedBox(height: 16),
                                    const Divider(color: AppColors.textMuted),
                                    Text('DEBUG', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted, letterSpacing: 2)),
                                    _statRow('Current Distance', '${liveDistance.toStringAsFixed(1)}m'),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.bloodRed),
                                          onPressed: () => _updateDistance(liveDistance, -1.0),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.toxicGreen),
                                          onPressed: () => _updateDistance(liveDistance, 1.0),
                                        ),
                                        TextButton(
                                          onPressed: () => _setDistanceDialog(context, liveDistance),
                                          child: Text('SET', style: GoogleFonts.jetBrainsMono(color: AppColors.pulseBlue)),
                                        ),
                                      ],
                                    ),
                                ],
                            );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                        error: (e,s) => Text('Error: $e', style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed)),
                    );
                }
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CLOSE', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary, letterSpacing: 2)),
                ),
            ],
        ),
      );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ghostWhite)),
        ],
      ),
    );
  }

  Future<void> _updateDistance(double currentDist, double delta) async {
      final newDistance = (currentDist + delta) < 0 ? 0.0 : (currentDist + delta);
      await FirestoreService().updatePlayerDistance(sessionId, userId, newDistance);
  }

  Future<void> _setDistanceDialog(BuildContext context, double currentDist) async {
      final controller = TextEditingController(text: currentDist.toStringAsFixed(1));

      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
              backgroundColor: AppColors.fogGrey,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text('SET DISTANCE', style: GoogleFonts.creepster(fontSize: 20, color: AppColors.ghostWhite)),
              content: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
                  decoration: InputDecoration(
                    labelText: 'Distance (meters)',
                    labelStyle: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.voidBlack,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary)),
                  ),
                  FilledButton(
                      onPressed: () async {
                          final val = double.tryParse(controller.text);
                          if (val != null) {
                              await FirestoreService().updatePlayerDistance(sessionId, userId, val);
                              if (context.mounted) Navigator.pop(context);
                          }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bloodRed,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: Text('SAVE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                  ),
              ],
          ),
      );
  }
}

class _HeadstartTimer extends StatefulWidget {
    final DateTime endTime;

    const _HeadstartTimer({required this.endTime, Key? key}) : super(key: key);

    @override
    State<_HeadstartTimer> createState() => _HeadstartTimerState();
}

class _HeadstartTimerState extends State<_HeadstartTimer> {
    late Stream<int> _timer;

    @override
    void initState() {
        super.initState();
        _timer = Stream.periodic(const Duration(seconds: 1), (x) => x);
    }

    @override
    Widget build(BuildContext context) {
        return StreamBuilder<int>(
            stream: _timer,
            builder: (context, snapshot) {
                final now = DateTime.now();
                final remaining = widget.endTime.difference(now);

                if (remaining.isNegative) {
                    return Text(
                      'RELEASED!',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: AppColors.bloodRed,
                        letterSpacing: 2,
                      ),
                    );
                }

                final m = remaining.inMinutes;
                final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

                return Text(
                  'RELEASE IN $m:$s',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningYellow,
                    letterSpacing: 1,
                  ),
                );
            }
        );
    }
}

// Game End Timer - shows days/hours/minutes remaining
class _GameEndTimer extends StatefulWidget {
    final DateTime endTime;

    const _GameEndTimer({required this.endTime, Key? key}) : super(key: key);

    @override
    State<_GameEndTimer> createState() => _GameEndTimerState();
}

class _GameEndTimerState extends State<_GameEndTimer> {
    late Stream<int> _timer;

    @override
    void initState() {
        super.initState();
        _timer = Stream.periodic(const Duration(minutes: 1), (x) => x);
    }

    @override
    Widget build(BuildContext context) {
        return StreamBuilder<int>(
            stream: _timer,
            builder: (context, snapshot) {
                final now = DateTime.now();
                final remaining = widget.endTime.difference(now);

                if (remaining.isNegative) {
                    return Text(
                      'ENDED',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: AppColors.bloodRed,
                        fontSize: 14,
                      ),
                    );
                }

                final days = remaining.inDays;
                final hours = remaining.inHours % 24;
                final mins = remaining.inMinutes % 60;

                String timeStr;
                if (days > 0) {
                  timeStr = '${days}d ${hours}h';
                } else if (hours > 0) {
                  timeStr = '${hours}h ${mins}m';
                } else {
                  timeStr = '${mins}m';
                }

                return Text(
                  timeStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningYellow,
                    fontSize: 14,
                  ),
                );
            }
        );
    }
}

// Game Rules Sheet - Read-only view of game rules
class _GameRulesSheet extends StatelessWidget {
  final SessionModel session;

  const _GameRulesSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.bloodRed),
              const SizedBox(width: 12),
              Text(
                'CHASE RULES',
                style: GoogleFonts.creepster(
                  fontSize: 24,
                  color: AppColors.ghostWhite,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.textMuted),
          _buildRuleRow(
            Icons.calendar_today,
            'Duration',
            '${session.durationDays} ${session.durationUnit}',
            AppColors.warningYellow,
          ),
          _buildRuleRow(
            Icons.gps_fixed,
            'Chasers',
            '${session.numChasers}',
            AppColors.bloodRed,
          ),
          _buildRuleRow(
            Icons.run_circle_outlined,
            'Headstart',
            (session.headstartDistance > 0 || session.headstartDuration > 0) ? '${UnitConverter.formatDistance(session.headstartDistance, session.headstartDistanceUnit)} / ${UnitConverter.formatDuration(session.headstartDuration, session.headstartDurationUnit)}' : 'None',
            AppColors.pulseBlue,
          ),
          _buildRuleRow(
            Icons.bedtime_outlined,
            'Rest Hours',
            (session.restStartHour != session.restEndHour) ? '${session.restStartHour}:00 - ${session.restEndHour}:00' : 'None',
            AppColors.textSecondary,
          ),
          _buildRuleRow(
            Icons.touch_app_outlined,
            'Capture',
            session.instantCapture ? 'Instant Kill' : 'Resist ${UnitConverter.formatDuration(session.captureResistanceDuration, session.captureResistanceDurationUnit)} / ${UnitConverter.formatDistance(session.captureResistanceDistance, session.captureResistanceDistanceUnit)}',
            AppColors.bloodRed,
          ),
          _buildRuleRow(
            Icons.swap_horiz,
            'Switch Cooldown',
            (session.gameMode == 'target') ? '${session.switchCooldown} min' : 'None',
            AppColors.warningYellow,
          ),
          _buildRuleRow(
            Icons.videogame_asset,
            'Game Mode',
            session.gameMode.toUpperCase(),
            AppColors.toxicGreen,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.ghostWhite,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureTimer extends StatefulWidget {
    final DateTime endTime;
    final VoidCallback? onExpired;

    const _CaptureTimer({required this.endTime, this.onExpired, Key? key}) : super(key: key);

    @override
    State<_CaptureTimer> createState() => _CaptureTimerState();
}

class _CaptureTimerState extends State<_CaptureTimer> {
    late Stream<int> _timer;
    bool _expiredTriggered = false;

    @override
    void initState() {
        super.initState();
        _timer = Stream.periodic(const Duration(seconds: 1), (x) => x);
    }

    @override
    Widget build(BuildContext context) {
        return StreamBuilder<int>(
            stream: _timer,
            builder: (context, snapshot) {
                final now = DateTime.now();
                final remaining = widget.endTime.difference(now);

                if (remaining.isNegative) {
                    if (!_expiredTriggered) {
                        _expiredTriggered = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           widget.onExpired?.call();
                        });
                    }
                    return Text(
                      'CAPTURING...',
                      style: GoogleFonts.creepster(
                        color: AppColors.bloodRed,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    );
                }

                final m = remaining.inMinutes;
                final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');

                return Text(
                    'TIME REMAINING: $m:$s',
                    style: GoogleFonts.jetBrainsMono(
                      color: AppColors.bloodRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                );
            }
        );
    }
}

class _GameLoopMonitor extends StatefulWidget {
  final String sessionId;
  final List<PlayerModel> players;

  const _GameLoopMonitor({
    required this.sessionId,
    required this.players,
    Key? key,
  }) : super(key: key);

  @override
  State<_GameLoopMonitor> createState() => _GameLoopMonitorState();
}

class _GameLoopMonitorState extends State<_GameLoopMonitor> {
  Timer? _monitorTimer;
  bool _isTriggering = false;

  @override
  void initState() {
    super.initState();
    _monitorTimer = Timer.periodic(const Duration(seconds: 2), _checkDeadlines);
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeadlines(Timer t) async {
    if (_isTriggering) return;

    final now = DateTime.now();
    bool needsTrigger = false;

    for (final player in widget.players) {
      if (player.role == 'runner' &&
          player.captureState == 'being_chased' &&
          player.captureDeadline != null) {

          if (now.isAfter(player.captureDeadline!.toDate())) {
            needsTrigger = true;
            break;
          }
      }
    }

    if (needsTrigger) {
      _isTriggering = true;
      debugPrint("GameLoopMonitor: Detected expired deadline. Triggering capture check...");
      try {
        await FirestoreService().triggerCaptureCheck(widget.sessionId);
      } catch (e) {
        debugPrint("GameLoopMonitor Error: $e");
      } finally {
        if (mounted) {
           setState(() {
             _isTriggering = false;
           });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ChaserCaptureStatus extends ConsumerWidget {
  final List<PlayerModel> victims;
  final String sessionId;

  const _ChaserCaptureStatus({
    required this.victims,
    required this.sessionId,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      if (victims.isEmpty) return const SizedBox.shrink();

      final victim = victims.first;
      final userProfileAsync = ref.watch(userProfileFamily(victim.userId));

      return Container(
        color: AppColors.toxicGreen.withOpacity(0.15),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.toxicGreen.withOpacity(0.3),
              child: const Icon(Icons.track_changes, color: AppColors.toxicGreen, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userProfileAsync.when(
                    data: (profile) => Text(
                        'CAPTURING ${profile?.displayName.toUpperCase() ?? 'RUNNER'}!',
                        style: GoogleFonts.creepster(
                          color: AppColors.toxicGreen,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                    ),
                    loading: () => Text(
                      'CAPTURING...',
                      style: GoogleFonts.creepster(color: AppColors.toxicGreen, fontSize: 16),
                    ),
                    error: (_,__) => Text(
                      'CAPTURING...',
                      style: GoogleFonts.creepster(color: AppColors.toxicGreen, fontSize: 16),
                    ),
                  ),
                  Text(
                    "Don't let them escape!",
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.ghostWhite),
                  ),
                  const SizedBox(height: 8),
                  _CaptureTimer(
                      endTime: victim.captureDeadline!.toDate(),
                      onExpired: () => FirestoreService().triggerCaptureCheck(sessionId),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _DistanceMonitor extends ConsumerStatefulWidget {
  final String sessionId;
  final String? userId;
  final SessionModel session;
  final DateTime startTime;
  final double baseOffset;

  const _DistanceMonitor({
    required this.sessionId,
    required this.userId,
    required this.session,
    required this.startTime,
    this.baseOffset = 0.0,
    super.key,
  });

  @override
  ConsumerState<_DistanceMonitor> createState() => _DistanceMonitorState();
}

class _DistanceMonitorState extends ConsumerState<_DistanceMonitor> {
  final PedometerService _pedometerService = PedometerService();
  Timer? _timer;

  // Total verified distance to write to Firestore (starts at baseOffset).
  double _totalDistance = 0.0;

  // The distance value most recently committed to Firestore.
  double _lastWrittenDistance = -1.0;

  // The pedometer window: we query from _windowStart to now each tick,
  // then advance _windowStart = now so the next tick gets only new movement.
  late DateTime _windowStart;

  // ─── Dynamic thresholds ────────────────────────────────────────────────────

  /// How often (seconds) to poll the pedometer.
  ///
  /// Scaled to captureResistanceDuration so we poll at least 8×
  /// per resistance window. Range: 10–60 s.
  int get _checkIntervalSecs {
    final resistanceSecs = widget.session.captureResistanceDuration * 60;
    if (resistanceSecs <= 0) return 10;
    return (resistanceSecs / 8).clamp(10, 60).toInt();
  }

  /// Minimum movement (metres) in a single check window to count as real
  /// walking (anti-pocket-shuffle noise gate).
  ///
  /// Must stay well below captureResistanceDistance so we never discard
  /// movement that closes the gap between two players. Capped at the
  /// smaller of captureDistance/10 or 5 m.
  double get _noiseGateMeters {
    const absoluteMax = 5.0;
    const absoluteMin = 2.0;
    final captureDist = widget.session.captureResistanceDistance;
    if (captureDist <= 0) return absoluteMin; // instant-capture: minimal gate
    // Allow at most 1/10th of the capture radius per window to be discarded.
    final captureBound = captureDist / 10.0;
    return captureBound.clamp(absoluteMin, absoluteMax);
  }

  /// Minimum accumulated movement (metres) before writing to Firestore.
  ///
  /// Driven by two competing needs:
  ///  - Long-game efficiency  → write less often (push threshold up)
  ///  - Capture accuracy      → write before players cross the zone (push down)
  ///
  /// Rule: always at most captureResistanceDistance / 4.
  /// That guarantees at least 4 positional updates while two players close
  /// from capture-range to contact, so the server never misses the window.
  double get _writeThresholdMeters {
    // Duration-based upper bound: e.g. 7-day game → 100 m, 10-min test → 5 m.
    final durationBound = (widget.session.durationInMinutes / 100.0).clamp(5.0, 100.0);

    final captureDist = widget.session.captureResistanceDistance;
    if (captureDist <= 0) return durationBound; // instant-capture: pure duration bound

    // Capture-accuracy bound: write at least every ¼ of capture distance.
    final captureBound = captureDist / 4.0;

    // Take whichever is tighter.
    return durationBound < captureBound ? durationBound : captureBound;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _totalDistance = widget.baseOffset;
    _lastWrittenDistance = widget.baseOffset - 1; // ensure first write fires
    _windowStart = widget.startTime;
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    final hasPerms = await _pedometerService.requestPermissions();
    if (!hasPerms || !mounted) return;

    debugPrint(
      'DistanceMonitor: interval=${_checkIntervalSecs}s  '
      'noiseGate=${_noiseGateMeters.toStringAsFixed(1)}m  '
      'writeThreshold=${_writeThresholdMeters.toStringAsFixed(1)}m',
    );

    _timer = Timer.periodic(Duration(seconds: _checkIntervalSecs), (_) => _tick());
    _tick(); // immediate first check
  }

  /// One polling cycle:
  ///  1. Query pedometer for movement in [_windowStart, now].
  ///  2. Advance window so next tick starts fresh.
  ///  3. Discard if below noise gate (pocket shuffle filter).
  ///  4. Otherwise add to running total and write if threshold crossed.
  Future<void> _tick() async {
    if (widget.userId == null || !mounted) return;

    final now = DateTime.now();
    final windowEnd = now;

    double intervalDist = 0.0;
    try {
      intervalDist = await _pedometerService.getDistance(_windowStart, windowEnd);
    } catch (e) {
      debugPrint('DistanceMonitor: pedometer error: $e');
    }

    // Advance window BEFORE any early returns so the next tick always has a
    // fresh window even if this tick produced no qualifying movement.
    _windowStart = windowEnd;

    // ── Noise gate ──────────────────────────────────────────────────────────
    if (intervalDist < _noiseGateMeters) {
      debugPrint(
        'DistanceMonitor: interval=${intervalDist.toStringAsFixed(1)}m '
        '< gate=${_noiseGateMeters.toStringAsFixed(1)}m — discarded',
      );
      return; // pocket shuffle / minimal movement — don't count it
    }

    // ── Accumulate verified movement ────────────────────────────────────────
    if (mounted) {
      _totalDistance += intervalDist;
      ref.read(localDistanceProvider.notifier).update(_totalDistance);
      debugPrint(
        'DistanceMonitor: +${intervalDist.toStringAsFixed(1)}m  '
        'total=${_totalDistance.toStringAsFixed(1)}m',
      );
    }

    // ── Write threshold ─────────────────────────────────────────────────────
    final delta = (_totalDistance - _lastWrittenDistance).abs();
    if (delta >= _writeThresholdMeters) {
      debugPrint(
        'DistanceMonitor: writing ${_totalDistance.toStringAsFixed(1)}m '
        '(delta=${delta.toStringAsFixed(1)}m)',
      );
      await _updateFirestore(_totalDistance);
      _lastWrittenDistance = _totalDistance;
    }
  }

  Future<void> _updateFirestore(double dist) async {
    if (widget.userId == null || !mounted) return;
    await FirestoreService().updatePlayerDistance(
      widget.sessionId,
      widget.userId!,
      dist,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

