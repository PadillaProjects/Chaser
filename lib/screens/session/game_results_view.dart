import 'package:chaser/models/player_profile.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/services/firebase/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class GameResultsView extends ConsumerStatefulWidget {
  final SessionModel session;
  final String currentUserId;
  final VoidCallback onDismiss;

  const GameResultsView({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.onDismiss,
  });

  @override
  ConsumerState<GameResultsView> createState() => _GameResultsViewState();
}

class _GameResultsViewState extends ConsumerState<GameResultsView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xpAnimation;
  
  // Results Data extraction
  Map<String, dynamic>? get _myResult => widget.session.results?['player_results']?[widget.currentUserId];
  String get _winnerRole => widget.session.results?['winner_role'] ?? 'none';
  bool get _didIWin => _myResult?['outcome'] == 'won';
  int get _xpEarned => _myResult?['xp_earned'] ?? 0;
  int get _oldLevel => _myResult?['old_level'] ?? 1;
  int get _newLevel => _myResult?['new_level'] ?? 1;
  int get _oldXP => _myResult?['old_xp'] ?? 0; // Wait, I didn't save old XP in logic! I saved old Level. 
  // Ah, I only saved 'old_level' and 'new_level'. 
  // And the profile has the 'current' (new) total XP.
  // I should rely on what I have. 'old_xp' key in my logic was missing?
  // Let's check logic:
  // playerResults[p.userId] = { ... 'old_level': profile.level, ... };
  // I did NOT save 'old_xp_total'. I can infer defaults or just animate "level bar".
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _xpAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunnerWin = _winnerRole == 'runner';
    final isChaserWin = _winnerRole == 'chaser';
    final isNeutral = _winnerRole == 'none';
    
    Color bannerColor = Colors.grey;
    IconData bannerIcon = Icons.flag;
    String bannerText = "GAME OVER";
    
    if (isRunnerWin) {
        bannerColor = Colors.green;
        bannerIcon = Icons.directions_run;
        bannerText = "RUNNERS WIN!";
    } else if (isChaserWin) {
        bannerColor = Colors.red;
        bannerIcon = Icons.gps_fixed;
        bannerText = "CHASERS WIN!";
    } else {
        // Stopped / Neutral
        bannerColor = Colors.blueGrey;
        bannerIcon = Icons.stop_circle_outlined;
        bannerText = "GAME STOPPED";
    }

    String resultText = "DEFEAT";
    Color resultColor = Colors.red[700]!;
    
    if (_didIWin) {
        resultText = "VICTORY";
        resultColor = Colors.green[700]!;
    } else if (isNeutral) {
        resultText = "ENDED";
        resultColor = Colors.blueGrey[700]!;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // Banner
            Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                    color: bannerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: bannerColor, width: 2),
                ),
                child: Column(
                    children: [
                        Icon(bannerIcon, size: 64, color: bannerColor),
                        const SizedBox(height: 16),
                        Text(bannerText, style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: bannerColor,
                        )),
                        const SizedBox(height: 8),
                         Text(
                             resultText, 
                             style: theme.textTheme.titleMedium?.copyWith(
                                 fontWeight: FontWeight.bold,
                                 color: resultColor,
                             )
                         ),
                    ],
                ),
            ),
            
            const SizedBox(height: 32),
            
            // Stats Card
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text('Rewards', style: theme.textTheme.titleLarge),
                            const Divider(),
                            
                            // Points Breakdown
                            if (_myResult?['breakdown'] != null) ...[
                                ...(_myResult!['breakdown'] as Map<String, dynamic>).entries.map((e) {
                                    String label = e.key.replaceAll('_', ' ').toUpperCase();
                                    String value = e.value.toString();
                                    // Formatting
                                    if(e.value is double) value = (e.value as double).toStringAsFixed(1);
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                      child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                              Text(label, style: const TextStyle(color: Colors.grey)),
                                              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                      ),
                                    );
                                }),
                                const Divider(),
                            ],

                            // XP Earned
                            ListTile(
                                leading: const Icon(Icons.star, color: Colors.amber),
                                title: const Text('XP Earned'),
                                subtitle: Text('${_myResult?['session_points'] ?? 0} Pts ÷ 10'),
                                trailing: Text('+${_xpEarned} XP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber)),
                            ),
                            const SizedBox(height: 16),
                            
                            // Level Progress
                            Text('Level Progress', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            _buildLevelProgress(theme),
                        ],
                    ),
                ),
            ),
            
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: widget.onDismiss,
                child: const Text('Close Results'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLevelProgress(ThemeData theme) {
      // Calculate Thresholds
      int currentLevel = _newLevel;
      
      // Use static helper to get previous cumulative XP
      int startXP = PlayerProfile.cumulativeXpForLevel(currentLevel);
      
      // XP needed for THIS level only
      int xpNeeded = (100 * pow(1.1, currentLevel - 1)).round();
      
      // Current Total XP from results
      int currentTotalXP = _myResult?['new_total_xp'] ?? 0;
      
      // XP acquired strictly within this level
      int xpInLevel = currentTotalXP - startXP;
      if (xpInLevel < 0) xpInLevel = 0;
      
      // Calculate Progress
      double progress = 0.0;
      if (xpNeeded > 0) {
          progress = xpInLevel / xpNeeded;
          if (progress > 1.0) progress = 1.0;
      }

      if (_newLevel > _oldLevel) {
          // Level Up Case
          return Column(
              children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          Text('Level $_oldLevel'),
                          const Icon(Icons.arrow_forward),
                          Text('Level $_newLevel', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                      animation: _xpAnimation,
                      builder: (context, child) {
                          // Animation: 0 -> Calculated Progress (or 100% then reset? For now just fill up)
                          // If leveled up, we effectively went 100% on old level -> X% on new level.
                          // Simplified: Just show the NEW level status filling up.
                          return LinearProgressIndicator(
                               value: _xpAnimation.value * progress, // Animate up to current progress
                              backgroundColor: Colors.grey[200],
                              color: Colors.amber,
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                          );
                      },
                  ),
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('$xpInLevel / $xpNeeded XP', style: theme.textTheme.bodySmall),
                  ),
                  if (_controller.isCompleted)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('LEVEL UP!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ),
              ],
          );
      } else {
          // Normal Case
          return Column(
              children: [
                 Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          Text('Level $_newLevel'),
                          Text('$xpInLevel / $xpNeeded XP', style: theme.textTheme.bodySmall), 
                      ],
                  ),
                  const SizedBox(height: 8),
                   AnimatedBuilder(
                      animation: _xpAnimation,
                      builder: (context, child) {
                          return LinearProgressIndicator(
                              value: _xpAnimation.value * progress, // Animate from 0 to current
                              backgroundColor: Colors.grey[200],
                              color: Colors.blue,
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                          );
                      },
                  ),
              ],
          );
      }
  }
}
