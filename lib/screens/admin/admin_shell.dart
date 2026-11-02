import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'admin_account_screen.dart';
import 'admin_bookings_screen.dart';
import 'calendar_screen.dart';
import 'guests_screen.dart';
import 'manage_rooms_screen.dart';
import 'today_screen.dart';

/// One admin tab and the privilege needed to see it.
class _Tab {
  const _Tab(this.id, this.item, this.page, [this.priv]);
  final String id;
  final NavItem item;
  final Widget page;
  final String? priv;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  /// Switch tab by id: 'today', 'bookings', 'guests', 'rooms', 'calendar'.
  static void goTab(BuildContext context, String id, {int? bookingsFilter}) =>
      context.findAncestorStateOfType<AdminShellState>()?.setTabId(id, bookingsFilter: bookingsFilter);

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
  String current = 'today';
  final bookingsKey = GlobalKey<AdminBookingsScreenState>();

  void setTabId(String id, {int? bookingsFilter}) {
    setState(() => current = id);
    if (bookingsFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => bookingsKey.currentState?.setFilter(bookingsFilter));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = [
      const _Tab('today', NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Today'), TodayScreen()),
      _Tab('bookings', NavItem(Icons.list_alt_outlined, Icons.list_alt_rounded, 'Bookings', badge: s.pending.length), AdminBookingsScreen(key: bookingsKey),
          Priv.bookingsView),
      const _Tab('guests', NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Guests'), GuestsScreen(), Priv.guestsView),
      const _Tab('rooms', NavItem(Icons.bed_outlined, Icons.bed_rounded, 'Rooms'), ManageRoomsScreen(), Priv.roomsManage),
      const _Tab('calendar', NavItem(Icons.event_note_outlined, Icons.event_note_rounded, 'Calendar'), CalendarScreen(), Priv.bookingsView),
      const _Tab('account', NavItem(Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded, 'Account'), AdminAccountScreen()),
    ];
    // only the tabs this staff member is allowed to use
    final tabs = all.where((t) => t.priv == null || s.can(t.priv!)).toList();
    var index = tabs.indexWhere((t) => t.id == current);
    if (index < 0) index = 0;

    return ShellScaffold(
      index: index,
      onTap: (i) => setTabId(tabs[i].id),
      items: [for (final t in tabs) t.item],
      railFooter: Pressable(
        onTap: () => setTabId('account'),
        child: Avatar(s.user?.name ?? '?', size: 40, accent: true),
      ),
      body: FadeIndexedStack(
        index: index,
        children: [for (var i = 0; i < tabs.length; i++) HeroMode(enabled: i == index, child: tabs[i].page)],
      ),
    );
  }
}

/// The next step a front-desk user can take on a booking.
class NextStep {
  const NextStep(this.label, this.status);
  final String label, status;

  static NextStep? of(Booking b) {
    switch (b.status) {
      case BookingStatus.pending:
        return const NextStep('Confirm', BookingStatus.confirmed);
      case BookingStatus.confirmed:
        return b.checkIn.isAfter(today()) ? null : const NextStep('Check in', BookingStatus.checkedIn);
      case BookingStatus.checkedIn:
        return const NextStep('Check out', BookingStatus.checkedOut);
    }
    return null;
  }
}

/// "Decline | Confirm" / "Check in" / "Check out" buttons for a booking.
/// Hidden for staff without the bookings.manage privilege.
class BookingActions extends StatefulWidget {
  const BookingActions({super.key, required this.booking, this.compact = true});
  final Booking booking;
  final bool compact;
  @override
  State<BookingActions> createState() => _BookingActionsState();
}

class _BookingActionsState extends State<BookingActions> {
  String? busy;

  Future<void> _run(String status, String done) async {
    setState(() => busy = status);
    await attempt(context, () => AppScope.read(context).setStatus(widget.booking, status), success: done);
    if (mounted) setState(() => busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = widget.booking;
    final step = NextStep.of(b);
    final h = widget.compact ? 42.0 : 52.0;
    if (step == null || !s.can(Priv.bookingsManage)) {
      if (b.status == BookingStatus.confirmed && b.checkIn.isAfter(today())) {
        return Text('Arrives ${fmtRelative(b.checkIn)}', style: TextStyle(fontSize: 12.5, color: C.muted));
      }
      if (step != null) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
          const SizedBox(width: 4),
          Text('View only', style: TextStyle(fontSize: 12.5, color: C.muted)),
        ]);
      }
      return const SizedBox.shrink();
    }
    final decline = Btn('Decline', style: BtnStyle.secondary, expand: !widget.compact, height: h, loading: busy == BookingStatus.cancelled, onTap: () async {
      final ok = await confirmDialog(context,
          title: 'Decline ${b.code}?', message: '${b.guestName} · ${b.roomName}. The guest will see it as cancelled.', confirm: 'Decline', danger: true);
      if (ok && mounted) await _run(BookingStatus.cancelled, 'Booking declined');
    });
    final main = Btn(step.label,
        expand: !widget.compact,
        height: h,
        loading: busy == step.status,
        onTap: () => _run(step.status, '${b.code} · ${BookingStatus.label(step.status).toLowerCase()}'));
    final hasDecline = b.status == BookingStatus.pending;
    return Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max, children: [
      if (hasDecline) ...[widget.compact ? decline : Expanded(child: decline), const SizedBox(width: 8)],
      widget.compact ? main : Expanded(flex: 2, child: main),
    ]);
  }
}
