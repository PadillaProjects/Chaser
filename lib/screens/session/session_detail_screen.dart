import 'dart:async';
import 'package:chaser/models/player.dart';
import 'package:chaser/models/player_profile.dart'; // Added
import 'package:chaser/models/session.dart';
import 'package:chaser/screens/session/edit_session_sheet.dart';
import 'package:chaser/services/pedometer_service.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaser/models/user_profile.dart'; 
import 'package:go_router/go_router.dart';
import 'package:chaser/screens/session/game_results_view.dart';


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
        title: const Text('Leave Game?'),
        content: const Text('Are you sure you want to leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
        actions: [
          sessionAsync.when(
            data: (session) {
              final isOwner = session.ownerId == currentUser?.uid;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      tooltip: 'Leave Game',
                      onPressed: _leaveSession,
                    ),
                  if (isOwner && session.status == 'pending')
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (session) {
          if (session.status == 'completed' && _showResults && session.results != null) {
              return GameResultsView(
                  session: session,
                  currentUserId: currentUser?.uid ?? '',
                  onDismiss: () => setState(() => _showResults = false),
              );
          }

          return Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Column(
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(session.status.toUpperCase()),
                          backgroundColor: session.status == 'active' 
                              ? Colors.green[100] 
                              : Colors.orange[100],
                        ),
                        if (session.status == 'active' && _isheadstartActive(session))
                             Chip(
                                avatar: const Icon(Icons.timer, size: 16),
                                label: _HeadstartTimer(
                                    endTime: (session.actualStartTime?.toDate() ?? 
                                             session.scheduledStartTime?.toDate() ?? 
                                             DateTime.now())
                                            .add(Duration(minutes: session.headstartDuration)),
                                ),
                                backgroundColor: Colors.amber[100],
                            ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${session.gameMode} • ${session.durationDays} Days • ${session.visibility.toUpperCase()}'),
                    if (session.status == 'pending' && session.joinCode != null) ...[
                       const SizedBox(height: 12),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         decoration: BoxDecoration(
                           color: Theme.of(context).colorScheme.primary,
                           borderRadius: BorderRadius.circular(16),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Text('CODE: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             Text(session.joinCode!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                           ],
                         ),
                       ),
                    ],
                     const SizedBox(height: 8),
                    Text('${session.memberCount} / ${session.maxMembers} Players'),
                  ],
                ),
              ),
              
              const Divider(height: 1),

              // Game Rules Summary
              ExpansionTile(
                title: const Text('Game Rules'),
                leading: const Icon(Icons.info_outline),
                children: [
                   ListTile(
                    dense: true,
                    title: Text('Headstart: ${session.headstartDistance}m (${session.headstartDuration} min)'),
                    leading: const Icon(Icons.run_circle_outlined),
                  ),
                  if (session.restStartHour != session.restEndHour)
                    ListTile(
                      dense: true,
                      title: Text('Rest Hours: ${session.restStartHour}:00 - ${session.restEndHour}:00'),
                      leading: const Icon(Icons.bedtime_outlined),
                    ),
                  ListTile(
                    dense: true,
                    title: Text('Capture: ${session.instantCapture ? "Instant" : "Resist ${session.captureResistanceDuration}min"}'),
                    leading: const Icon(Icons.touch_app_outlined),
                  ),
                  if (session.gameMode == 'target')
                    ListTile(
                      dense: true,
                      title: Text('Switch Cooldown: ${session.switchCooldown} min'),
                      leading: const Icon(Icons.swap_horiz),
                    ),
                  if (session.visibility == 'private' && session.password != null)
                     const ListTile(
                      dense: true,
                      title: Text('Password Protected'),
                      leading: Icon(Icons.lock),
                    ),
                ],
              ),
              const Divider(height: 1),
              
              // Players List
              Expanded(
                child: playersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e,s) => Center(child: Text('Error loading players: $e')),
                  data: (players) {
                    if (players.isEmpty) return const Center(child: Text('No players yet'));
                    
                    final myPlayer = players.where((p) => p.userId == currentUser?.uid).firstOrNull;
                    final showCaptureWarning = myPlayer?.captureState == 'being_chased' && myPlayer?.captureDeadline != null;

                    // Check if I am a chaser and any runner is being chased
                    final isChaser = myPlayer?.role == 'chaser';
                    final victims = players.where((p) => p.role == 'runner' && p.captureState == 'being_chased' && p.captureDeadline != null).toList();
                    final showChaserStatus = isChaser && victims.isNotEmpty;

                    return Stack(
                      children: [
                        // Game Loop Monitor: Runs logic for everyone if needed
                        _GameLoopMonitor(
                          sessionId: widget.sessionId,
                          players: players,
                        ),
                        // Distance Monitor: Tracks distance for current user
                        if (session.status == 'active' && 
                            // Only track if game has started
                            (session.actualStartTime != null || session.scheduledStartTime != null))
                          _DistanceMonitor(
                            sessionId: widget.sessionId,
                            userId: currentUser?.uid,
                            startTime: session.actualStartTime?.toDate() ?? session.scheduledStartTime?.toDate() ?? DateTime.now(),
                            baseOffset: (myPlayer?.role == 'runner') ? session.headstartDistance : 0.0,
                          ),
                        Column(
                          children: [
                            if (showCaptureWarning) 

                              Container(
                                color: Colors.red.withOpacity(0.1),
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Capture Imminent!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                          const Text('Escape by increasing your distance!', style: TextStyle(fontSize: 12)),
                                          const SizedBox(height: 4),
                                          _CaptureTimer(
                                              endTime: myPlayer!.captureDeadline!.toDate(),
                                              onExpired: () => FirestoreService().triggerCaptureCheck(widget.sessionId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                             if (showChaserStatus)
                               _ChaserCaptureStatus(
                                 victims: victims,
                                 sessionId: widget.sessionId,
                               ),
                            Expanded(
                              child: ListView.builder(
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              if (session.ownerId == currentUser?.uid && session.status == 'active') ...[
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: ElevatedButton.icon(
                     onPressed: () => _stopGame(session.id),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                     icon: const Icon(Icons.stop),
                     label: const Text('Stop Game'),
                   ),
                 )
              ] else if (session.ownerId == currentUser?.uid && session.status == 'pending') ...[
                 Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Schedule option
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Schedule Start'),
                        subtitle: Text(session.scheduledStartTime == null 
                            ? 'Not scheduled' 
                            : 'Scheduled for: ${session.scheduledStartTime!.toDate().toString().split('.')[0]}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (session.scheduledStartTime != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearScheduledTime,
                              ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month),
                              onPressed: () => _pickScheduledTime(session.scheduledStartTime),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _startGame(session),
                        child: const Text('Start Game Now'),
                      ),
                    ],
                  ),
                )
              ] else if (session.ownerId == currentUser?.uid && session.status == 'completed') ...[
                  Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                           ElevatedButton.icon(
                             onPressed: () => _resetGame(session.id),
                             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                             icon: const Icon(Icons.refresh),
                             label: const Text('Reset Game'),
                           ),
                           const SizedBox(height: 8),
                           OutlinedButton(
                                onPressed: () => setState(() => _showResults = true),
                                child: const Text('View Results'),
                            ),
                       ],
                   ),
                 )

              ] else if (session.status == 'completed') ...[
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Center(
                     child: Column(
                        children: [
                            const Text('Game Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                                onPressed: () => setState(() => _showResults = true),
                                child: const Text('View Results'),
                            ),
                        ],
                     ),
                   ),
                 ),
              ] else 
                Padding(

                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      session.status == 'active' ? 'Game in progress' : 
                      session.status == 'completed' ? 'Game Completed' :
                      'Waiting for host to start...',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startGame(SessionModel session) async {
    try {
      await _firestoreService.startGame(widget.sessionId, session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game Started!')),
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
        title: const Text('Stop Game?'),
        content: const Text('Are you sure you want to stop this game? This will calculate results and end the session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Stop Game'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
        try {
            await _firestoreService.stopGame(sessionId);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Game Stopped!')),
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
        title: const Text('Reset Game?'),
        content: const Text('This will reset the game to pending state. All players will remain in the lobby.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
         try {
            await _firestoreService.resetGame(sessionId);
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Game Reset!')),
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
    // Prefer actualStartTime if game started, fall back to scheduled if just checking preview (though this method is mostly for active state)
    final start = session.actualStartTime?.toDate() ?? session.scheduledStartTime?.toDate();
    if (start == null) return false;
    
    final end = start.add(Duration(minutes: session.headstartDuration));
    return DateTime.now().isBefore(end);
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

    // Determine effective distance to show
    double effectiveDistance = currentDistance;
    if (isMe && localDist != null) {
        effectiveDistance = localDist;
    }
    
    return userProfileAsync.when(
      data: (user) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase()) : null,
          ),
          title: Text(user.displayName),
          subtitle: Row(
            children: [
                Text(role),
                if (effectiveDistance >= 0) ...[
                    const SizedBox(width: 8),
                    Container(width: 1, height: 12, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('${effectiveDistance.toStringAsFixed(0)}m', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]
            ],
          ),
          trailing: isOwner 
              ? const Icon(Icons.star, color: Colors.amber) 
              : const Icon(Icons.info_outline, color: Colors.grey),
          onTap: () => _showPlayerStats(context, ref, user.displayName),
        );
      },
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('Loading...'),
      ),
      error: (_, __) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: Text('Unknown User ($userId)'),
      ),
    );
  }

  Future<void> _showPlayerStats(BuildContext context, WidgetRef ref, String displayName) async {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: Text('$displayName\'s Stats'),
            content: Consumer(
                builder: (context, ref, child) {
                    final otherPlayerStats = ref.watch(otherPlayerProfileFamily(userId));
                    final sessionPlayersAsync = ref.watch(playersStreamProvider(sessionId));
                    
                    // Get live session data for this player
                    final livePlayer = sessionPlayersAsync.asData?.value
                        .where((p) => p.userId == userId)
                        .firstOrNull;
                    final liveDistance = livePlayer?.currentDistance ?? 0.0;
                    
                    return otherPlayerStats.when(
                        data: (stats) {
                            if (stats == null) return const Text('No stats available.');
                            return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text('Level: ${stats.level}'),
                                    const SizedBox(height: 8),
                                    Text('Games Played: ${stats.totalGamesPlayed}'),
                                    Text('Wins: ${stats.totalWins}'),
                                    Text('Captures: ${stats.totalCaptures}'),
                                    Text('Escapes: ${stats.totalEscapes}'),
                                    const SizedBox(height: 8),
                                    Text('Total Distance: ${stats.totalDistance.toStringAsFixed(1)}m'),
                                    const Divider(),
                                    const Text('Debug Distance:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Current: ${liveDistance.toStringAsFixed(1)}m'),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () => _updateDistance(liveDistance, -1.0),
                                          tooltip: '-1m',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () => _updateDistance(liveDistance, 1.0),
                                          tooltip: '+1m',
                                        ),
                                        TextButton(
                                          onPressed: () => _setDistanceDialog(context, liveDistance),
                                          child: const Text('Set'),
                                        ),
                                      ],
                                    ),
                                ],
                            );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e,s) => Text('Error: $e'),
                    );
                }
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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
              title: const Text('Set Distance'),
              content: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Distance (meters)'),
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                  ),
                  FilledButton(
                      onPressed: () async {
                          final val = double.tryParse(controller.text);
                          if (val != null) {
                              await FirestoreService().updatePlayerDistance(sessionId, userId, val);
                              if (context.mounted) Navigator.pop(context);
                          }
                      },
                      child: const Text('Save'),
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
                    return const Text('Started!');
                }
                
                final m = remaining.inMinutes;
                final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                
                return Text('Release in $m:$s');
            }
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
                        // Schedule callback for next frame to avoid build-time side effects
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           widget.onExpired?.call();
                        });
                    }
                    return const Text('Capturing...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                }
                
                // Reset trigger if we go back to positive (e.g. deadline extended? unlikely but safe)
                // _expiredTriggered = false; 

                final m = remaining.inMinutes;
                final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                
                return Text(
                    'Time remaining: $m:$s', 
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)
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
    // Check every 2 seconds
    _monitorTimer = Timer.periodic(const Duration(seconds: 2), _checkDeadlines);
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeadlines(Timer t) async {
    if (_isTriggering) return; // Debounce

    final now = DateTime.now();
    bool needsTrigger = false;

    // Check if ANY runner has an expired deadline
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
    return const SizedBox.shrink(); // Invisible widget
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

      // For simplicity, display the first victim found (or format list)
      final victim = victims.first;
      final userProfileAsync = ref.watch(userProfileFamily(victim.userId));
      
      return Container(
        color: Colors.green.withOpacity(0.1),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.track_changes, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userProfileAsync.when(
                    data: (profile) => Text(
                        'You are capturing ${profile?.displayName ?? 'Runner'}!', 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    ),
                    loading: () => const Text('You are capturing...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    error: (_,__) => const Text('You are capturing...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  const Text("Don't let them escape!", style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
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
  final String? userId; // Nullable to handle loading/auth states gracefully
  final DateTime startTime;
  final double baseOffset;

  const _DistanceMonitor({
    required this.sessionId,
    required this.userId,
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
  StreamSubscription? _subscription;
  bool _hasPermissions = false;
  
  double _currentTotalDistance = 0.0;
  double _lastStoredDistance = -20.0; // Init to allow first write (0 - (-20) > 10)

  @override
  void initState() {
    super.initState();
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    _hasPermissions = await _pedometerService.requestPermissions();
    if (_hasPermissions && mounted) {
      // 1. Start Stream for live local updates (no write)
      _subscription = _pedometerService.getPedometerStream(widget.startTime).listen((data) {
          try {
             final dynamic distVal = data.distance;
             if (distVal != null && distVal is num) {
                 final double pedometerDist = distVal.toDouble();
                 if (mounted) {
                   final total = widget.baseOffset + pedometerDist;
                   setState(() {
                     _currentTotalDistance = total;
                   });
                   // Update provider for optimistic UI
                   ref.read(localDistanceProvider.notifier).update(total);
                 }
                 // debugPrint("DistanceMonitor: Stream Update - Local Total: $_currentTotalDistance");
             }
          } catch (e) {
             debugPrint("DistanceMonitor: Stream Processing Error: $e");
          }
      }, onError: (e) {
          debugPrint("DistanceMonitor: Stream Error: $e");
      });

      // 2. Periodic timer checks for significant changes to write
      _timer = Timer.periodic(const Duration(seconds: 10), _checkAndWriteDistance);
      
      // Initial check
      _checkAndWriteDistance(null);
    }
  }

  Future<void> _checkAndWriteDistance(Timer? t) async {
    if (widget.userId == null) return;
    
    // 1. Poll to ensure we have the absolute latest (sync with stream)
    try {
        final double pedometerDist = await _pedometerService.getDistance(widget.startTime, DateTime.now());
        if (mounted) {
           _currentTotalDistance = widget.baseOffset + pedometerDist;
        }
    } catch (e) {
        debugPrint("DistanceMonitor: Poll Error: $e");
    }

    // 2. Check threshold
    final double diff = (_currentTotalDistance - _lastStoredDistance).abs();
    
    if (diff > 10.0) {
        debugPrint("DistanceMonitor: Threshold met (Diff: ${diff.toStringAsFixed(1)}m). Writing: ${_currentTotalDistance.toStringAsFixed(1)}m");
        await _updateFirestore(_currentTotalDistance);
        _lastStoredDistance = _currentTotalDistance;
    } else {
        // debugPrint("DistanceMonitor: Threshold not met (Diff: ${diff.toStringAsFixed(1)}m). Skipping write.");
    }
  }

  Future<void> _updateFirestore(double dist) async {
    if (widget.userId == null || !mounted) return;
    await FirestoreService().updatePlayerDistance(widget.sessionId, widget.userId!, dist);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); 
  }
}
