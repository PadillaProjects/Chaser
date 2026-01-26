import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSession(sessionId);
});

final playersStreamProvider = StreamProvider.family((ref, String sessionId) {
  return FirestoreService().watchSessionPlayers(sessionId);
});

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStreamProvider(sessionId));
    final playersAsync = ref.watch(playersStreamProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Lobby'),
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                    Text('${session.gameMode} • ${session.durationDays} Days'),
                  ],
                ),
              ),
              
              const Divider(),
              
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
              
              // Action Button (Start Game - Owner only logic would go here)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Logic to start game
                  },
                  child: const Text('Start Game'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
