import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final publicSessionsProvider = StreamProvider((ref) {
  return FirestoreService().watchPublicSessions();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(publicSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No active games found.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/create-session'),
                    child: const Text('Create New Game'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                child: ListTile(
                  title: Text(session.name),
                  subtitle: Text('${session.memberCount} Players • ${session.gameMode}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    // Quick Join Logic
                    final auth = AuthService();
                    if (auth.currentUser != null) {
                      await FirestoreService().joinSession(
                        session.id, 
                        auth.currentUser!.uid,
                      );
                      if (context.mounted) {
                        context.push('/session/${session.id}');
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-session'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
