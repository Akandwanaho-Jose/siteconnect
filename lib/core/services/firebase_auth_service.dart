import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../shared/models/app_user.dart';
import '../constants/firestore_collections.dart';
import '../constants/user_roles.dart';
import 'auth_failure.dart';
import 'authenticated_session.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AuthenticatedSession> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure(
          code: 'missing-auth-user',
          message: 'Unable to confirm the signed-in account.',
          shouldSignOut: true,
        );
      }

      final profile = await fetchUserProfile(firebaseUser.uid);

      return AuthenticatedSession(firebaseUser: firebaseUser, profile: profile);
    } on AuthFailure catch (error) {
      if (error.shouldSignOut) {
        await signOut();
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(
        code: 'unknown-auth-error',
        message: 'Unable to sign in. Please try again.',
      );
    }
  }

  Future<AuthenticatedSession> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required AppUser userProfile,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFailure(
          code: 'missing-auth-user',
          message: 'Unable to confirm the created account.',
          shouldSignOut: true,
        );
      }

      final now = DateTime.now();
      final profile = _validateProfile(
        userProfile.copyWith(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? email.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await saveUserProfile(profile);
      await firebaseUser.updateDisplayName(profile.fullName);

      return AuthenticatedSession(firebaseUser: firebaseUser, profile: profile);
    } on AuthFailure catch (error) {
      if (error.shouldSignOut) {
        await signOut();
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(
        code: 'unknown-account-creation-error',
        message: 'Unable to create the user account.',
        shouldSignOut: true,
      );
    }
  }

  Future<AuthenticatedSession?> restoreCurrentSession() async {
    try {
      final user = currentUser ?? await authStateChanges().first;
      if (user == null) {
        return null;
      }

      final profile = await fetchUserProfile(user.uid);

      return AuthenticatedSession(firebaseUser: user, profile: profile);
    } on AuthFailure catch (error) {
      if (error.shouldSignOut) {
        await signOut();
      }
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(
        code: 'session-restore-failed',
        message: 'Unable to restore your session. Please try again.',
      );
    }
  }

  Future<AppUser> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'not-authenticated',
        message: 'Please sign in to continue.',
        shouldSignOut: true,
      );
    }

    return fetchUserProfile(user.uid);
  }

  Future<AppUser> fetchUserProfile(String uid) async {
    try {
      final snapshot = await _usersCollection.doc(uid).get();
      if (!snapshot.exists) {
        throw const AuthFailure(
          code: 'user-profile-missing',
          message: 'Your account profile is missing. Contact an administrator.',
          shouldSignOut: true,
        );
      }

      return _validateProfile(AppUser.fromFirestore(snapshot));
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    }
  }

  Stream<AppUser?> currentUserProfileStream() {
    final user = currentUser;
    if (user == null) {
      return const Stream<AppUser?>.empty();
    }

    return _usersCollection.doc(user.uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return AppUser.fromFirestore(snapshot);
    });
  }

  Future<void> saveUserProfile(AppUser user) {
    // User documents are intentionally kept in one collection for the MVP.
    // Role-specific permissions can be added around this model without moving
    // existing data as modules mature.
    return _usersCollection
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  Future<AppUser> updateCurrentUserProfile({
    required String fullName,
    required String phoneNumber,
    required String district,
    String? profileImage,
  }) async {
    final profile = await fetchCurrentUserProfile();
    final updatedProfile = profile.copyWith(
      fullName: fullName.trim(),
      phoneNumber: phoneNumber.trim(),
      district: district.trim(),
      profileImage: profileImage?.trim(),
      updatedAt: DateTime.now(),
    );

    await saveUserProfile(updatedProfile);
    await currentUser?.updateDisplayName(updatedProfile.fullName);

    return updatedProfile;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _mapPasswordResetException(error);
    } catch (_) {
      throw const AuthFailure(
        code: 'password-reset-failed',
        message: 'Unable to send the password reset email.',
      );
    }
  }

  Future<void> changeCurrentUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      throw const AuthFailure(
        code: 'not-authenticated',
        message: 'Please sign in to continue.',
        shouldSignOut: true,
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } catch (_) {
      throw const AuthFailure(
        code: 'password-change-failed',
        message: 'Unable to change your password.',
      );
    }
  }

  Future<void> signOut() => _auth.signOut();

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection(FirestoreCollections.users);
  }

  AppUser _validateProfile(AppUser profile) {
    if (profile.role == UserRole.unknown) {
      throw const AuthFailure(
        code: 'user-role-missing',
        message: 'Your account does not have an assigned role yet.',
        shouldSignOut: true,
      );
    }

    if (!profile.isActive) {
      throw const AuthFailure(
        code: 'user-profile-disabled',
        message: 'This account has been deactivated. Contact an administrator.',
        shouldSignOut: true,
      );
    }

    return profile;
  }

  AuthFailure _mapPasswordResetException(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => const AuthFailure(
        code: 'invalid-email',
        message: 'Enter a valid email address.',
      ),
      'user-disabled' => const AuthFailure(
        code: 'user-disabled',
        message: 'This account has been disabled. Contact an administrator.',
      ),
      'too-many-requests' => const AuthFailure(
        code: 'too-many-requests',
        message: 'Too many attempts. Please wait and try again.',
      ),
      'network-request-failed' => const AuthFailure(
        code: 'network-request-failed',
        message: 'Network connection failed. Please try again when online.',
      ),
      _ => const AuthFailure(
        code: 'password-reset-failed',
        message: 'Unable to send the password reset email.',
      ),
    };
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => const AuthFailure(
        code: 'invalid-credentials',
        message: 'Email or password is incorrect.',
      ),
      'invalid-email' => const AuthFailure(
        code: 'invalid-email',
        message: 'Enter a valid email address.',
      ),
      'user-disabled' => const AuthFailure(
        code: 'user-disabled',
        message: 'This account has been disabled. Contact an administrator.',
      ),
      'too-many-requests' => const AuthFailure(
        code: 'too-many-requests',
        message: 'Too many attempts. Please wait and try again.',
      ),
      'network-request-failed' => const AuthFailure(
        code: 'network-request-failed',
        message: 'Network connection failed. Please try again when online.',
      ),
      'email-already-in-use' => const AuthFailure(
        code: 'email-already-in-use',
        message: 'An account already exists for this email address.',
      ),
      'requires-recent-login' => const AuthFailure(
        code: 'requires-recent-login',
        message: 'Sign out, sign in again, then try changing your password.',
      ),
      'weak-password' => const AuthFailure(
        code: 'weak-password',
        message: 'Use a stronger password for this account.',
      ),
      _ => const AuthFailure(
        code: 'firebase-auth-error',
        message: 'Unable to authenticate. Please try again.',
      ),
    };
  }

  AuthFailure _mapFirestoreException(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const AuthFailure(
        code: 'profile-permission-denied',
        message: 'You do not have permission to access this profile.',
        shouldSignOut: true,
      ),
      'unavailable' || 'deadline-exceeded' => const AuthFailure(
        code: 'profile-service-unavailable',
        message: 'Unable to load your profile. Check your connection.',
      ),
      _ => const AuthFailure(
        code: 'profile-load-failed',
        message: 'Unable to load your account profile.',
      ),
    };
  }
}
