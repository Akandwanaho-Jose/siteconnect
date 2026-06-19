import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../shared/models/app_user.dart';
import '../constants/firestore_collections.dart';
import '../constants/user_roles.dart';
import 'auth_failure.dart';

class AdminUserService {
  AdminUserService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<AppUser> createManagedUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    required String phoneNumber,
    required String district,
    String? profileImage,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) {
      throw const AuthFailure(
        code: 'not-authenticated',
        message: 'Please sign in to continue.',
      );
    }

    final secondaryAuth = await _userCreationAuth();

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthFailure(
          code: 'missing-created-user',
          message: 'Unable to confirm the created user.',
        );
      }

      await firebaseUser.updateDisplayName(fullName.trim());
      await secondaryAuth.signOut();

      final now = DateTime.now();
      final profile = AppUser(
        uid: firebaseUser.uid,
        fullName: fullName.trim(),
        email: firebaseUser.email ?? email.trim(),
        role: role,
        phoneNumber: phoneNumber.trim(),
        district: district.trim(),
        profileImage: _blankToNull(profileImage),
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: adminUser.uid,
      );

      await _usersCollection.doc(profile.uid).set(profile.toFirestore());

      return profile;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Future<void> updateManagedUser(AppUser user) async {
    final existingSnapshot = await _usersCollection.doc(user.uid).get();
    final existingProfile = existingSnapshot.exists
        ? AppUser.fromFirestore(existingSnapshot)
        : user;
    final updatedUser = user.copyWith(
      email: existingProfile.email,
      updatedAt: DateTime.now(),
    );

    await _usersCollection
        .doc(user.uid)
        .set(updatedUser.toFirestore(), SetOptions(merge: true));

    if (_auth.currentUser?.uid == updatedUser.uid) {
      await _auth.currentUser?.updateDisplayName(updatedUser.fullName);
    }
  }

  Future<AppUser> replaceManagedUserLoginEmail({
    required AppUser user,
    required String email,
    required String password,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) {
      throw const AuthFailure(
        code: 'not-authenticated',
        message: 'Please sign in to continue.',
      );
    }

    if (adminUser.uid == user.uid) {
      throw const AuthFailure(
        code: 'cannot-replace-own-login',
        message: 'Create another administrator before changing your own login.',
      );
    }

    final replacementEmail = email.trim().toLowerCase();
    await _ensureEmailIsAvailableForReplacement(
      email: replacementEmail,
      currentUserId: user.uid,
    );

    final secondaryAuth = await _userCreationAuth();

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: replacementEmail,
        password: password,
      );
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthFailure(
          code: 'missing-created-user',
          message: 'Unable to confirm the replacement login.',
        );
      }

      await firebaseUser.updateDisplayName(user.fullName.trim());
      await secondaryAuth.signOut();

      final now = DateTime.now();
      final replacementProfile = user.copyWith(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? replacementEmail,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: adminUser.uid,
      );

      await _replaceProfileAndMemberships(
        oldUser: user,
        replacementUser: replacementProfile,
        adminUserId: adminUser.uid,
        replacedAt: now,
      );

      return replacementProfile;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw _mapFirestoreException(error);
    } finally {
      await secondaryAuth.signOut();
    }
  }

  Future<void> _ensureEmailIsAvailableForReplacement({
    required String email,
    required String currentUserId,
  }) async {
    final existingProfiles = await _usersCollection
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (existingProfiles.docs.isEmpty) {
      return;
    }

    final existingProfile = AppUser.fromFirestore(existingProfiles.docs.first);
    if (existingProfile.uid == currentUserId) {
      return;
    }

    throw AuthFailure(
      code: 'email-already-used-by-profile',
      message:
          '$email is already assigned to ${existingProfile.fullName}. '
          'Open that user instead of replacing this login.',
    );
  }

  Future<void> _replaceProfileAndMemberships({
    required AppUser oldUser,
    required AppUser replacementUser,
    required String adminUserId,
    required DateTime replacedAt,
  }) async {
    final batch = _firestore.batch();
    final oldUserRef = _usersCollection.doc(oldUser.uid);
    final replacementUserRef = _usersCollection.doc(replacementUser.uid);

    batch.set(replacementUserRef, replacementUser.toFirestore());
    batch.set(oldUserRef, {
      'isActive': false,
      'updatedAt': Timestamp.fromDate(replacedAt),
      'replacementUserId': replacementUser.uid,
      'replacedBy': adminUserId,
      'replacedAt': Timestamp.fromDate(replacedAt),
    }, SetOptions(merge: true));

    final memberships = await _firestore
        .collection(FirestoreCollections.projectMembers)
        .where('userId', isEqualTo: oldUser.uid)
        .get();

    for (final member in memberships.docs) {
      final data = member.data();
      final projectId = data['projectId'] as String? ?? '';
      final role = data['role'] as String? ?? replacementUser.role.value;
      final replacementMemberId = [
        if (projectId.isNotEmpty) projectId,
        replacementUser.uid,
        role,
      ].join('_');

      batch.set(
        _firestore
            .collection(FirestoreCollections.projectMembers)
            .doc(replacementMemberId),
        {
          ...data,
          'id': replacementMemberId,
          'userId': replacementUser.uid,
          'role': role,
          'status': 'active',
          'createdBy': data['createdBy'] ?? adminUserId,
          'updatedAt': Timestamp.fromDate(replacedAt),
        },
        SetOptions(merge: true),
      );

      batch.set(member.reference, {
        'status': 'removed',
        'updatedAt': Timestamp.fromDate(replacedAt),
        'replacedByUserId': replacementUser.uid,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<FirebaseAuth> _userCreationAuth() async {
    const secondaryAppName = 'siteconnectUserCreation';

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app(secondaryAppName);
    } on FirebaseException {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    return FirebaseAuth.instanceFor(app: secondaryApp);
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection(FirestoreCollections.users);
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => const AuthFailure(
        code: 'email-already-in-use',
        message: 'An account already exists for this email address.',
      ),
      'invalid-email' => const AuthFailure(
        code: 'invalid-email',
        message: 'Enter a valid email address.',
      ),
      'weak-password' => const AuthFailure(
        code: 'weak-password',
        message: 'Use a stronger temporary password.',
      ),
      'operation-not-allowed' => const AuthFailure(
        code: 'operation-not-allowed',
        message: 'Email/password sign-in is not enabled in Firebase.',
      ),
      'network-request-failed' => const AuthFailure(
        code: 'network-request-failed',
        message: 'Network connection failed. Please try again when online.',
      ),
      _ => const AuthFailure(
        code: 'user-create-failed',
        message: 'Unable to create this user account.',
      ),
    };
  }

  AuthFailure _mapFirestoreException(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const AuthFailure(
        code: 'user-profile-permission-denied',
        message: 'You do not have permission to manage user profiles.',
      ),
      _ => const AuthFailure(
        code: 'user-profile-save-failed',
        message: 'Unable to save this user profile.',
      ),
    };
  }
}
