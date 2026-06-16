import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../shared/models/user.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(localStorageProvider);
  return AuthRepository(apiClient, storage);
});

class AuthRepository {
  final ApiClient _apiClient;
  final LocalStorage _storage;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthRepository(this._apiClient, this._storage);

  Future<User> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final auth = await account.authentication;
    final response = await _apiClient.post('/auth/google', data: {
      'id_token': auth.idToken,
      'access_token': auth.accessToken,
    });

    final token = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;
    await _storage.saveAuthToken(token);
    await _storage.saveRefreshToken(refreshToken);

    final userData = response.data['user'] as Map<String, dynamic>;
    final user = User.fromJson(userData);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInWithApple() async {
    // Apple sign-in implementation
    final response = await _apiClient.post('/auth/apple', data: {});
    final token = response.data['access_token'] as String;
    await _storage.saveAuthToken(token);
    final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInWithEmail(String email, String password) async {
    final response = await _apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = response.data['access_token'] as String;
    final refreshToken = response.data['refresh_token'] as String;
    await _storage.saveAuthToken(token);
    await _storage.saveRefreshToken(refreshToken);

    final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<User> signInAsDemo() async {
    final response = await _apiClient.post('/auth/demo', data: {});
    final token = response.data['access_token'] as String;
    await _storage.saveAuthToken(token);
    final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<void> signOut() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
    await _googleSignIn.signOut();
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
    try {
      await _apiClient.post('/users/onboarding/complete');
    } catch (_) {}
  }
}
