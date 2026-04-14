import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/upload/presentation/upload_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/home/presentation/shell_screen.dart';
import '../features/analysis/presentation/loading_screen.dart';
import '../features/analysis/presentation/results_screen.dart';
import '../features/gamification/presentation/screens/achievements_screen.dart';
import '../features/gamification/application/gamification_service.dart';
import '../features/analysis/presentation/meta_screen.dart';

// Auth imports
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/privacy_policy_screen.dart';
import '../features/auth/presentation/terms_screen.dart';
import '../core/auth_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuthenticated = authState == AuthState.authenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');
      
      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      
      // If user is authenticated and trying to access auth routes
      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }
      
      // No redirect
      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfileScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => TermsScreen(),
      ),
      
      // Main shell routes (protected)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/analysis/loading/:id',
        builder: (context, state) {
          final analysisId = state.pathParameters['id']!;
          return LoadingScreen(analysisId: analysisId);
        },
      ),
      GoRoute(
        path: '/analysis/results/:id',
        builder: (context, state) {
          final analysisId = state.pathParameters['id']!;
          final gamiResult = state.extra as GamificationResult?;
          return ResultsScreen(
            analysisId: analysisId,
            gamificationResult: gamiResult,
          );
        },
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => AchievementsScreen(),
      ),
      GoRoute(
        path: '/meta/:gameType',
        builder: (context, state) =>
            MetaScreen(gameType: state.pathParameters['gameType']!),
      ),
      GoRoute(
        path: '/upload',
        builder: (context, state) => UploadScreen(),
      ),
    ],
  );
});