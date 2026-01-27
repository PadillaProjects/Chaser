import 'package:chaser/config/colors.dart';
import 'package:chaser/config/routes.dart';
import 'package:chaser/models/player_profile.dart';
import 'package:chaser/models/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
        title: Text(
          'HUNTER PROFILE',
          style: GoogleFonts.creepster(
            fontSize: 24,
            letterSpacing: 2,
            color: AppColors.ghostWhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.bloodRed),
            onPressed: () {
               ref.read(authServiceProvider).signOut();
            },
            tooltip: 'Flee',
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (userProfile) {
          if (userProfile == null) {
            return Center(
              child: Text(
                'Hunter profile not found.',
                style: GoogleFonts.jetBrainsMono(color: AppColors.textSecondary),
              ),
            );
          }

          if (!_isEditing && _nameController.text.isEmpty) {
             _nameController.text = userProfile.displayName;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bloodRed, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bloodRed.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.fogGrey,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.bloodRed,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                _isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
                              decoration: InputDecoration(
                                labelText: 'HUNTER NAME',
                                labelStyle: GoogleFonts.jetBrainsMono(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 2,
                                ),
                                filled: true,
                                fillColor: AppColors.fogGrey,
                                border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: AppColors.toxicGreen),
                            onPressed: () => _updateName(userProfile.displayName),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.bloodRed),
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
                            userProfile.displayName.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ghostWhite,
                              letterSpacing: 2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
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
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 32),

                // Level & XP Section
                playerProfileAsync.when(
                  data: (playerProfileData) {
                    final playerProfile = playerProfileData ?? PlayerProfile(
                        userId: userProfile.uid,
                        level: 1,
                        totalXP: 0,
                        totalCoins: 0,
                        totalDistance: 0,
                        totalGamesPlayed: 0,
                        createdAt: DateTime.now(),
                    );

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.fogGrey,
                        border: Border.all(color: AppColors.pulseBlue.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'LEVEL ${playerProfile.level}',
                            style: GoogleFonts.creepster(
                              fontSize: 32,
                              color: AppColors.pulseBlue,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(
                                  color: AppColors.pulseBlue.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.voidBlack,
                              border: Border.all(color: AppColors.pulseBlue.withOpacity(0.5)),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: playerProfile.currentLevelProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.pulseBlue,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.pulseBlue.withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${playerProfile.xpSinceCurrentLevelStart} / ${playerProfile.xpRequiredForNextLevel} XP',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 100),
                  error: (_,__) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // Stats Header
                Row(
                  children: [
                    Container(width: 4, height: 20, color: AppColors.bloodRed),
                    const SizedBox(width: 8),
                    Text(
                      'KILL STATISTICS',
                      style: GoogleFonts.creepster(
                        fontSize: 20,
                        color: AppColors.ghostWhite,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Grid
                playerProfileAsync.when(
                  data: (playerProfileData) {
                    final playerProfile = playerProfileData ?? PlayerProfile(
                        userId: userProfile.uid,
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
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard('HUNTS', '${playerProfile.totalGamesPlayed}', Icons.track_changes, AppColors.bloodRed),
                        _buildStatCard('VICTORIES', '${playerProfile.totalWins}', Icons.emoji_events, AppColors.warningYellow),
                        _buildStatCard('CAPTURES', '${playerProfile.totalCaptures}', Icons.gps_fixed, AppColors.bloodRed),
                        _buildStatCard('ESCAPES', '${playerProfile.totalEscapes}', Icons.directions_run, AppColors.pulseBlue),
                        _buildStatCard('DISTANCE', '${playerProfile.totalDistance.toStringAsFixed(0)}m', Icons.explore, AppColors.toxicGreen),
                        _buildStatCard('BOUNTY', '${playerProfile.totalCoins}', Icons.toll, AppColors.warningYellow),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                  error: (e, s) => Center(
                    child: Text(
                      'Error loading stats: $e',
                      style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed),
                    ),
                  ),
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fogGrey,
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ghostWhite,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
