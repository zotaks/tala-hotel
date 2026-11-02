import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../models.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool agree = false, busy = false;

  @override
  void dispose() {
    for (final c in [name, phone, email, pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty || pass.text.isEmpty) {
      toast(context, 'Please fill in your name, email and password', error: true);
      return;
    }
    final problem = PasswordRules.check(pass.text);
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    if (!agree) {
      toast(context, 'Please agree to the privacy notice', error: true);
      return;
    }
    setState(() => busy = true);
    final ok = await attempt(context,
        () => AppScope.read(context).register(name: name.text, email: email.text, phone: phone.text, password: pass.text));
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      toast(context, 'Welcome to Tala, ${name.text.trim().split(' ').first}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      Text('Tell us about you', style: T.h1),
      const SizedBox(height: 4),
      Text('It only takes a minute — then pick your room.', style: T.bodyMuted),
      const SizedBox(height: 24),
      Field(label: 'Full name', hint: 'e.g. Juan Dela Cruz', controller: name, autofill: const [AutofillHints.name]),
      Field(label: 'Mobile number', hint: 'e.g. 0917 123 4567', controller: phone, keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]),
      Field(label: 'Email', hint: 'e.g. juan.delacruz@gmail.com', controller: email, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
      Field(
        label: 'Password',
        hint: 'At least 8 characters, letters + numbers',
        controller: pass,
        obscure: true,
        autofill: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() {}),
      ),
      PasswordStrength(pass.text),
      Pressable(
        onTap: () => setState(() => agree = !agree),
        scale: 0.99,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: Motion.medium,
            curve: Curves.easeOutBack,
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: agree ? C.accent : Colors.transparent,
              border: Border.all(color: agree ? C.accent : C.muted, width: 1.6),
              borderRadius: BorderRadius.circular(5),
            ),
            child: AnimatedScale(
              scale: agree ? 1 : 0,
              duration: Motion.medium,
              curve: Curves.easeOutBack,
              child: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('I agree to the privacy notice. My details are used only to manage my bookings.', style: T.bodyMuted)),
        ]),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const BackHeader(title: 'Create account'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(sidePad(context), 8, sidePad(context), 24),
              children: [for (var i = 0; i < fields.length; i++) FadeSlideIn(index: i, child: fields[i])],
            ),
          ),
          BottomBar(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Btn('Continue', loading: busy, onTap: _submit)),
              const SizedBox(height: 12),
              Pressable(
                onTap: () => Navigator.of(context).pop(),
                child: Text.rich(TextSpan(text: 'Already have an account? ', style: T.small, children: [
                  TextSpan(text: 'Log in', style: TextStyle(color: C.text, fontWeight: FontWeight.w800)),
                ])),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
