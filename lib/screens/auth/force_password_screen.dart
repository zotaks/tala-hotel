import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';

/// Shown to staff who still have a default or reset password.
/// The dashboard stays locked (also on the server) until they choose their own.
class ForcePasswordScreen extends StatefulWidget {
  const ForcePasswordScreen({super.key});
  @override
  State<ForcePasswordScreen> createState() => _ForcePasswordScreenState();
}

class _ForcePasswordScreenState extends State<ForcePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    for (final c in [current, next, again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final problem = PasswordRules.check(next.text);
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    if (next.text != again.text) {
      toast(context, 'The new passwords don\'t match', error: true);
      return;
    }
    setState(() => busy = true);
    await attempt(context, () => AppScope.read(context).changePassword(current.text, next.text), success: 'Password set. Welcome!');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).user;
    final items = <Widget>[
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: C.note, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.lock_reset_rounded, color: C.accent, size: 28),
      ),
      const SizedBox(height: 18),
      Text('Set your own password', style: T.h1),
      const SizedBox(height: 6),
      Text(
        'Hi ${u?.name.split(' ').first ?? ''}! Your account is using a default or temporary password. '
        'Choose a new one to open the staff dashboard. Nobody else — not even the owner — will know it.',
        style: T.bodyMuted,
      ),
      const SizedBox(height: 24),
      Field(label: 'Current (temporary) password', controller: current, obscure: true, autofill: const [AutofillHints.password]),
      Field(label: 'New password', controller: next, obscure: true, autofill: const [AutofillHints.newPassword], onChanged: (_) => setState(() {})),
      PasswordStrength(next.text),
      Field(label: 'Type the new password again', controller: again, obscure: true),
      const SizedBox(height: 4),
      Btn('Save and continue', icon: Icons.lock_outline_rounded, loading: busy, onTap: _save),
      const SizedBox(height: 14),
      Center(
        child: Pressable(
          onTap: () => AppScope.read(context).logout(),
          child: Text('Log out', style: TextStyle(fontWeight: FontWeight.w700, color: C.muted)),
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: sidePad(context, maxWidth: 480), vertical: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < items.length; i++) FadeSlideIn(index: i, child: items[i]),
            ]),
          ),
        ),
      ),
    );
  }
}
