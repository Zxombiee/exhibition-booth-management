import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // flutter_secure_storage — stores sensitive data encrypted on device
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyUid   = 'auth_uid';

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<AppUser?> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Store UID securely after successful login
        final token = await user.getIdToken();
        await _secureStorage.write(key: _keyToken, value: token);
        await _secureStorage.write(key: _keyUid,   value: user.uid);

        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return AppUser.fromMap(user.uid, doc.data()!);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  // Register new user
  Future<AppUser?> registerWithEmailAndPassword(
      String name,
      String email,
      String password,
      UserRole role,
      String? companyName,
      ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Store UID securely after registration
        final token = await user.getIdToken();
        await _secureStorage.write(key: _keyToken, value: token);
        await _secureStorage.write(key: _keyUid,   value: user.uid);

        final appUser = AppUser(
          id: user.uid,
          name: name,
          email: email,
          role: role,
          companyName: companyName,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
        return appUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  // Sign out — clears secure storage
  Future<void> signOut() async {
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyUid);
    await _auth.signOut();
  }

  // Read stored UID securely
  Future<String?> getStoredUid() async {
    return await _secureStorage.read(key: _keyUid);
  }

  // Check if a secure token exists (for quick auth check)
  Future<bool> hasStoredToken() async {
    final token = await _secureStorage.read(key: _keyToken);
    return token != null && token.isNotEmpty;
  }
}