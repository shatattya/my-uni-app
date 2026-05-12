import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(userRepositoryProvider));
});

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final UserRepository _userRepo;

  AuthService(this._userRepo);

  // Existing Student Sign Up (Unchanged)
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
}