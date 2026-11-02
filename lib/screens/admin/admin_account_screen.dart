import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import '../auth/server_sheet.dart';
import 'security_logs_screen.dart';
import 'staff_screen.dart';

/// The signed-in staff member: login information, privileges, security,
/// and (for owners) staff administration.
class AdminAccountScreen extends StatelessWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user;
    if (u == null) return const SizedBox();
    final exp = u.tokenExpires == null ? null : parseDateTime(u.tokenExpires!);
    final privs = u.isOwner ? Priv.all : u.privileges;

    final left = <Widget>[
      AppCard(
        child: Row(children: [
          Avatar(u.name, size: 64, accent: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, style: T.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [RoleBadge(u.staffRole ?? 'Staff'), const SizedBox(width: 8), Flexible(child: Text(u.email, style: T.small, overflow: TextOverflow.ellipsis))]),
            ]),
          ),
          Btn('Edit', style: BtnStyle.secondary, expand: false, height: 40, onTap: () => sheet(context, const EditProfileSheet())),
        ]),
      ),
      const SectionLabel('Sign-in information', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.login_rounded, label: 'This sign-in${u.lastLoginIp == null ? '' : ' · ${u.lastLoginIp}'}', value: fmtStamp(u.lastLoginAt)),
          InfoRow(
            icon: Icons.history_rounded,
            label: 'Previous sign-in${u.previousLoginIp == null ? '' : ' · ${u.previousLoginIp}'}',
            value: fmtStamp(u.previousLoginAt),
          ),
          InfoRow(icon: Icons.timer_outlined, label: 'Session ends (then sign in again)', value: exp == null ? '—' : fmtStamp(u.tokenExpires)),
          InfoRow(icon: Icons.bedtime_outlined, label: 'Automatic sign-out', value: 'After ${Security.staffIdleMinutes} idle minutes'),
        ]),
      ),
      const SectionLabel('Your privileges', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.isOwner ? 'Owners always have every privilege.' : '${privs.length} of ${Priv.all.length} — set by the hotel owner.', style: T.small),
          const SizedBox(height: 8),
          PrivilegeList(privileges: privs),
        ]),
      ),
    ];

    final right = <Widget>[
      const SectionLabel('Security', padding: EdgeInsets.fromLTRB(0, 0, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.password_rounded, label: 'Signs out your other devices', value: 'Change password', onTap: () => ChangePasswordSheet.open(context)),
          InfoRow(icon: Icons.manage_history_rounded, label: 'Where and when you signed in', value: 'My sign-ins', onTap: () => sheet(context, const MyLoginsSheet())),
        ]),
      ),
      if (s.can(Priv.staffManage)) ...[
        const SectionLabel('Administration', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            InfoRow(
              icon: Icons.badge_outlined,
              label: '${s.security.staffActive} active · ${s.security.staffDisabled} disabled',
              value: 'Staff & privileges',
              onTap: () => go(context, const StaffScreen()),
            ),
            InfoRow(
              icon: Icons.gpp_maybe_outlined,
              label: '${s.security.failed24h} failed in the last 24 hours',
              value: 'Login activity',
              onTap: () => go(context, const LoginActivityScreen()),
            ),
            InfoRow(icon: Icons.fact_check_outlined, label: 'Who changed what', value: 'Audit log', onTap: () => go(context, const AuditLogScreen())),
          ]),
        ),
      ],
      const SectionLabel('Appearance', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      const ThemePicker(),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InfoRow(
          icon: Icons.dns_rounded,
          label: s.apiUrl,
          value: 'Database',
          onTap: () => ServerSheet.open(context),
        ),
      ),
      const SizedBox(height: 16),
      Btn('Log out', style: BtnStyle.danger, icon: Icons.logout_rounded, onTap: () async {
        final ok = await confirmDialog(context, title: 'Log out?', message: 'You are signed in as ${u.name}.', confirm: 'Log out', danger: true);
        if (ok && context.mounted) await AppScope.read(context).logout();
      }),
    ];

    return Column(children: [
      PageHeader(title: 'Account', subtitle: '${u.staffRole ?? 'Staff'} · sign-in & privileges'),
      Expanded(
        child: SplitList(left: left, right: [const SizedBox(height: 22), ...right], padding: const EdgeInsets.fromLTRB(20, 0, 20, 28)),
      ),
    ]);
  }
}
