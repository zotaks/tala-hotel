import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';

/// Owner / staff.manage: every staff account with its role and privileges.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.staff;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BackHeader(
            title: 'Staff & privileges',
            trailing: SquareIconButton(icon: Icons.person_add_alt_1_rounded, onTap: () => go(context, const StaffEditScreen())),
          ),
          Expanded(
            child: RefreshIndicator(
              color: C.accent,
              backgroundColor: C.card,
              onRefresh: s.refresh,
              child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 28), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text('Decide what each person can see and do. Disabling an account signs it out everywhere.', style: T.bodyMuted),
                ),
                AdaptiveGrid(children: [
                  for (var i = 0; i < list.length; i++)
                    FadeSlideIn(index: i, child: _StaffCard(user: list[i], me: list[i].id == s.user?.id)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.user, required this.me});
  final AppUser user;
  final bool me;
  @override
  Widget build(BuildContext context) {
    final u = user;
    final count = u.isOwner ? Priv.all.length : u.privileges.length;
    return AppCard(
      dim: !u.active,
      onTap: () => go(context, StaffEditScreen(user: u)),
      child: Row(children: [
        Avatar(u.name, size: 46, accent: u.isOwner),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(me ? '${u.name} (you)' : u.name, style: T.title, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              RoleBadge(u.staffRole ?? 'Custom'),
            ]),
            const SizedBox(height: 3),
            Text(u.email, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
              u.active
                  ? 'Last sign-in ${fmtStamp(u.lastLoginAt)} · $count/${Priv.all.length} privileges${u.activeSessions > 0 ? ' · signed in now' : ''}'
                  : 'Disabled — cannot sign in',
              style: TextStyle(fontSize: 12, color: u.active ? C.muted : C.danger),
              maxLines: 2,
            ),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: C.muted),
      ]),
    );
  }
}

/// Add a staff member or change role / privileges / status / password.
class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen({super.key, this.user});
  final AppUser? user;
  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  late final AppUser? u = widget.user;
  late final name = TextEditingController(text: u?.name ?? '');
  late final email = TextEditingController(text: u?.email ?? '');
  late final phone = TextEditingController(text: u?.phone ?? '');
  final password = TextEditingController();
  late String role = u?.staffRole ?? 'Front desk';
  late Set<String> privs = {...(u == null ? Priv.preset('Front desk') : (u!.isOwner ? Priv.all : u!.privileges))};
  late bool active = u?.active ?? true;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, email, phone, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setRole(String r) => setState(() {
        role = r;
        if (r != 'Custom') privs = {...Priv.preset(r)};
      });

  Future<void> _save() async {
    if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
      toast(context, 'Enter a name and an email', error: true);
      return;
    }
    if (u == null && password.text.isEmpty) {
      toast(context, 'Set a starting password', error: true);
      return;
    }
    if (password.text.isNotEmpty) {
      final problem = PasswordRules.check(password.text);
      if (problem != null) {
        toast(context, problem, error: true);
        return;
      }
    }
    // sensitive change → confirm it's really the owner
    final ok = await askPassword(context, action: u == null ? 'add a staff account' : 'change ${u!.name}\'s account');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    final saved = await attempt(
      context,
      () => AppScope.read(context).saveStaff(StaffDraft(
            id: u?.id ?? 0,
            name: name.text,
            email: email.text,
            phone: phone.text,
            staffRole: role,
            privileges: role == 'Owner' ? Priv.all : Priv.all.where(privs.contains).toList(),
            active: active,
            password: password.text,
          )),
      success: u == null ? 'Staff account created' : 'Changes saved',
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final self = u != null && u!.id == s.user?.id;
    final iAmOwner = s.user?.isOwner ?? false;
    final roles = Priv.roles.where((r) => r != 'Owner' || iAmOwner).toList();
    final ownerLocked = role == 'Owner';

    final left = <Widget>[
      if (self)
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: NoteBox(title: 'This is you', text: 'You can\'t change your own role, privileges or status — ask another owner.'),
        ),
      Field(label: 'Full name', hint: 'e.g. Joy Fernandez', controller: name),
      Field(label: 'Work email (used to sign in)', hint: 'e.g. joy@talahotel.ph', controller: email, keyboard: TextInputType.emailAddress),
      Field(label: 'Mobile number', controller: phone, keyboard: TextInputType.phone),
      Field(
        label: u == null ? 'Starting password' : 'Reset password (optional)',
        hint: u == null ? 'They should change it after signing in' : 'Leave blank to keep their password',
        controller: password,
        obscure: true,
        onChanged: (_) => setState(() {}),
      ),
      PasswordStrength(password.text),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: active,
          onChanged: self ? null : (v) => setState(() => active = v),
          title: Text('Account active', style: T.title),
          subtitle: Text(active ? 'Can sign in and open the dashboard' : 'Blocked — signed out everywhere', style: T.small),
        ),
      ),
    ];

    final right = <Widget>[
      Text('Role', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        for (var k = 0; k < roles.length; k++) ...[
          if (k > 0) const SizedBox(width: 6),
          Expanded(
            child: ChoiceTile(title: roles[k], selected: role == roles[k], height: 46, disabled: self, onTap: () => _setRole(roles[k])),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      Text(
        switch (role) {
          'Owner' => 'Full control, including staff accounts. Owners always have every privilege.',
          'Manager' => 'Runs the hotel: bookings, rooms, prices, calendar and reports — but not staff accounts.',
          'Front desk' => 'Day-to-day desk work: view, confirm, check in and check out bookings; see guests.',
          _ => 'Pick exactly which privileges this person gets.',
        },
        style: T.small,
      ),
      const SectionLabel('Privileges', padding: EdgeInsets.fromLTRB(0, 18, 0, 8)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          for (final p in Priv.all)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: ownerLocked || privs.contains(p),
              activeColor: C.accent,
              checkColor: Colors.black,
              onChanged: (ownerLocked || self)
                  ? null
                  : (v) => setState(() {
                        v == true ? privs.add(p) : privs.remove(p);
                        role = 'Custom';
                      }),
              title: Text(Priv.labels[p] ?? p, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.text)),
              subtitle: Text(p, style: TextStyle(fontSize: 11, color: C.faint)),
            ),
        ]),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BackHeader(title: u == null ? 'New staff account' : u!.name),
          Expanded(child: SplitList(left: left, right: [if (!Screen.wide(context)) const SizedBox(height: 8), ...right])),
        ]),
      ),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          Expanded(child: Btn('Cancel', style: BtnStyle.secondary, onTap: () => Navigator.of(context).pop())),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Btn(u == null ? 'Create account' : 'Save changes', icon: Icons.lock_outline_rounded, loading: busy, onTap: _save)),
        ]),
      ),
    );
  }
}
