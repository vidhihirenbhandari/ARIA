import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/assistant/presentation/screens/chat_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/memory/presentation/screens/memory_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/people/presentation/screens/people_screen.dart';
import '../../features/renewals/presentation/screens/renewals_screen.dart';
import '../../features/travel/presentation/screens/travel_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/permissions_screen.dart';
import '../../features/settings/presentation/screens/assistant_name_screen.dart';
import '../../main_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isOnboarded = authState.user?.onboardingComplete ?? false;

      final isLoginRoute = state.matchedLocation == '/login';
      final isSplashRoute = state.matchedLocation == '/';
      final isOnboardingRoute =
          state.matchedLocation == '/onboarding';

      if (isSplashRoute) return null;

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && !isOnboarded && !isOnboardingRoute) {
        return '/onboarding';
      }
      if (isAuth && isOnboarded && isLoginRoute) return '/home';
      if (isAuth && isOnboarded && isOnboardingRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainNavigation(child: child),
        routes: [
          GoRoute(
            path: '/home',
            redirect: (context, state) =>
                state.matchedLocation == '/home' ? '/home/dashboard' : null,
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => const ChatScreen(),
              ),
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
              GoRoute(
                path: 'memory',
                builder: (context, state) => const MemoryScreen(),
              ),
              GoRoute(
                path: 'tasks',
                builder: (context, state) => const TasksScreen(),
              ),
              GoRoute(
                path: 'inbox',
                builder: (context, state) => const InboxScreen(),
              ),
              GoRoute(
                path: 'people',
                builder: (context, state) => const PeopleScreen(),
              ),
              GoRoute(
                path: 'renewals',
                builder: (context, state) => const RenewalsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/travel',
        builder: (context, state) => const TravelScreen(),
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TravelScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'permissions',
            builder: (context, state) => const PermissionsScreen(),
          ),
          GoRoute(
            path: 'assistant-name',
            builder: (context, state) => const AssistantNameScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
