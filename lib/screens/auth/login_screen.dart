import 'package:flutter/material.dart';

import '../../data/seed_data.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import 'register_screen.dart';
import 'server_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false, hide = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      toast(context, 'Enter your email and password', error: true);
      return;
    }
    setState(() => busy = true);
    final ok = await attempt(context, () => AppScope.read(context).login(email.text, pass.text));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) pass.clear(); // never leave a wrong password in the box
  }

  /// The hotel photo with logo + headline, drawn inside the left panel (landscape) or on top (portrait).
  Widget _hero(BuildContext context, {required bool wide}) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(fit: StackFit.expand, children: [
      TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.12, end: 1.0),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: const NetImage(heroNight, radius: 0),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: wide
              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x11000000), Color(0xCC000000)])
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0x66000000), const Color(0x00000000), C.bg.withAlpha(0xEE)],
                  stops: const [0, 0.45, 1],
                ),
        ),
      ),
      Positioned(
        top: 18 + (wide ? 0 : top),
        left: 20,
        right: 16,
        child: Row(children: [
          const Logo(size: 30, color: Colors.white),
          const Spacer(),
          SquareIconButton(
            icon: Icons.dns_outlined,
            color: const Color(0xAA161618),
            iconColor: Colors.white,
            onTap: () => ServerSheet.open(context),
          ),
          const SizedBox(width: 8),
          const ThemeToggleButton(overPhoto: true),
        ]),
      ),
      Positioned(
        left: 24,
        right: 24,
        bottom: 24,
        child: FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: Text('Your stay in Dagupan,\nbooked in a few taps.',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6, color: wide ? Colors.white : C.text)),
        ),
      ),
    ]);
  }

  Widget _form(BuildContext context, AppState s) {
    final items = <Widget>[
      if (s.signOutReason != null)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: NoteBox(title: 'Signed out', text: s.signOutReason!)),
      if (s.loadError != null && s.rooms.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NoteBox(
            title: "Can't reach the database",
            text: 'Start Apache and MySQL in XAMPP, then tap the server button above to check the address.\n${s.apiUrl}',
          ),
        ),
      Text('Welcome back', style: T.h1),
      const SizedBox(height: 4),
      Text('Log in to book your stay — or to open the hotel dashboard if you are staff.', style: T.bodyMuted),
      const SizedBox(height: 24),
      Field(
        label: 'Email',
        hint: 'you@example.com',
        controller: email,
        keyboard: TextInputType.emailAddress,
        autofill: const [AutofillHints.email],
      ),
      Field(
        label: 'Password',
        hint: 'Enter your password',
        controller: pass,
        obscure: hide,
        autofill: const [AutofillHints.password],
        suffix: IconButton(
          onPressed: () => setState(() => hide = !hide),
          icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: C.muted),
        ),
        trailing: Pressable(
          onTap: () => toast(context, 'Guests: ask the front desk at ${Hotel.phone}. Staff: ask the hotel owner to reset it.'),
          child: Text('Forgot password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.muted)),
        ),
      ),
      const SizedBox(height: 4),
      Btn('Log in', loading: busy, onTap: _login),
      const SizedBox(height: 22),
      Center(
        child: Pressable(
          onTap: () => go(context, const RegisterScreen()),
          child: Text.rich(TextSpan(text: 'New to Tala? ', style: T.bodyMuted, children: [
            TextSpan(text: 'Create an account', style: TextStyle(color: C.text, fontWeight: FontWeight.w800)),
          ])),
        ),
      ),
      const SizedBox(height: 26),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.shield_outlined, size: 16, color: C.faint),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Protected sign-in: 5 wrong passwords lock the account for 15 minutes. Every sign-in is recorded.',
              style: TextStyle(fontSize: 12, color: C.faint, height: 1.35)),
        ),
      ]),
    ];
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < items.length; i++) FadeSlideIn(index: i, child: items[i]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (Screen.wide(context)) {
      // landscape / desktop: photo fills the left panel, form on the right
      return Scaffold(
        body: SafeArea(
          child: Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _hero(context, wide: true)),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 28, 24),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: _form(context, s)),
                ),
              ),
            ),
          ]),
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 300, child: _hero(context, wide: false)),
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), child: _form(context, s)),
        ]),
      ),
    );
  }
}
