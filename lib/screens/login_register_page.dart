import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import '../game/services/audio_manager.dart';
import '../game/services/save_manager.dart';
import '../l10n/app_localizations.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}
class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;

  static const String _developerEmail = 'dev@rebirth2048.local';
  static const String _developerPassword = 'Rebirth2048Dev!';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToGame() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _emailSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (kDebugMode &&
          email == _developerEmail &&
          password == _developerPassword) {
        await SaveManager.setDeveloperMode(true);
        if (mounted) _goToGame();
        return;
      }

      await SaveManager.setDeveloperMode(false);
      if (_isRegister) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (mounted) _goToGame();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showError(_authError(l10n, error.code));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async => _providerLogin(GoogleAuthProvider());

  Future<void> _appleLogin() async => _providerLogin(AppleAuthProvider());

  Future<void> _providerLogin(AuthProvider provider) async {
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
      if (mounted) _goToGame();
    } on FirebaseAuthException catch (error) {
      if (mounted &&
          error.code != 'popup-closed-by-user' &&
          error.code != 'cancelled-popup-request') {
        final l10n = AppLocalizations.of(context)!;
        _showError(_authError(l10n, error.code));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(AppLocalizations l10n, String code) {
    switch (code) {
      case 'email-already-in-use':
        return l10n.authEmailAlreadyInUse;
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return l10n.authInvalidCredentials;
      case 'weak-password':
        return l10n.authWeakPassword;
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      default:
        return l10n.authFailed;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 72),
                const SizedBox(height: 20),
                Text(
                  l10n.authChooseMethod,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          unawaited(
                            AudioManager.instance.playSfx(GameSfx.buttonClick),
                          );
                          _googleLogin();
                        },
                  icon: const Icon(Icons.g_mobiledata, size: 30),
                  label: Text(l10n.authGoogle),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          unawaited(
                            AudioManager.instance.playSfx(GameSfx.buttonClick),
                          );
                          _appleLogin();
                        },
                  icon: const Icon(Icons.apple),
                  label: Text(l10n.authApple),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(l10n.authOr),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.authEmail,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.authEmailRequired;
                          }
                          if (!value.contains('@')) {
                            return l10n.authInvalidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: l10n.authPassword,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.password_outlined),
                          suffixIcon: IconButton(
                            onPressed: () {
                              unawaited(
                                AudioManager.instance.playSfx(
                                  GameSfx.buttonClick,
                                ),
                              );
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.authPasswordRequired;
                          }
                          if (value.length < 6) {
                            return l10n.authPasswordTooShort;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  unawaited(
                                    AudioManager.instance.playSfx(
                                      GameSfx.buttonClick,
                                    ),
                                  );
                                  _emailSubmit();
                                },
                          child: Text(
                            _isRegister ? l10n.authRegister : l10n.authLogin,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                unawaited(
                                  AudioManager.instance.playSfx(
                                    GameSfx.buttonClick,
                                  ),
                                );
                                setState(() => _isRegister = !_isRegister);
                              },
                        child: Text(
                          _isRegister
                              ? l10n.authSwitchToLogin
                              : l10n.authSwitchToRegister,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          unawaited(
                            AudioManager.instance.playSfx(GameSfx.buttonClick),
                          );
                          _goToGame();
                        },
                  child: Text(l10n.authSkip),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

