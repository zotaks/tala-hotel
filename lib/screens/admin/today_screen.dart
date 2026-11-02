import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import 'admin_booking_detail.dart';
import 'admin_shell.dart';
import 'security_logs_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user;
    if (u == null) return const SizedBox();
    final wide = Screen.wide(context);
    final t = today();
    final canView = s.can(Priv.bookingsView);
    final arriving = s.bookings
        .where((b) => sameDay(b.checkIn, t) && (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed))
        .toList();
    final departing = s.bookings.where((b) => sameDay(b.checkOut, t) && b.status == BookingStatus.checkedIn).toList();
    final movements = [...arriving, ...departing];
    final pending = s.pending;
    final occ = s.occupancyTonight;
    void openBookings(int filter) => AdminShell.goTab(context, 'bookings', bookingsFilter: filter);

    // -------------------------------------------------- signed-in info + security
    final signedIn = _SignedInCard(user: u, onTap: () => AdminShell.goTab(context, 'account'));
    final security = s.can(Priv.staffManage) ? _SecurityCard(summary: s.security, onTap: () => go(context, const LoginActivityScreen())) : null;

    // -------------------------------------------------- stats
    final tiles = <Widget>[
      StatTile(value: arriving.length, label: 'Arriving today', onTap: () => openBookings(2)),
      StatTile(value: pending.length, label: 'Waiting to confirm', dot: true, onTap: () => openBookings(1)),
      StatTile(value: s.inHouse.length, label: 'In-house now', onTap: () => openBookings(3)),
      StatTile(value: departing.length, label: 'Checking out today', onTap: () => openBookings(3)),
    ];
    final stats = wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var k = 0; k < tiles.length; k++) ...[if (k > 0) const SizedBox(width: 10), Expanded(child: tiles[k])],
          ])
        : Column(children: [
            Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 10), Expanded(child: tiles[1])]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 10), Expanded(child: tiles[3])]),
          ]);

    final occupancy = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Occupancy tonight', style: T.bodyMuted)),
          AnimatedNumber(occ * 100, format: (v) => '${v.round()}%', style: T.h2),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 8, color: C.card2),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: occ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0).toDouble(), child: Container(height: 8, color: C.accent)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('Revenue this month', style: T.bodyMuted)),
          s.can(Priv.reportsView)
              ? AnimatedNumber(s.revenueThisMonth, format: (v) => peso(v.round()), style: T.title)
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
                  const SizedBox(width: 4),
                  Text('Hidden', style: T.small),
                ]),
        ]),
      ]),
    );

    // -------------------------------------------------- lists
    final pendingSection = Column(children: [
      SectionLabel('Needs your confirmation',
          action: pending.isEmpty ? null : 'See all', onAction: () => openBookings(1), padding: const EdgeInsets.fromLTRB(0, 22, 0, 10)),
      if (pending.isEmpty)
        AppCard(child: Row(children: [Icon(Icons.check_circle_outline_rounded, color: C.muted), const SizedBox(width: 10), Text('All caught up', style: T.bodyMuted)])),
      for (final b in pending.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => go(context, AdminBookingDetail(bookingId: b.id)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b.guestName} · ${b.roomName}', style: T.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('${fmtDay(b.checkIn)} · ${plural(b.nights, 'night')} · ${peso(b.total)}', style: T.small),
                ]),
              ),
              const SizedBox(width: 8),
              BookingActions(booking: b),
            ]),
          ),
        ),
    ]);

    final movementSection = Column(children: [
      const SectionLabel('Arrivals & departures', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      if (movements.isEmpty) AppCard(child: Text('No arrivals or departures left today.', style: T.bodyMuted)),
      if (movements.isNotEmpty)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var k = 0; k < movements.length; k++) ...[
              if (k > 0) Divider(height: 1, color: C.line),
              _Movement(booking: movements[k], arriving: arriving.contains(movements[k])),
            ],
          ]),
        ),
    ]);

    final parts = <Widget>[
      security == null ? signedIn : PairRow(first: signedIn, second: security, spacing: 10),
      if (canView) ...[
        const SizedBox(height: 10),
        stats,
        const SizedBox(height: 10),
        occupancy,
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: pendingSection),
                const SizedBox(width: 16),
                Expanded(child: movementSection),
              ])
            : Column(children: [pendingSection, movementSection]),
      ] else ...[
        const SizedBox(height: 16),
        const NoteBox(title: 'Limited access', text: 'Your account cannot view bookings. Ask the hotel owner if you need more privileges.'),
      ],
      const SizedBox(height: 28),
    ];

    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.card,
      onRefresh: s.refresh,
      child: ListView(children: [
        PageHeader(
          title: 'Today',
          subtitle: fmtLong(t),
          actions: [
            SquareIconButton(icon: Icons.refresh_rounded, onTap: () => attempt(context, s.refresh)),
            const ThemeToggleButton(),
            SquareIconButton(
              icon: Icons.logout_rounded,
              onTap: () async {
                final ok = await confirmDialog(context, title: 'Log out?', message: 'You are signed in as ${u.name}.', confirm: 'Log out', danger: true);
                if (ok && context.mounted) await AppScope.read(context).logout();
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [for (var i = 0; i < parts.length; i++) FadeSlideIn(index: i, child: parts[i])]),
        ),
      ]),
    );
  }
}

/// "Signed in as …" with role, previous sign-in and session expiry.
class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.user, required this.onTap});
  final AppUser user;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final exp = user.tokenExpires == null ? null : parseDateTime(user.tokenExpires!);
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Avatar(user.name, size: 48, accent: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(user.name, style: T.title, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              RoleBadge(user.staffRole ?? 'Staff'),
            ]),
            const SizedBox(height: 4),
            Text('Previous sign-in: ${fmtStamp(user.previousLoginAt)}${user.previousLoginIp == null ? '' : ' · ${user.previousLoginIp}'}',
                style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${user.isOwner ? Priv.all.length : user.privileges.length} of ${Priv.all.length} privileges'
                '${exp == null ? '' : ' · session ends ${fmtTime(exp)}'}', style: T.small),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: C.muted),
      ]),
    );
  }
}

/// Owner-only: failed sign-ins, locked accounts, staff signed in.
class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.summary, required this.onTap});
  final SecuritySummary summary;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    Widget n(int v, String label, {bool warn = false}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedNumber(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: warn && v > 0 ? C.accent : C.text)),
            Text(label, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined, size: 18, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('Security · last 24 hours', style: T.bodyMuted)),
          Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          n(summary.failed24h, 'Failed sign-ins', warn: true),
          n(summary.lockedAccounts, 'Locked now', warn: true),
          n(summary.activeSessions, 'Staff sessions'),
        ]),
      ]),
    );
  }
}

class _Movement extends StatelessWidget {
  const _Movement({required this.booking, required this.arriving});
  final Booking booking;
  final bool arriving;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Pressable(
      onTap: () => go(context, AdminBookingDetail(bookingId: b.id)),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 62,
            child: Text(arriving ? 'IN' : 'OUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: arriving ? C.text : C.muted)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.guestName, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${b.roomName} · ${plural(b.guests, 'guest')}', style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          b.status == BookingStatus.pending ? StatusChip(b.status) : BookingActions(booking: b),
        ]),
      ),
    );
  }
}
