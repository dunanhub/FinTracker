import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/shake_detector_service.dart';
import '../controllers/shake_settings_controller.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/more_screen.dart';
import '../screens/transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ShakeDetectorService _shakeDetector = ShakeDetectorService();
  StreamSubscription<void>? _shakeSubscription;
  ShakeSettingsController? _shakeSettings;
  ModalRoute<dynamic>? _homeRoute;
  bool _appResumed = true;
  bool _openingTransaction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeSubscription = _shakeDetector.shakes.listen((_) {
      if (_appResumed &&
          (_shakeSettings?.enabled ?? false) &&
          !_openingTransaction &&
          _homeRouteIsCurrent) {
        unawaited(_openAddTransaction());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<ShakeSettingsController>();
    if (!identical(_shakeSettings, settings)) {
      _shakeSettings?.removeListener(_syncShakeListening);
      _shakeSettings = settings;
      settings.addListener(_syncShakeListening);
    }
    // Register a dependency on the route's current status.
    _homeRoute = ModalRoute.of(context);
    _syncShakeListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _syncShakeListening();
  }

  bool get _homeRouteIsCurrent => _homeRoute?.isCurrent == true;

  void _syncShakeListening() {
    if (!mounted) return;
    if (_appResumed &&
        (_shakeSettings?.enabled ?? false) &&
        !_openingTransaction &&
        _homeRouteIsCurrent) {
      _shakeDetector.start();
    } else {
      unawaited(_shakeDetector.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shakeSettings?.removeListener(_syncShakeListening);
    unawaited(_shakeSubscription?.cancel());
    unawaited(_shakeDetector.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final compact = width < 360;
    final horizontalPadding = compact ? 10.0 : 14.0;
    final centerGap = compact ? 58.0 : 76.0;
    final navHeight = compact ? 68.0 : 72.0;

    final screens = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: List.generate(screens.length, (index) {
          final selected = index == _currentIndex;

          return IgnorePointer(
            ignoring: !selected,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: AnimatedScale(
                scale: selected ? 1 : 0.985,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: screens[index],
              ),
            ),
          );
        }),
      ),

      // BLUR BACKGROUND UNDER NAVIGATION
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              10,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.82 : 0.76,
              ),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.38,
                  ),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: compact ? 80 : 86,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: navHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha:
                                theme.brightness == Brightness.dark
                                    ? 0.88
                                    : 0.92,
                          ),
                          borderRadius: BorderRadius.circular(
                            compact ? 24 : 28,
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.24
                                        : 0.07,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _NavItem(
                              compact: compact,
                              selected: _currentIndex == 0,
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home_rounded,
                              label: 'Главная',
                              onTap: () => _select(0),
                            ),
                            _NavItem(
                              compact: compact,
                              selected: _currentIndex == 1,
                              icon: Icons.receipt_long_outlined,
                              selectedIcon: Icons.receipt_long_rounded,
                              label: 'Операции',
                              onTap: () => _select(1),
                            ),

                            SizedBox(width: centerGap),

                            _NavItem(
                              compact: compact,
                              selected: _currentIndex == 2,
                              icon: Icons.auto_graph_outlined,
                              selectedIcon: Icons.auto_graph_rounded,
                              label: 'Аналитика',
                              onTap: () => _select(2),
                            ),
                            _NavItem(
                              compact: compact,
                              selected: _currentIndex == 3,
                              icon: Icons.grid_view_outlined,
                              selectedIcon: Icons.grid_view_rounded,
                              label: 'Ещё',
                              onTap: () => _select(3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Center(
                        child: _AddButton(
                          compact: compact,
                          onTap: _openAddTransaction,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _select(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openAddTransaction() async {
    if (_openingTransaction || !_homeRouteIsCurrent) return;
    _openingTransaction = true;
    _syncShakeListening();

    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const AddTransactionScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } finally {
      _openingTransaction = false;
      if (mounted) _syncShakeListening();
    }
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const _AddButton({required this.onTap, required this.compact});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final size = widget.compact ? 54.0 : 60.0;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });

        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _pressed ? 0.90 : 1,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
              width: widget.compact ? 5 : 6,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Icon(
            Icons.add_rounded,
            color: theme.colorScheme.onPrimary,
            size: widget.compact ? 27 : 30,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool compact;
  final bool selected;

  final IconData icon;
  final IconData selectedIcon;

  final String label;

  final VoidCallback onTap;

  const _NavItem({
    required this.compact,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: selected ? (compact ? 34 : 38) : (compact ? 28 : 30),
                height: compact ? 29 : 31,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.10)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    size: selected ? (compact ? 19 : 21) : (compact ? 18 : 20),
                    color:
                        selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 3),

              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    child: Text(label, maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
