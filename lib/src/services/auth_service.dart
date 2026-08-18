import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/repositories/user_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/local/app_database.dart';
import '../providers/db_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(userRepositoryProvider),
    ref.watch(routineRepositoryProvider),
    ref.watch(dbProvider),
  );
});

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final UserRepository _userRepo;
  final RoutineRepository _routineRepo;
  final AppDatabase _db;

  AuthService(this._userRepo, this._routineRepo, this._db);

  // Existing Student Sign Up
  Future<firebase_auth.UserCredential> signUp({
    required String internalId,
    required String password,
    required String name,
    required int semester,
    required String section,
  }) async {
    final normalizedSection = section.toUpperCase().trim();
    final email = "$internalId@bgctub.local";

    firebase_auth.UserCredential credential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;

    await FirebaseFirestore.instance.collection("students").doc(internalId).set({
      "uid": uid,
      "name": name,
      "internalId": internalId,
      "semester": semester,
      "section": normalizedSection,
      "role": "student",
      "avatarId": 1,
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _userRepo.syncUser(uid);
    await _auth.signOut();
    return credential;
  }

  // New Teacher Sign Up
  Future<firebase_auth.UserCredential> signUpTeacher({
    required String email,
    required String password,
    required String name,
  }) async {
    // Strict enforcement of teacher email domain
    if (!email.endsWith("@bgctub.ac.bd")) {
      throw firebase_auth.FirebaseAuthException(
        code: "invalid-teacher-email",
        message: "Teachers must use a @bgctub.ac.bd email",
      );
    }

    firebase_auth.UserCredential credential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;

    // Save to 'teachers' collection using the email as the Document ID
    await FirebaseFirestore.instance.collection("teachers").doc(email).set({
      "uid": uid,
      "name": name,
      "internalId": email, // For teachers, their email is their internal identifier
      "role": "teacher",
      "avatarId": 10, // Default teacher avatar
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Sync to Local SQLite immediately
    await _userRepo.syncUser(uid);
    await _auth.signOut();
    return credential;
  }

  // Existing Login
  Future<firebase_auth.UserCredential> login({
    required String idOrEmail,
    required String password,
  }) async {
    String email;
    if (idOrEmail.contains("@")) {
      if (!idOrEmail.endsWith("@bgctub.ac.bd")) {
        throw firebase_auth.FirebaseAuthException(
          code: "invalid-teacher-email",
          message: "Teachers must use a @bgctub.ac.bd email",
        );
      }
      email = idOrEmail;
    } else {
      email = "$idOrEmail@bgctub.local";
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _userRepo.syncUser(credential.user!.uid);
    return credential;
  }

  // Centralized secure sign-out method
  Future<void> signOut() async {
    try {
      // 1. Delete the FCM token.
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      print("DEBUG: Failed to delete FCM token during sign out: $e");
    }

    // 2. Reset routine sync metadata to allow the next user to sync immediately
    _routineRepo.resetSyncMetadata();

    // 3. Annihilate the local SQLite database to prevent offline data ghosting
    await _db.clearAllData();

    // 4. Actually sign out of Firebase
    await _auth.signOut();
  }

  // ADDED: Centralized secure account deletion method
  Future<void> deleteAccount({
    required String password,
    required String role,
    required String docId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("Authentication session invalid.");
    }

    // 1. Re-authenticate to satisfy Firebase's sensitive action requirements
    final cred = firebase_auth.EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);

    // 2. Delete Firestore Profile Document
    final collection = role == 'teacher' ? 'teachers' : 'students';
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();

    // 3. Delete FCM token to stop future notifications
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      print("DEBUG: Failed to delete FCM token during account deletion: $e");
    }

    // 4. Wipe Local Database & Reset Sync State
    _routineRepo.resetSyncMetadata();
    await _db.clearAllData();

    // 5. Delete the Firebase Auth User
    await user.delete();
  }
}