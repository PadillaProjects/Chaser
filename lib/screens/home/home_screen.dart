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

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});

final userSessionsProvider = StreamProvider((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return const Stream<List<SessionModel>>.empty();
  return FirestoreService().watchUserSessions(user.uid);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("HomeScreen: Requesting Pedometer Permissions...");
      final success = await PedometerService().requestPermissions();
      debugPrint("HomeScreen: Permissions request result: $success");
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(userSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ACTIVE HUNTS',
          style: GoogleFonts.creepster(
            fontSize: 24,
            letterSpacing: 2,
            color: AppColors.ghostWhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.bloodRed),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: sessionsAsync.when(
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
                    size: 64,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NO HUNTS ACTIVE',
                    style: GoogleFonts.creepster(
                      fontSize: 24,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a kill zone.',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bloodRed.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: () => context.push('/create-session'),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'BEGIN A HUNT',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.bloodRed,
                        foregroundColor: AppColors.ghostWhite,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showJoinDialog(context),
                    icon: const Icon(Icons.login),
                    label: Text(
                      'ENTER THE ZONE',
                      style: GoogleFonts.jetBrainsMono(
                        letterSpacing: 2,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ghostWhite,
                      side: const BorderSide(color: AppColors.ghostWhite),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
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
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.bloodRed.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
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
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${session.memberCount} Prey',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: isActive
                              ? AppColors.bloodRed.withOpacity(0.2)
                              : AppColors.textMuted.withOpacity(0.2),
                          child: Text(
                            isActive ? 'HUNTING' : session.status.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? AppColors.bloodRed : AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
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
