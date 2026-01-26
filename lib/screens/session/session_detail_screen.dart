import 'package:chaser/screens/session/edit_session_sheet.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final sessionStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSession(sessionId);
});

final playersStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSessionPlayers(sessionId);
});

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _firestoreService = FirestoreService();

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
                  if (isOwner)
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
                    Chip(
                      label: Text(session.status.toUpperCase()),
                      backgroundColor: session.status == 'active' 
                          ? Colors.green[100] 
                          : Colors.orange[100],
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
                  error: (err, _) => Center(child: Text('$err')),
                  data: (players) {
                    if (players.isEmpty) return const Center(child: Text('No players yet'));
                    
                    return ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(player.role[0].toUpperCase()),
                          ),
                          title: Text(player.userId), // Pending: Fetch user name
                          subtitle: Text(player.role),
                          trailing: player.isOwner 
                              ? const Icon(Icons.star, color: Colors.amber) 
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              
              // Scheduled Start & Start Button (Owner Only)
              if (session.ownerId == currentUser?.uid && session.status == 'pending')
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
                        onPressed: () {
                          // Logic to start game
                        },
                        child: const Text('Start Game Now'),
                      ),
                    ],
                  ),
                )
              else 
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      session.status == 'active' ? 'Game in progress' : 'Waiting for host to start...',
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
}
