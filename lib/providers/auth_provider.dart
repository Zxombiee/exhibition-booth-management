import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────
// AUTH PROVIDER
// Uses:
//   provider              — global state accessible from any screen
//   shared_preferences    — caches user role locally so router
//                           doesn't need a Firestore fetch every time
//   flutter_secure_storage — stores Firebase UID securely on device
// ─────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _prefs     = SharedPreferences.getInstance();
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── State ───────────────────────────────────────────────────
  User?   _user;
  String  _role        = 'exhibitor';
  String  _userName    = '';
  String  _userEmail   = '';
  bool    _isLoading   = true;

  // ── Getters ─────────────────────────────────────────────────
  User?   get user       => _user;
  String  get role       => _role;
  String  get userName   => _userName;
  String  get userEmail  => _userEmail;
  bool    get isLoading  => _isLoading;
  bool    get isLoggedIn => _user != null;

  bool    get isAdmin     => _role == 'admin';
  bool    get isOrganizer => _role == 'organizer';
  bool    get isExhibitor => _role == 'exhibitor';

  // ── Constructor ─────────────────────────────────────────────
  AuthProvider() {
    _init();
  }

  // ── Init — restore cached state on app start ────────────────
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Restore cached role from shared_preferences (fast, no network)
    final prefs = await _prefs;
    _role      = prefs.getString('user_role')  ?? 'exhibitor';
    _userName  = prefs.getString('user_name')  ?? '';
    _userEmail = prefs.getString('user_email') ?? '';

    // Listen to Firebase auth state
    _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        // Restore UID from secure storage to verify
        final storedUid = await _secureStorage.read(key: 'user_uid');
        if (storedUid != user.uid) {
          // UID mismatch — fetch fresh from Firestore
          await _fetchAndCacheUserData(user.uid);
        }
      } else {
        // Logged out — clear cache
        await _clearCache();
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  // ── Fetch user data from Firestore and cache locally ─────────
  Future<void> _fetchAndCacheUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _role      = data['role']  as String? ?? 'exhibitor';
        _userName  = data['name']  as String? ?? '';
        _userEmail = data['email'] as String? ?? '';

        // Cache in shared_preferences (survives app restart, fast read)
        final prefs = await _prefs;
        await prefs.setString('user_role',  _role);
        await prefs.setString('user_name',  _userName);
        await prefs.setString('user_email', _userEmail);

        // Store UID securely (encrypted)
        await _secureStorage.write(key: 'user_uid', value: uid);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider: failed to fetch user data — $e');
    }
  }

  // ── Call this after login to refresh role immediately ────────
  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _fetchAndCacheUserData(user.uid);
    }
  }

  // ── Get role without Firestore call (uses cache) ─────────────
  Future<String> getCachedRole() async {
    final prefs = await _prefs;
    return prefs.getString('user_role') ?? _role;
  }

  // ── Sign out ─────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
    await _clearCache();
  }

  // ── Clear all cached data ────────────────────────────────────
  Future<void> _clearCache() async {
    _role      = 'exhibitor';
    _userName  = '';
    _userEmail = '';

    final prefs = await _prefs;
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    await prefs.remove('user_email');

    await _secureStorage.delete(key: 'user_uid');

    notifyListeners();
  }
}