import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/local_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AuthRepository(storage);
});

class AuthRepository {
  final LocalStorage _storage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthRepository(this._storage);

  String _hashPassword(String password, String email) {
    final salt = '${email.toLowerCase()}_aria_v1';
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  Future<User> createAccount(String email, String password, String name) async {
    final trimmedEmail = email.trim().toLowerCase();
    final existing = _storage.getLocalAccount(trimmedEmail);
    if (existing != null) {
      throw Exception('An account with this email already exists. Please sign in.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: trimmedEmail,
      name: name.trim(),
      assistantName: 'ARIA',
      createdAt: DateTime.now(),
      onboardingComplete: false,
    );
    await _storage.saveLocalAccount(trimmedEmail, {
      'passwordHash': _hashPassword(password, trimmedEmail),
      'user': user.toJson(),
    });
    await _storage.saveAuthToken('local-auth-${user.id}');
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInWithEmail(String email, String password) async {
    final trimmedEmail = email.trim().toLowerCase();
    final account = _storage.getLocalAccount(trimmedEmail);
    if (account == null) {
      throw Exception('No account found. Please create an account first.');
    }
    final expectedHash = _hashPassword(password, trimmedEmail);
    if (account['passwordHash'] != expectedHash) {
      throw Exception('Incorrect password. Please try again.');
    }
    final user = User.fromJson(account['user'] as Map<String, dynamic>);
    await _storage.saveAuthToken('local-auth-${user.id}');
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final trimmedEmail = account.email.toLowerCase();
    var stored = _storage.getLocalAccount(trimmedEmail);

    User user;
    if (stored != null) {
      user = User.fromJson(stored['user'] as Map<String, dynamic>);
    } else {
      user = User(
        id: 'google_${account.id}',
        email: trimmedEmail,
        name: account.displayName ?? account.email.split('@').first,
        photoUrl: account.photoUrl,
        assistantName: 'ARIA',
        createdAt: DateTime.now(),
        onboardingComplete: false,
      );
      await _storage.saveLocalAccount(trimmedEmail, {
        'passwordHash': '',
        'provider': 'google',
        'user': user.toJson(),
      });
    }
    await _storage.saveAuthToken('google-auth-${user.id}');
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInWithApple() async {
    throw Exception('Apple Sign-In requires an Apple Developer account. Use email sign-in instead.');
  }

  Future<User> signInAsDemo() async {
    await _storage.setDemoMode(true);
    await _storage.saveAuthToken('demo-token');
    await _storage.setOnboardingComplete(true);
    final user = User(
      id: 'demo-user-001',
      email: 'demo@aria.app',
      name: 'Vidhi',
      assistantName: 'ARIA',
      createdAt: DateTime.now(),
      onboardingComplete: true,
    );
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.clearAll();
  }

  User? getCurrentUser() {
    final data = _storage.getUser();
    if (data == null) return null;
    return User.fromJson(data);
  }

  bool isAuthenticated() => _storage.getAuthToken() != null;

  Future<void> updateAssistantName(String name) async {
    await _storage.saveAssistantName(name);
    final user = getCurrentUser();
    if (user != null) {
      final updated = user.copyWith(assistantName: name);
      await _storage.saveUser(updated.toJson());
    }
  }

  Future<void> completeOnboarding() async {
    await _storage.setOnboardingComplete(true);
  }
}
