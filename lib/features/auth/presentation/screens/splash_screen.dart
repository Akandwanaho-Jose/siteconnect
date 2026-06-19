import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/app_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({FirebaseAuthService? authService, super.key})
    : _authService = authService;

  final FirebaseAuthService? _authService;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final FirebaseAuthService _authService;

  AuthFailure? _failure;
  bool _isResolving = true;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    unawaited(_resolveSession());
  }

  Future<void> _resolveSession() async {
    if (!_isResolving || _failure != null) {
      setState(() {
        _failure = null;
        _isResolving = true;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) {
      return;
    }

    try {
      final session = await _authService.restoreCurrentSession();

      if (!mounted) {
        return;
      }

      if (session == null) {
        await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        return;
      }

      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.dashboardForRole(session.role),
        arguments: DashboardRouteArguments(profile: session.profile),
      );
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _failure = error;
        _isResolving = false;
      });
    }
  }

  Future<void> _goToLogin() async {
    await _authService.signOut();

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.primaryGreenDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.nationalGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.engineering,
                  color: AppColors.primaryGreenDark,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (_isResolving)
                const LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  color: AppColors.nationalGold,
                )
              else
                _SplashError(
                  message: _failure?.message ?? 'Unable to start the app.',
                  onRetry: _resolveSession,
                  onSignIn: _goToLogin,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({
    required this.message,
    required this.onRetry,
    required this.onSignIn,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Sign in',
                  icon: Icons.login,
                  fullWidth: false,
                  onPressed: onSignIn,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
