import 'package:go_router/go_router.dart';

import '../../features/auth/viewmodels/session_viewmodel.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/home/views/home_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/splash/views/splash_view.dart';
import 'app_routes.dart';

/// Roteador central com guard de autenticação (C2.2 / C2.5).
GoRouter createAppRouter(SessionViewModel session) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isPublic = AppRoutes.public.contains(location);

      if (!session.isAuthenticated && !isPublic) return AppRoutes.login;
      if (session.isAuthenticated && location == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeView(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsView(),
          ),
        ],
      ),
    ],
  );
}
