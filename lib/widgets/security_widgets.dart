import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';
import 'motion.dart';

/// System / Light / Dark selector.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    const opts = [
      (ThemeMode.system, 'System', 'Follow phone'),
      (ThemeMode.light, 'Light', 'Bright'),
      (ThemeMode.dark, 'Dark', 'Night'),
    ];
    return Row(children: [
      for (var i = 0; i < opts.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: ChoiceTile(
            title: opts[i].$2,
            subtitle: opts[i].$3,
            selected: s.themeMode == opts[i].$1,
            onTap: () => AppScope.read(context).setThemeMode(opts[i].$1),
          ),
        ),
      ],
    ]);
  }
}

/// Small sun/moon button that flips between light and dark.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.overPhoto = false});
  final bool overPhoto;
  @override
  Widget build(BuildContext context) => SquareIconButton(
        icon: C.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: overPhoto ? const Color(0xAA161618) : null,
        iconColor: overPhoto ? Colors.white : null,
        onTap: () => AppScope.read(context).setThemeMode(C.isDark ? ThemeMode.light : ThemeMode.dark),
      );
}

/// Animated 4-step strength bar under password fields.
class PasswordStrength extends StatelessWidget {
  const PasswordStrength(this.password, {super.key});
  final String password;
  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox(height: 4);
    final score = PasswordRules.score(password);
    final problem = PasswordRules.check(password);
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final color = score <= 1 ? C.danger : (score == 2 ? C.accent : C.text);
    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: Motion.medium,
                height: 4,
                decoration: BoxDecoration(color: i < score ? color : C.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(problem ?? 'Password strength: ${labels[score]}', style: TextStyle(fontSize: 12, color: problem != null ? C.danger : C.muted)),
      ]),
    );
  }
}

/// Asks for the password again before a sensitive action. Returns true when it was correct.
Future<bool> askPassword(BuildContext context, {required String action}) async {
  final ok = await sheet<bool>(context, _ReauthSheet(action: action));
  return ok ?? false;
}

class _ReauthSheet extends StatefulWidget {
  const _ReauthSheet({required this.action});
  final String action;
  @override
  State<_ReauthSheet> createState() => _ReauthSheetState();
}

class _ReauthSheetState extends State<_ReauthSheet> {
  final pw = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    pw.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.read(context).verifyPassword(pw.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.note, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_outline_rounded, color: C.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Confirm it\'s you', style: T.h2)),
          ]),
          const SizedBox(height: 8),
          Text('Enter your password to ${widget.action}.', style: T.bodyMuted),
          const SizedBox(height: 16),
          TextField(
            controller: pw,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(hintText: 'Your password', errorText: error),
          ),
          const SizedBox(height: 16),
          Btn('Confirm', loading: busy, onTap: _go),
        ]),
      );
}

/// Change password (current + new + confirm), used by guests and staff.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});
  static Future<void> open(BuildContext context) => sheet(context, const ChangePasswordSheet());
  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
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
    final ok = await attempt(context, () => AppScope.read(context).changePassword(current.text, next.text),
        success: 'Password changed. Other devices were signed out.');
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Change password', style: T.h2),
          const SizedBox(height: 4),
          Text('Use at least 8 characters with letters and numbers.', style: T.bodyMuted),
          const SizedBox(height: 18),
          Field(label: 'Current password', controller: current, obscure: true, autofill: const [AutofillHints.password]),
          Field(label: 'New password', controller: next, obscure: true, autofill: const [AutofillHints.newPassword], onChanged: (_) => setState(() {})),
          PasswordStrength(next.text),
          Field(label: 'Type the new password again', controller: again, obscure: true),
          Btn('Change password', loading: busy, onTap: _save),
        ]),
      );
}

/// One row of login history.
class LoginEventTile extends StatelessWidget {
  const LoginEventTile(this.e, {super.key, this.showWho = true});
  final LoginEvent e;
  final bool showWho;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: e.success ? C.card2 : C.dangerBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(e.success ? Icons.login_rounded : Icons.gpp_maybe_outlined, size: 18, color: e.success ? C.text : C.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(showWho ? (e.userName ?? e.email) : e.reasonLabel, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                [if (showWho) e.reasonLabel, '${e.portal == 'staff' ? 'Staff' : 'Guest'} login', e.ip, if (e.userAgent.isNotEmpty) e.userAgent].join(' · '),
                style: T.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(fmtStamp(e.createdAt), style: T.small),
        ]),
      );
}

/// Labelled list of every privilege with a tick or a cross.
class PrivilegeList extends StatelessWidget {
  const PrivilegeList({super.key, required this.privileges});
  final List<String> privileges;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final p in Priv.all)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(privileges.contains(p) ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                  size: 18, color: privileges.contains(p) ? C.accent : C.faint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(Priv.labels[p] ?? p,
                    style: TextStyle(fontSize: 13.5, color: privileges.contains(p) ? C.text : C.faint, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]);
}

/// The signed-in user's own recent sign-ins (guests and staff).
class MyLoginsSheet extends StatelessWidget {
  const MyLoginsSheet({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Recent sign-ins', style: T.h2),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text("Don't recognise one? Change your password right away.", style: T.small),
          ),
          Expanded(
            child: FutureBuilder<List<LoginEvent>>(
              future: AppScope.read(context).myLogins(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('${snap.error}', style: T.bodyMuted));
                if (!snap.hasData) return Center(child: CircularProgressIndicator(color: C.accent));
                final list = snap.data!;
                if (list.isEmpty) return Center(child: Text('No sign-ins yet.', style: T.bodyMuted));
                return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                  for (var i = 0; i < list.length; i++) FadeSlideIn(index: i, child: LoginEventTile(list[i], showWho: false)),
                ]);
              },
            ),
          ),
        ]),
      );
}

/// "OWNER" / "MANAGER" / "FRONT DESK" tag.
class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});
  final String role;
  @override
  Widget build(BuildContext context) {
    final owner = role == 'Owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: owner ? C.accent : C.card2, borderRadius: BorderRadius.circular(5)),
      child: Text(role.toUpperCase(),
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: owner ? Colors.black : C.text)),
    );
  }
}

/// Edit your own name and mobile number.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController name, phone;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final u = AppScope.read(context).user!;
    name = TextEditingController(text: u.name);
    phone = TextEditingController(text: u.phone);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit profile', style: T.h2),
          const SizedBox(height: 18),
          Field(label: 'Full name', controller: name),
          Field(label: 'Mobile number', controller: phone, keyboard: TextInputType.phone),
          Btn('Save changes', loading: busy, onTap: () async {
            if (name.text.trim().isEmpty) {
              toast(context, 'Name can\'t be empty', error: true);
              return;
            }
            setState(() => busy = true);
            final ok = await attempt(context, () => AppScope.read(context).updateMe(name: name.text, phone: phone.text), success: 'Profile updated');
            if (!context.mounted || !mounted) return;
            setState(() => busy = false);
            if (ok) Navigator.of(context).pop();
          }),
        ]),
      );
}
