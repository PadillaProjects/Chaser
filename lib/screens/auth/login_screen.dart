import 'package:chaser/config/colors.dart';
import 'package:chaser/services/firebase/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRegistering) {
        if (_nameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter your name')),
          );
           setState(() => _isLoading = false);
          return;
        }
        await _authService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
      } else {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.voidBlack,
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppColors.voidBlack,
              AppColors.voidBlack,
              Colors.black,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title with glow effect
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'CHASER',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.creepster(
                      fontSize: 64,
                      color: AppColors.bloodRed,
                      letterSpacing: 8,
                      shadows: [
                        Shadow(
                          color: AppColors.bloodRed.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: AppColors.bloodRed.withOpacity(0.5),
                          blurRadius: 40,
                        ),
                        Shadow(
                          color: AppColors.bloodRed.withOpacity(0.3),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                  ),
                ),

                // Tagline
                Text(
                  'THE HUNT AWAITS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    letterSpacing: 6,
                  ),
                ),

                const SizedBox(height: 60),

                // Name field (registration only)
                if (_isRegistering) ...[
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
                    decoration: InputDecoration(
                      labelText: 'HUNTER NAME',
                      labelStyle: GoogleFonts.jetBrainsMono(
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                      prefixIcon: const Icon(Icons.person_outline, color: AppColors.bloodRed),
                      filled: true,
                      fillColor: AppColors.fogGrey,
                      border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
                  decoration: InputDecoration(
                    labelText: 'EMAIL',
                    labelStyle: GoogleFonts.jetBrainsMono(
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.bloodRed),
                    filled: true,
                    fillColor: AppColors.fogGrey,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(color: AppColors.ghostWhite),
                  decoration: InputDecoration(
                    labelText: 'PASSWORD',
                    labelStyle: GoogleFonts.jetBrainsMono(
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.bloodRed),
                    filled: true,
                    fillColor: AppColors.fogGrey,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.bloodRed, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary action button with glow
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
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bloodRed,
                      foregroundColor: AppColors.ghostWhite,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ghostWhite,
                            ),
                          )
                        : Text(
                            _isRegistering ? 'JOIN THE HUNT' : 'ENTER',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                  ),
                ),

                // Toggle registration
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                    });
                  },
                  child: Text(
                    _isRegistering
                        ? 'Already a hunter? Sign In'
                        : 'New prey? Create account',
                    style: GoogleFonts.jetBrainsMono(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 24),

                // Google sign in button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(
                    'SIGN IN WITH GOOGLE',
                    style: GoogleFonts.jetBrainsMono(
                      letterSpacing: 2,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ghostWhite,
                    side: const BorderSide(color: AppColors.ghostWhite),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
