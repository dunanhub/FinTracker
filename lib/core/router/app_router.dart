import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/controllers/auth_controller.dart';
import '../../presentation/screens/account_screen.dart';
import '../../presentation/screens/accounts_screen.dart';
import '../../presentation/screens/budgets_screen.dart';
import '../../presentation/screens/currency_rates_screen.dart';
import '../../presentation/screens/debts_screen.dart';
import '../../presentation/screens/debt_details_screen.dart';
import '../../presentation/screens/notifications_screen.dart';
import '../../presentation/screens/device_diagnostics_screen.dart';
import '../../presentation/screens/goals_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/register_screen.dart';
import '../../presentation/screens/reports_screen.dart';
import '../../presentation/screens/savings_calculator_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/shell/main_shell.dart';
import '../../presentation/screens/transaction_map_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static GoRouter create({AuthController? authController}) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: authController,
      redirect: (context, state) {
        if (authController == null) {
          return null;
        }

        final authenticated = authController.isAuthenticated;

        final location = state.matchedLocation;

        final isAuthRoute =
            location == AppRoutes.login || location == AppRoutes.register;

        if (!authenticated && !isAuthRoute) {
          return AppRoutes.login;
        }

        if (authenticated && isAuthRoute) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          pageBuilder:
              (context, state) =>
                  _page(state, const LoginScreen(), transition: false),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) => _page(state, const RegisterScreen()),
        ),
        GoRoute(
          path: AppRoutes.home,
          pageBuilder:
              (context, state) =>
                  _page(state, const MainShell(), transition: false),
        ),
        GoRoute(
          path: AppRoutes.accounts,
          pageBuilder: (context, state) => _page(state, const AccountsScreen()),
        ),
        GoRoute(
          path: AppRoutes.budgets,
          pageBuilder: (context, state) => _page(state, const BudgetsScreen()),
        ),
        GoRoute(
          path: AppRoutes.goals,
          pageBuilder: (context, state) => _page(state, const GoalsScreen()),
        ),
        GoRoute(
          path: AppRoutes.debts,
          pageBuilder: (context, state) => _page(state, const DebtsScreen()),
        ),
        GoRoute(
          path: AppRoutes.debtDetails,
          pageBuilder:
              (context, state) => _page(
                state,
                DebtDetailsScreen(debtId: state.pathParameters['id']!),
              ),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          pageBuilder:
              (context, state) => _page(
                state,
                NotificationsScreen(openId: state.uri.queryParameters['open']),
              ),
        ),
        GoRoute(
          path: AppRoutes.reports,
          pageBuilder: (context, state) => _page(state, const ReportsScreen()),
        ),
        GoRoute(
          path: AppRoutes.currencyRates,
          pageBuilder:
              (context, state) => _page(state, const CurrencyRatesPage()),
        ),
        GoRoute(
          path: AppRoutes.calculator,
          pageBuilder:
              (context, state) => _page(state, const SavingsCalculatorScreen()),
        ),
        GoRoute(
          path: AppRoutes.account,
          pageBuilder: (context, state) => _page(state, const AccountScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => _page(state, const SettingsScreen()),
        ),
        GoRoute(
          path: AppRoutes.deviceDiagnostics,
          pageBuilder:
              (context, state) => _page(state, const DeviceDiagnosticsPage()),
        ),
        GoRoute(
          path: AppRoutes.transactionMap,
          pageBuilder:
              (context, state) => _page(state, const TransactionMapScreen()),
        ),
      ],
    );
  }

  static Page<void> _page(
    GoRouterState state,
    Widget child, {
    bool transition = true,
  }) {
    if (!transition) {
      return NoTransitionPage<void>(key: state.pageKey, child: child);
    }

    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
