import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'booking_detail_screen.dart';
import 'customer_shell.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = tab == 0 ? s.upcoming : s.past;
    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.card,
      onRefresh: s.refresh,
      child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        PageHeader(title: 'Bookings', subtitle: s.upcoming.isEmpty ? 'No upcoming stays' : plural(s.upcoming.length, 'upcoming stay')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentToggle(options: const ['Upcoming', 'Past'], index: tab, onChanged: (i) => setState(() => tab = i)),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey('tab$tab-${list.length}'),
          child: Column(children: [
            if (list.isEmpty)
              EmptyState(
                icon: tab == 0 ? Icons.luggage_outlined : Icons.history_rounded,
                title: tab == 0 ? 'No upcoming stays' : 'No past stays yet',
                text: tab == 0 ? 'Pick a room and your booking will show up here.' : 'Completed and cancelled bookings appear here.',
                action: tab == 0 ? 'Browse rooms' : null,
                onAction: () => CustomerShell.goTab(context, 1),
              ),
            AdaptiveGrid(children: [
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  index: i,
                  child: BookingCard(booking: list[i], onTap: () => go(context, BookingDetailScreen(bookingId: list[i].id))),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
