import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import 'package:firebase_auth/firebase_auth.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});

final userSessionsProvider = StreamProvider((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null) return const Stream<List<SessionModel>>.empty();
  return FirestoreService().watchUserSessions(user.uid);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
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
                  const Text('You have no active games.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/create-session'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Game'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showJoinDialog(context),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Join with Code'),
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
                  onTap: () => context.push('/session/${session.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: () => _showJoinDialog(context),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: () => context.push('/create-session'),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeController = TextEditingController();
    
    final joined = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Game'),
        content: TextField(
          controller: codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: '4-Digit Code',
            hintText: 'e.g. 1234',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 4) return;
              
              Navigator.pop(context, true); // Pop dialog first
              
              try {
                final user = AuthService().currentUser;
                if (user != null) {
                  await FirestoreService().joinSessionByCode(code, user.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Joined!')),
                    );
                    // No need to nav, stream will update list
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
