import 'package:flutter/material.dart';

import '../core/services/firebase_auth_service.dart';
import 'app_route_arguments.dart';
import 'app_routes.dart';

class RouteGuard {
  const RouteGuard._();

  static RouteSettings guardedSettings(
    RouteSettings settings, {
    required FirebaseAuthService authService,
  }) {
    final routeName = settings.name;

    if (!AppRoutes.isProtectedRoute(routeName)) {
      return settings;
    }

    if (authService.currentUser != null) {
      return settings;
    }

    return RouteSettings(
      name: AppRoutes.login,
      arguments: LoginRouteArguments(
        message: 'Please sign in to continue.',
        redirectRoute: routeName,
      ),
    );
  }
}
