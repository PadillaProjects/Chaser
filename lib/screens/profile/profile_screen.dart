import 'package:chaser/config/routes.dart';
import 'package:chaser/models/player_profile.dart'; // New Import
import 'package:chaser/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Existing UserProfile Provider
final userProfileStreamProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  });
});

// New PlayerProfile Provider
final playerProfileStreamProvider = StreamProvider.autoDispose<PlayerProfile?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('player_profiles')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return PlayerProfile.fromFirestore(doc);
  });
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName(String currentName) async {
    if (_nameController.text.trim().isEmpty || _nameController.text.trim() == currentName) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    try {
      await ref.read(authServiceProvider).updateDisplayName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating name: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final playerProfileAsync = ref.watch(playerProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
               ref.read(authServiceProvider).signOut();
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) {
            return const Center(child: Text('User profile not found.'));
          }
          
          if (!_isEditing && _nameController.text.isEmpty) {
             _nameController.text = userProfile.displayName;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
                const SizedBox(height: 16),
                _isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Display Name'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: () => _updateName(userProfile.displayName),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                _nameController.text = userProfile.displayName;
                              });
                            },
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            userProfile.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                                _nameController.text = userProfile.displayName;
                              });
                            },
                          ),
                        ],
                      ),
                Text(
                  userProfile.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 24),
                // Level & XP
                playerProfileAsync.when(
                  data: (playerProfileData) {
                    // Default profile if null
                    final playerProfile = playerProfileData ?? PlayerProfile(
                        userId: userProfile.uid,
                        level: 1,
                        totalXP: 0,
                        totalCoins: 0,
                        totalDistance: 0,
                        totalGamesPlayed: 0,
                        createdAt: DateTime.now(),
                    );
                    
                    return Column(
                      children: [
                        Text('Level ${playerProfile.level}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        )),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: LinearProgressIndicator(
                            value: playerProfile.currentLevelProgress, 
                            minHeight: 12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playerProfile.xpSinceCurrentLevelStart} / ${playerProfile.xpRequiredForNextLevel} XP',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  }, 
                  loading: () => const SizedBox(height: 50),
                  error: (_,__) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                
                // Stats Display
                playerProfileAsync.when(
                  data: (playerProfileData) {
                    // Default profile if null
                    final playerProfile = playerProfileData ?? PlayerProfile(
                        userId: userProfile.uid, // Use auth uid
                        level: 1,
                        totalXP: 0,
                        totalCoins: 0,
                        totalDistance: 0,
                        totalGamesPlayed: 0,
                        createdAt: DateTime.now(),
                    );
                    
                     return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('Total Games', '${playerProfile.totalGamesPlayed}', Icons.games),
                        _buildStatCard('Wins', '${playerProfile.totalWins}', Icons.emoji_events),
                        _buildStatCard('Captures', '${playerProfile.totalCaptures}', Icons.handshake),
                         _buildStatCard('Escapes', '${playerProfile.totalEscapes}', Icons.run_circle_outlined),
                        _buildStatCard('Distance', '${playerProfile.totalDistance.toStringAsFixed(1)} m', Icons.directions_run),
                        _buildStatCard('Coins', '${playerProfile.totalCoins}', Icons.monetization_on),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error loading stats: $e')),
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
