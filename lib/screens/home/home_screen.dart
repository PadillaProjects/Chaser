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

import 'package:chaser/character/widgets/character_avatar.dart';
import 'package:chaser/providers/user_provider.dart';

// ... (imports)

// Remove local definition of authStateProvider since we moved it to user_provider.dart
// But wait, HomeScreen defines userSessionsProvider which depends on authStateProvider.
// I should update userSessionsProvider to use the one from user_provider.dart or just leave it if names collide.
// Actually, looking at the code, I can just import user_provider.dart and remove the local authStateProvider definition.
// But userSessionsProvider is defined in this file too. I should update it to use the import.

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ... initState ...

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        title: Text(
          'CHASER',
          style: GoogleFonts.creepster(
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
          // --- TOP HALF: CHARACTER ---
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.voidBlack,
                border: Border(bottom: BorderSide(color: AppColors.bloodRed.withOpacity(0.3))),
                boxShadow: [
                  BoxShadow(color: AppColors.bloodRed.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: userProfileAsync.when(
                data: (profile) => profile != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate character size to fit with room for text below
                          final availableHeight = constraints.maxHeight;
                          final charSize = (availableHeight * 0.55).clamp(100.0, 180.0);
                          
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Character with glow
                              GestureDetector(
                                onTap: () => context.push('/customize'),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Glow effect behind
                                    Container(
                                      width: charSize * 0.9,
                                      height: charSize * 0.9,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: AppColors.pulseBlue.withOpacity(0.2), blurRadius: 50, spreadRadius: 10),
                                        ],
                                      ),
                                    ),
                                    CharacterAvatar(profile: profile.character, size: charSize),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              

                              const SizedBox(height: 12),
                              
                              // Customize Button
                              FilledButton.icon(
                                onPressed: () => context.push('/customize'),
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text('CUSTOMIZE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.bloodRed.withOpacity(0.2),
                                  foregroundColor: AppColors.bloodRed,
                                  side: BorderSide(color: AppColors.bloodRed),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bloodRed)),
                error: (e, _) => Center(child: Icon(Icons.error, color: AppColors.bloodRed)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.fogGrey,
                  child: Row(
                    children: [
                      Icon(Icons.radar, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE ZONES',
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
                                'NO ACTIVE HUNTS',
                                style: GoogleFonts.jetBrainsMono(
                                  color: AppColors.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Small CTA since FAB handles main creation
                               OutlinedButton(
                                onPressed: () => context.push('/create-session'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(color: AppColors.textSecondary),
                                ),
                                child: const Text('CREATE ZONE'),
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
                                  color: isActive ? AppColors.bloodRed : AppColors.textMuted,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                session.name.toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ghostWhite,
                                  letterSpacing: 1,
                                ),
                              ),
                              subtitle: Text(
                                '${session.memberCount} Players • ${isActive ? 'HUNTING' : 'PENDING'}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  color: isActive ? AppColors.bloodRed : AppColors.textSecondary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: isActive ? AppColors.bloodRed : AppColors.textMuted,
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

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.fogGrey,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          'ENTER THE ZONE',
          style: GoogleFonts.creepster(
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
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
