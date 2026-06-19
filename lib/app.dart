import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'routes/app_routes.dart';

class SiteConnectApp extends StatelessWidget {
  const SiteConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep the root widget thin. App-wide concerns such as theme and routing
    // live here, while features own their screens and business workflows.
    return MaterialApp(
      title: 'SiteConnect Uganda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
