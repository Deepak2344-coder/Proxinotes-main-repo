import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/features/auth/data/auth_repository.dart';
import 'package:notes_app/features/viewer/data/viewer_repository.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/core/security/page_encryptor.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(supabaseClientProvider));
});

enum AuthStatus {
  uninitialized,
  unauthenticated,
  authenticating,
  authenticated
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;
  final bool needsUsername;

  const AuthState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.error,
    this.isLoading = false,
    this.needsUsername = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
    bool? needsUsername,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      needsUsername: needsUsername ?? this.needsUsername,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final ViewerRepository _viewerRepo;

  AuthNotifier(this._authRepo, this._viewerRepo) : super(const AuthState()) {
    _init();
  }

  void _init() {
    final session = _authRepo.currentSession;
    if (session != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: session.user,
      );
      _checkProfile();
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _authRepo.authStateChanges.listen((authState) {
      if (authState.session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: authState.session!.user,
        );
        _checkProfile();
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _checkProfile() async {
    final user = _authRepo.currentUser;
    if (user == null) return;

    final profile = await _authRepo.getProfile(user.id);
    final username = profile?['username'] as String?;

    if (username == null || username.isEmpty) {
      state = state.copyWith(needsUsername: true);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepo.signInWithGoogle();
      state = state.copyWith(isLoading: false, status: AuthStatus.authenticated);
      await _checkProfile();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> setUsername(String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _authRepo.currentUser;
      if (user == null) throw Exception('No authenticated user');
      await _authRepo.setUsername(user.id, username);
      state = state.copyWith(
        isLoading: false,
        needsUsername: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signOut() async {
    await _viewerRepo.clearAllCache();
    await PageEncryptor.deleteKey();
    await _authRepo.signOut();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final viewerRepo = ViewerRepository(ApiClient.instance);
  return AuthNotifier(ref.read(authRepositoryProvider), viewerRepo);
});
