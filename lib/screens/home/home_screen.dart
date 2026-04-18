import 'package:chaser/config/colors.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:chaser/services/pedometer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chaser/providers/user_provider.dart';
import 'package:chaser/models/player_profile.dart';

/// Live member count for a session — watches the real session_members
/// collection so the home screen updates when anyone joins or leaves.
final sessionMemberCountProvider = StreamProvider.family<int, String>((ref, sessionId) {
  return FirestoreService().watchSessionPlayers(sessionId).map((players) => players.length);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _statsTabController;

  @override
  void initState() {
    super.initState();
    _statsTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _statsTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final playerProfileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'CHASER',
          style: GoogleFonts.specialElite(
            fontSize: 28,
            letterSpacing: 4,
            color: AppColors.bloodRed,
            shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textMuted),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- TOP HALF: STATS ---
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.voidBlack,
                border: Border(
                  bottom: BorderSide(color: AppColors.bloodRed.withOpacity(0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bloodRed.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: playerProfileAsync.when(
                data: (playerProfileData) {
                  final profile = playerProfileData ??
                      PlayerProfile(
                        userId: '',
                        totalCoins: 0,
                        totalCoinsEarned: 0,
                        totalCoinsSpent: 0,
                        totalDistance: 0,
                        totalGamesPlayed: 0,
                        totalWins: 0,
                        totalLosses: 0,
                        totalCaptures: 0,
                        totalEscapes: 0,
                        totalTimesCaptured: 0,
                        createdAt: DateTime.now(),
                      );

                  // Derived stats
                  final winRate = profile.totalGamesPlayed > 0
                      ? (profile.totalWins / profile.totalGamesPlayed * 100)
                          .toStringAsFixed(0)
                      : '0';
                  final captureRate = profile.totalGamesPlayed > 0
                      ? (profile.totalCaptures /
                              profile.totalGamesPlayed)
                          .toStringAsFixed(1)
                      : '0';

                  return Column(
                    children: [
                      // Tab bar label
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Text(
                          'PLAYER STATS',
                          style: GoogleFonts.specialElite(
                            fontSize: 16,
                            color: AppColors.ghostWhite,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // Category tabs
                      TabBar(
                        controller: _statsTabController,
                        labelColor: AppColors.bloodRed,
                        unselectedLabelColor: AppColors.textMuted,
                        indicatorColor: AppColors.bloodRed,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: Colors.transparent,
                        labelStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        unselectedLabelStyle:
                            GoogleFonts.jetBrainsMono(fontSize: 11, letterSpacing: 1),
                        tabs: const [
                          Tab(text: 'OVERALL'),
                          Tab(text: 'CHASER'),
                          Tab(text: 'RUNNER'),
                        ],
                      ),
                      // Stats panels
                      Expanded(
                        child: TabBarView(
                          controller: _statsTabController,
                          children: [
                            // — OVERALL —
                            _buildStatRow([
                              _StatCell('GAMES', '${profile.totalGamesPlayed}', Icons.sports_kabaddi, AppColors.ghostWhite),
                              _StatCell('WINS', '${profile.totalWins}', Icons.emoji_events, AppColors.warningYellow),
                              _StatCell('WIN %', '$winRate%', Icons.percent, AppColors.toxicGreen),
                              _StatCell('DISTANCE', '${profile.totalDistance.toStringAsFixed(0)}m', Icons.explore, AppColors.pulseBlue),
                            ]),
                            // — CHASER —
                            _buildStatRow([
                              _StatCell('CAPTURES', '${profile.totalCaptures}', Icons.gps_fixed, AppColors.bloodRed),
                              _StatCell('AVG/GAME', captureRate, Icons.trending_up, AppColors.warningYellow),
                              _StatCell('LOSSES', '${profile.totalLosses}', Icons.close, AppColors.textMuted),
                              _StatCell('DISTANCE', '${profile.totalDistance.toStringAsFixed(0)}m', Icons.directions_run, AppColors.toxicGreen),
                            ]),
                            // — RUNNER —
                            _buildStatRow([
                              _StatCell('ESCAPES', '${profile.totalEscapes}', Icons.directions_run, AppColors.pulseBlue),
                              _StatCell('CAPTURED', '${profile.totalTimesCaptured}', Icons.lock, AppColors.bloodRed),
                              _StatCell('WINS', '${profile.totalWins}', Icons.shield, AppColors.toxicGreen),
                              _StatCell('DISTANCE', '${profile.totalDistance.toStringAsFixed(0)}m', Icons.explore, AppColors.warningYellow),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                error: (e, _) =>
                    Center(child: Icon(Icons.error, color: AppColors.bloodRed)),
              ),
            ),
          ),

          // --- BOTTOM HALF: SESSIONS ---
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Section Header
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.fogGrey,
                  child: Row(
                    children: [
                      Icon(Icons.radar, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE GAMES',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: sessionsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.bloodRed),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error: $err',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.bloodRed),
                      ),
                    ),
                    data: (sessions) {
                      if (sessions.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_off,
                                size: 48,
                                color: AppColors.textMuted.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "IT'S QUIET AROUND HERE...",
                                style: GoogleFonts.specialElite(
                                  color: AppColors.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton(
                                onPressed: () => context.push('/create-session'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(color: AppColors.textSecondary),
                                ),
                                child: const Text('NEW GAME'),
                              ),
                            ],
                          ),
                        );
                      }

                          return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isActive = session.status == 'active';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.fogGrey,
                              border: Border(
                                left: BorderSide(
                                  color: isActive
                                      ? AppColors.bloodRed
                                      : AppColors.textMuted,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Text(
                                session.name.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ghostWhite,
                                  letterSpacing: 1,
                                ),
                              ),
                              subtitle: Consumer(
                                builder: (context, ref, _) {
                                  final countAsync = ref.watch(sessionMemberCountProvider(session.id));
                                  final count = countAsync.value ?? session.memberCount;
                                  return Text(
                                    '$count Players • ${isActive ? 'IN PROGRESS' : 'WAITING'}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      color: isActive
                                          ? AppColors.bloodRed
                                          : AppColors.textSecondary,
                                    ),
                                  );
                                },
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color:
                                    isActive ? AppColors.bloodRed : AppColors.textMuted,
                              ),
                              onTap: () => context.push('/session/${session.id}'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.pulseBlue.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'join',
              onPressed: () => _showJoinDialog(context),
              backgroundColor: AppColors.fogGrey,
              foregroundColor: AppColors.pulseBlue,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: const Icon(Icons.login),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.bloodRed.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'create',
              onPressed: () => context.push('/create-session'),
              backgroundColor: AppColors.bloodRed,
              foregroundColor: AppColors.ghostWhite,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row of 4 stat cells with equal spacing.
  Widget _buildStatRow(List<_StatCell> cells) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cells
            .map(
              (c) => Expanded(
                child: _buildMiniStat(c.label, c.value, c.icon, c.color),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMiniStat(
      String title, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.ghostWhite,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'ENTER',
          style: GoogleFonts.specialElite(
            fontSize: 24,
            color: AppColors.ghostWhite,
          ),
        ),
        content: TextField(
          controller: codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.ghostWhite,
            fontSize: 24,
            letterSpacing: 8,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: 'ACCESS CODE',
            labelStyle: GoogleFonts.jetBrainsMono(
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
            hintText: '0000',
            hintStyle: GoogleFonts.jetBrainsMono(
              color: AppColors.textMuted,
              fontSize: 24,
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: AppColors.voidBlack,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.textMuted),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
            ),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ABORT',
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 4) return;

              Navigator.pop(context, true);

              try {
                final user = AuthService().currentUser;
                if (user != null) {
                  await FirestoreService().joinSessionByCode(code, user.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You have entered the zone.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Access denied: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.bloodRed,
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(
              'ENTER',
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple data carrier for a stat cell.
class _StatCell {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCell(this.label, this.value, this.icon, this.color);
}
