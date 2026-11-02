import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';

/// Every sign-in attempt (staff + guests), newest first. Owner / staff.manage only.
class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});
  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  int filter = 0; // 0 all, 1 failed, 2 staff

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sum = s.security;
    final list = s.loginEvents.where((e) => switch (filter) { 1 => !e.success, 2 => e.portal == 'staff', _ => true }).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BackHeader(title: 'Login activity'),
          Expanded(
            child: RefreshIndicator(
              color: C.accent,
              backgroundColor: C.card,
              onRefresh: s.refresh,
              child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
                AdaptiveGrid(minItemWidth: 150, maxColumns: 4, children: [
                  _Num(sum.failed24h, 'Failed sign-ins (24 h)', warn: true),
                  _Num(sum.lockedAccounts, 'Accounts locked now', warn: true),
                  _Num(sum.activeSessions, 'Staff sessions open'),
                  _Num(sum.staffDisabled, 'Disabled staff'),
                ]),
                const SizedBox(height: 6),
                FilterChips(
                  options: ['All (${s.loginEvents.length})', 'Failed (${s.loginEvents.where((e) => !e.success).length})', 'Staff only'],
                  selected: filter,
                  onSelect: (i) => setState(() => filter = i),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: ValueKey('f$filter'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePad(context, maxWidth: 900)),
                    child: list.isEmpty
                        ? const EmptyState(icon: Icons.verified_user_outlined, title: 'Nothing here', text: 'No sign-in attempts match this filter.')
                        : AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Column(children: [
                              for (var i = 0; i < list.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: C.line),
                                FadeSlideIn(index: i, child: LoginEventTile(list[i])),
                              ],
                            ]),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text('After 5 wrong passwords in 15 minutes an account is locked for 15 minutes. Showing the latest 100 attempts.',
                      style: T.small, textAlign: TextAlign.center),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.value, this.label, {this.warn = false});
  final int value;
  final String label;
  final bool warn;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedNumber(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: warn && value > 0 ? C.accent : C.text)),
          Text(label, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

/// Who did what — every staff action is written here by the server.
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  static IconData _icon(String action) {
    if (action.startsWith('auth.')) return Icons.key_rounded;
    if (action.startsWith('booking.')) return Icons.receipt_long_rounded;
    if (action.startsWith('room.') || action.startsWith('extra.')) return Icons.bed_outlined;
    if (action.startsWith('calendar.')) return Icons.event_busy_outlined;
    if (action.startsWith('staff.')) return Icons.badge_outlined;
    return Icons.history_rounded;
  }

  static String _label(String action) => switch (action) {
        'auth.login' => 'Signed in',
        'auth.password' => 'Changed password',
        'booking.confirm' => 'Confirmed a booking',
        'booking.decline' => 'Declined a booking',
        'booking.cancel' => 'Cancelled a booking',
        'booking.check_in' => 'Checked a guest in',
        'booking.check_out' => 'Checked a guest out',
        'booking.note' => 'Edited a staff note',
        'room.update' => 'Edited a room type',
        'room.create' => 'Added a room type',
        'room.delete' => 'Deleted a room type',
        'room.units' => 'Changed room inventory',
        'extra.save' => 'Saved an extra',
        'extra.delete' => 'Deleted an extra',
        'calendar.close' => 'Closed a day',
        'calendar.open' => 'Re-opened a day',
        'staff.create' => 'Added a staff account',
        'staff.update' => 'Changed a staff account',
        _ => action,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.audit;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BackHeader(title: 'Audit log'),
          Expanded(
            child: RefreshIndicator(
              color: C.accent,
              backgroundColor: C.card,
              onRefresh: s.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(sidePad(context, maxWidth: 900), 4, sidePad(context, maxWidth: 900), 28),
                children: [
                  if (list.isEmpty) const EmptyState(icon: Icons.fact_check_outlined, title: 'No activity yet', text: 'Staff actions will appear here.'),
                  if (list.isNotEmpty)
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: C.line),
                          FadeSlideIn(index: i, child: _AuditRow(list[i])),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow(this.a);
  final AuditEntry a;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(9)),
            child: Icon(AuditLogScreen._icon(a.action), size: 18, color: C.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.userName} · ${AuditLogScreen._label(a.action)}', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (a.details.isNotEmpty) Text(a.details, style: T.small, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Text(fmtStamp(a.createdAt), style: T.small),
        ]),
      );
}
