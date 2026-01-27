import 'package:chaser/config/colors.dart';
import 'package:chaser/models/player_profile.dart';
import 'package:chaser/models/session.dart';
import 'package:chaser/screens/session/session_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Map<String, dynamic>? get _myResult => widget.session.results?['player_results']?[widget.currentUserId];
  String get _winnerRole => widget.session.results?['winner_role'] ?? 'none';
  bool get _didIWin => _myResult?['outcome'] == 'won';
  int get _xpEarned => _myResult?['xp_earned'] ?? 0;
  int get _oldLevel => _myResult?['old_level'] ?? 1;
  int get _newLevel => _myResult?['new_level'] ?? 1;

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
    final isRunnerWin = _winnerRole == 'runner';
    final isChaserWin = _winnerRole == 'chaser';
    final isNeutral = _winnerRole == 'none';

    Color bannerColor = AppColors.textMuted;
    IconData bannerIcon = Icons.flag;
    String bannerText = 'THE HUNT ENDED';
    String bannerSubtext = 'No clear victor.';

    if (isRunnerWin) {
      bannerColor = AppColors.pulseBlue;
      bannerIcon = Icons.directions_run;
      bannerText = 'RUNNERS SURVIVED';
      bannerSubtext = 'The prey escaped the hunt.';
    } else if (isChaserWin) {
      bannerColor = AppColors.bloodRed;
      bannerIcon = Icons.gps_fixed;
      bannerText = 'CHASERS DOMINATED';
      bannerSubtext = 'All prey have been captured.';
    }

    String resultText = 'DEFEAT';
    Color resultColor = AppColors.bloodRed;
    String resultSubtext = isChaserWin ? 'You were captured.' : 'The prey escaped.';

    if (_didIWin) {
      resultText = 'VICTORY';
      resultColor = AppColors.toxicGreen;
      resultSubtext = isRunnerWin ? 'You survived the hunt.' : 'You captured your prey.';
    } else if (isNeutral) {
      resultText = 'ENDED';
      resultColor = AppColors.textSecondary;
      resultSubtext = 'The hunt was stopped.';
    }

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Banner
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bannerColor.withOpacity(0.3),
                      AppColors.voidBlack,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bannerColor.withOpacity(0.2),
                        border: Border.all(color: bannerColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: bannerColor.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        bannerIcon,
                        size: 64,
                        color: bannerColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      bannerText,
                      style: GoogleFonts.creepster(
                        fontSize: 32,
                        color: bannerColor,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: bannerColor.withOpacity(0.8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bannerSubtext,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Personal Result Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.fogGrey,
                  border: Border(
                    left: BorderSide(
                      color: resultColor,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _didIWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                      size: 32,
                      color: _didIWin ? AppColors.warningYellow : AppColors.bloodRed,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resultText,
                            style: GoogleFonts.creepster(
                              fontSize: 24,
                              color: resultColor,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            resultSubtext,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Rewards Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(width: 4, height: 16, color: AppColors.pulseBlue),
                    const SizedBox(width: 8),
                    Text(
                      'REWARDS',
                      style: GoogleFonts.creepster(
                        fontSize: 20,
                        color: AppColors.ghostWhite,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // XP Earned Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.fogGrey,
                  border: Border.all(color: AppColors.pulseBlue.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.pulseBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    AnimatedBuilder(
                      animation: _xpAnimation,
                      builder: (context, child) {
                        final displayXp = (_xpEarned * _xpAnimation.value).round();
                        return Text(
                          '+$displayXp XP',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pulseBlue,
                            shadows: [
                              Shadow(
                                color: AppColors.pulseBlue.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Points Breakdown
              if (_myResult?['breakdown'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  color: AppColors.fogGrey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BREAKDOWN',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_myResult!['breakdown'] as Map<String, dynamic>).entries.map((e) {
                        String label = e.key.replaceAll('_', ' ').toUpperCase();
                        String value = e.value.toString();
                        if (e.value is double) value = (e.value as double).toStringAsFixed(1);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
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
                      }),
                    ],
                  ),
                ),
              ],

              // Level Progress Section
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(width: 4, height: 16, color: AppColors.warningYellow),
                    const SizedBox(width: 8),
                    Text(
                      'LEVEL PROGRESS',
                      style: GoogleFonts.creepster(
                        fontSize: 20,
                        color: AppColors.ghostWhite,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                color: AppColors.fogGrey,
                child: _buildLevelProgress(),
              ),

              // Dismiss Button
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: widget.onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ghostWhite,
                    side: const BorderSide(color: AppColors.ghostWhite),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(
                    'VIEW SESSION',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelProgress() {
    int currentLevel = _newLevel;
    int startXP = PlayerProfile.cumulativeXpForLevel(currentLevel);
    int xpNeeded = (100 * pow(1.1, currentLevel - 1)).round();
    int currentTotalXP = _myResult?['new_total_xp'] ?? 0;
    int xpInLevel = currentTotalXP - startXP;
    if (xpInLevel < 0) xpInLevel = 0;

    double progress = 0.0;
    if (xpNeeded > 0) {
      progress = xpInLevel / xpNeeded;
      if (progress > 1.0) progress = 1.0;
    }

    final leveledUp = _newLevel > _oldLevel;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Level $_oldLevel',
              style: GoogleFonts.jetBrainsMono(
                color: leveledUp ? AppColors.textSecondary : AppColors.ghostWhite,
              ),
            ),
            if (leveledUp) ...[
              const Icon(Icons.arrow_forward, color: AppColors.warningYellow),
              Text(
                'Level $_newLevel',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warningYellow,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _xpAnimation,
          builder: (context, child) {
            return Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.voidBlack,
                border: Border.all(color: AppColors.warningYellow.withOpacity(0.5)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _xpAnimation.value * progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.warningYellow,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warningYellow.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '$xpInLevel / $xpNeeded XP',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        if (leveledUp && _controller.isCompleted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.warningYellow.withOpacity(0.2),
            child: Text(
              'LEVEL UP!',
              style: GoogleFonts.creepster(
                fontSize: 18,
                color: AppColors.warningYellow,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: AppColors.warningYellow.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
