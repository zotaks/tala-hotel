import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'screens/admin/admin_shell.dart';
import 'screens/auth/force_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TalaApp());
}

class TalaApp extends StatefulWidget {
  const TalaApp({super.key});
  @override
  State<TalaApp> createState() => _TalaAppState();
}

class _TalaAppState extends State<TalaApp> with WidgetsBindingObserver {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.addListener(_syncTheme);
    state.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.removeListener(_syncTheme);
    state.dispose();
    super.dispose();
  }

  // Phone switched between light/dark while "System" is selected.
  @override
  void didChangePlatformBrightness() => _syncTheme();

  bool get _wantDark => switch (state.themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        _ => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  /// Swaps the colour palette and repaints every screen (including ones underneath).
  void _syncTheme() {
    final dark = _wantDark;
    if (C.isDark == dark) return;
    C.use(dark ? Palette.dark : Palette.light);
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final dark = C.isDark;
    return AppScope(
      state: state,
      child: Listener(
        // any touch counts as activity for the staff auto-logout timer
        onPointerDown: (_) => state.touch(),
        onPointerSignal: (_) => state.touch(),
        behavior: HitTestBehavior.translucent,
        child: MaterialApp(
          title: 'Tala Hotel',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Palette.light),
          darkTheme: buildTheme(Palette.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          // Lets you drag horizontal lists with the mouse in a browser.
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
          ),
          // Uses the full width on phones (portrait + landscape) and tablets;
          // only very wide desktop windows get side margins.
          builder: (context, child) => ColoredBox(
            color: C.backdrop,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: ClipRect(child: child ?? const SizedBox()),
              ),
            ),
          ),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// Shows splash → login → guest app or admin app, cross-fading between them.
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final Widget page;
    if (!s.ready) {
      page = const _Splash(key: ValueKey('splash'));
    } else if (s.user == null) {
      page = const LoginScreen(key: ValueKey('login'));
    } else if (s.user!.isAdmin && s.user!.mustChangePassword) {
      // default / reset password → staff must choose their own before the dashboard opens
      page = ForcePasswordScreen(key: ValueKey('pw${s.user!.id}'));
    } else if (s.user!.isAdmin) {
      page = AdminShell(key: ValueKey('admin${s.user!.id}'));
    } else {
      page = CustomerShell(key: ValueKey('guest${s.user!.id}'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(a), child: child),
      ),
      child: page,
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: v, child: child)),
            child: const Logo(size: 44),
          ),
        ),
      );
}
