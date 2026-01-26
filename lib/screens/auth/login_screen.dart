import 'package:chaser/services/firebase/auth_service.dart';
import 'package:flutter/material.dart';

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
      // Navigation is handled by router based on auth state
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chaser',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 60),
              
              if (_isRegistering)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
              if (_isRegistering) const SizedBox(height: 16),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailAuth,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegistering ? 'Register' : 'Sign In'),
              ),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                  });
                },
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Sign In'
                      : 'Create an account',
                ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                   Expanded(child: Divider()),
                   Padding(
                     padding: EdgeInsets.symmetric(horizontal: 16),
                     child: Text('OR'),
                   ),
                   Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.g_mobiledata, size: 28), // Using standard icon as placeholder
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
              // Apple would go here
            ],
          ),
        ),
      ),
    );
  }
}
