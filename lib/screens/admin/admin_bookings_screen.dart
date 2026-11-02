import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'admin_booking_detail.dart';
import 'admin_shell.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => AdminBookingsScreenState();
}

class AdminBookingsScreenState extends State<AdminBookingsScreen> {
  int filter = 0;
  final q = TextEditingController();

  void setFilter(int f) => setState(() => filter = f);

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  bool _match(Booking b, int f) {
    final t = today();
    return switch (f) {
      1 => b.status == BookingStatus.pending,
      2 => sameDay(b.checkIn, t) && (b.status == BookingStatus.pending || b.status == BookingStatus.confirmed),
      3 => b.status == BookingStatus.checkedIn,
      4 => b.status == BookingStatus.confirmed && b.checkIn.isAfter(t),
      5 => b.status == BookingStatus.checkedOut || b.status == BookingStatus.cancelled,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final query = q.text.trim().toLowerCase();
    var list = s.bookings.where((b) => _match(b, filter)).where((b) {
      if (query.isEmpty) return true;
      return '${b.guestName} ${b.code} ${b.roomName}'.toLowerCase().contains(query);
    }).toList();
    // active ones first, nearest date first
    if (filter != 5) {
      list.sort((a, b) {
        final ra = a.isActive ? 0 : 1, rb = b.isActive ? 0 : 1;
        if (ra != rb) return ra - rb;
        return a.isActive ? a.checkIn.compareTo(b.checkIn) : b.checkIn.compareTo(a.checkIn);
      });
    }
    final counts = [for (var f = 0; f < 6; f++) s.bookings.where((b) => _match(b, f)).length];
    final labels = ['All', 'Pending', 'Arriving today', 'In-house', 'Upcoming', 'Done'];

    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.card,
      onRefresh: s.refresh,
      child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        const PageHeader(title: 'Bookings', subtitle: 'Move each booking to its next step'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Search guest, code or room', prefixIcon: Icon(Icons.search_rounded, color: C.muted)),
          ),
        ),
        FilterChips(
          options: [for (var f = 0; f < labels.length; f++) f == 0 ? labels[f] : '${labels[f]} (${counts[f]})'],
          selected: filter,
          onSelect: setFilter,
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey('f$filter-$query'),
          child: Column(children: [
            if (list.isEmpty) const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here', text: 'No bookings match this filter.'),
            AdaptiveGrid(children: [
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  index: i,
                  child: BookingCard(
                    booking: list[i],
                    showGuest: true,
                    onTap: () => go(context, AdminBookingDetail(bookingId: list[i].id)),
                    footer: NextStep.of(list[i]) == null && list[i].status != BookingStatus.confirmed ? null : BookingActions(booking: list[i]),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
