import 'package:chaser/config/colors.dart';
import 'package:chaser/models/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';


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

class _GameResultsViewState extends ConsumerState<GameResultsView> {

  Map<String, dynamic>? get _myResult => widget.session.results?['player_results']?[widget.currentUserId];
  String get _winnerRole => widget.session.results?['winner_role'] ?? 'none';
  bool get _didIWin => _myResult?['outcome'] == 'won';


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
}
