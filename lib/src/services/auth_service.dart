import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Added for FCM unsubscription
import '../data/repositories/user_repository.dart';
import '../data/repositories/routine_repository.dart'; // ADDED: To reset sync metadata
import '../data/local/app_database.dart'; // Added to access the database wipe
import '../providers/db_provider.dart'; // Added to inject the DB

final authServiceProvider = Provider<AuthService>((ref) {
  // MODIFICATION: Injected the RoutineRepository to handle metadata resets
  return AuthService(
    ref.watch(userRepositoryProvider),
    ref.watch(routineRepositoryProvider),
    ref.watch(dbProvider),
  );
});

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final UserRepository _userRepo;
  final RoutineRepository _routineRepo; // ADDED
  final AppDatabase _db; // Added database dependency

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

    // MODIFICATION: Sign out immediately so they aren't auto-logged in
    await _auth.signOut();

    return credential;
  }

  // ADDED: New Teacher Sign Up
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

    // MODIFICATION: Sign out immediately so they aren't auto-logged in
    await _auth.signOut();

    return credential;
  }

  // Existing Login (Unchanged)
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

  // MODIFICATION: Centralized secure sign-out method
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
}