import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/app_user.dart';
import '../constants/user_roles.dart';

class AuthenticatedSession {
  const AuthenticatedSession({
    required this.firebaseUser,
    required this.profile,
  });

  final User firebaseUser;
  final AppUser profile;

  UserRole get role => profile.role;
}
