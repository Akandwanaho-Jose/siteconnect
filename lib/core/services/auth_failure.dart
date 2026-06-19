class AuthFailure implements Exception {
  const AuthFailure({
    required this.code,
    required this.message,
    this.shouldSignOut = false,
  });

  final String code;
  final String message;

  /// True when the local Firebase Auth session should be cleared because the
  /// account cannot safely enter the app, for example when the Firestore user
  /// profile is missing or has no valid role.
  final bool shouldSignOut;

  @override
  String toString() => 'AuthFailure($code): $message';
}
