import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _showPAT = false;
  final _patController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _patController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo / Branding
              Icon(
                Icons.edit_note,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Markdown Editor',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'GitHub-backed markdown editing',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // OAuth button
              FilledButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        await context.read<AuthProvider>().login();
                        if (mounted) setState(() => _isSubmitting = false);
                      },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with GitHub'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              // PAT toggle
              TextButton(
                onPressed: () => setState(() => _showPAT = !_showPAT),
                child: Text(_showPAT
                    ? 'Hide Personal Access Token'
                    : 'Use Personal Access Token'),
              ),
              if (_showPAT) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _patController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Personal Access Token',
                    border: OutlineInputBorder(),
                    hintText: 'ghp_...',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final pat = _patController.text.trim();
                          if (pat.isEmpty) return;
                          setState(() => _isSubmitting = true);
                          await context.read<AuthProvider>().loginWithPAT(pat);
                          if (mounted) setState(() => _isSubmitting = false);
                        },
                  child: const Text('Connect with Token'),
                ),
              ],
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (_isSubmitting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
