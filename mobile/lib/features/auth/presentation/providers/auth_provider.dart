import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/services/local_storage.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final LocalStorage _storage;

  AuthNotifier(this._repository, this._storage)
      : super(const AuthState()) {
    _initialize();
  }

  void _initialize() {
    final user = _repository.getCurrentUser();
    final onboardingComplete = _storage.isOnboardingComplete();

    if (user != null && onboardingComplete) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else if (user != null && !onboardingComplete) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInWithGoogle();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInWithApple();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> signInAsDemo() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInAsDemo();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.signInWithEmail(email, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> createAccount(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.createAccount(email, password, name);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateAssistantName(String name) async {
    await _repository.updateAssistantName(name);
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(assistantName: name),
      );
    }
  }

  Future<void> completeOnboarding() async {
    await _repository.completeOnboarding();
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(onboardingComplete: true),
      );
    }
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final storage = ref.watch(localStorageProvider);
  return AuthNotifier(repository, storage);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final assistantNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.assistantName ?? 'ARIA';
});
