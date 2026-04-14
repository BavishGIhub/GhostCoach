import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './services/auth_service.dart';
import './services/user_service.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// User Service Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

// Current User Provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Authentication State Provider
final authStateProvider = Provider<AuthState>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) {
        return AuthState.unauthenticated;
      } else if (user.isAnonymous) {
        // Guest users skip email verification
        return AuthState.authenticated;
      } else if (!user.emailVerified) {
        return AuthState.unverified;
      } else {
        return AuthState.authenticated;
      }
    },
    loading: () => AuthState.loading,
    error: (error, stackTrace) => AuthState.error,
  );
});

// User Data Provider
final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  
  if (user == null) {
    return const Stream.empty();
  }
  
  final userService = ref.watch(userServiceProvider);
  return userService.streamUser(user.uid);
});

// Authentication Notifier for managing auth state
class AuthNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    // Initial state
    return AuthStatus.initial;
  }

  // Sign in with email and password
  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      
      final user = await authService.signInWithEmailAndPassword(email, password);
      
      if (user != null) {
        // Create or update user document
        await userService.createOrUpdateUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }

  // Sign up with email and password
  Future<void> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      
      final user = await authService.signUpWithEmailAndPassword(
        email,
        password,
        displayName,
      );
      
      if (user != null) {
        // Create user document
        await userService.createOrUpdateUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: displayName,
          photoUrl: user.photoURL,
        );
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      
      final user = await authService.signInWithGoogle();
      
      if (user != null) {
        // Create or update user document
        await userService.createOrUpdateUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }

  // Sign in anonymously
  Future<void> signInAnonymously() async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      
      final user = await authService.signInAnonymously();
      
      if (user != null) {
        // Create or update user document for the anonymous guest
        await userService.createOrUpdateUser(
          uid: user.uid,
          email: '', // Anonymous users don't have an email
          displayName: 'Guest User',
          photoUrl: '', // Default or simple guest avatar could be handled downstream
        );
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.unauthenticated;
      }
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      state = AuthStatus.unauthenticated;
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final user = ref.read(currentUserProvider).value;
      
      if (user == null) {
        throw 'No user is signed in.';
      }
      
      await authService.updateProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      
      // Update user document
      await userService.createOrUpdateUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: displayName ?? user.displayName,
        photoUrl: photoUrl ?? user.photoURL,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      state = AuthStatus.loading;
      final authService = ref.read(authServiceProvider);
      final userService = ref.read(userServiceProvider);
      final user = ref.read(currentUserProvider).value;
      
      if (user == null) {
        throw 'No user is signed in.';
      }
      
      // Delete user data first
      await userService.deleteUserData(user.uid);
      
      // Delete auth account
      await authService.deleteAccount();
      
      state = AuthStatus.unauthenticated;
    } catch (e) {
      state = AuthStatus.error;
      rethrow;
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthStatus>(
  AuthNotifier.new,
);

// Enums for authentication states
enum AuthState {
  unauthenticated,
  unverified,
  authenticated,
  loading,
  error,
}

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

// Helper function to check if user is authenticated
bool isUserAuthenticated(AuthState state) {
  return state == AuthState.authenticated;
}

// Helper function to check if user is loading
bool isUserLoading(AuthState state) {
  return state == AuthState.loading;
}

// Helper function to check if user has error
bool hasAuthError(AuthState state) {
  return state == AuthState.error;
}