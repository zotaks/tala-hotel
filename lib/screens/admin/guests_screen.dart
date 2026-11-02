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

class GuestsScreen extends StatefulWidget {
  const GuestsScreen({super.key});
  @override
  State<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends State<GuestsScreen> {
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final query = q.text.trim().toLowerCase();
    final list = s.guests.where((g) => '${g.user.name} ${g.user.email} ${g.user.phone}'.toLowerCase().contains(query)).toList();
    final inHouseIds = s.inHouse.map((b) => b.userId).toSet();

    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.card,
      onRefresh: s.refresh,
      child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        PageHeader(title: 'Guests', subtitle: '${plural(s.guests.length, 'guest')} · ${inHouseIds.length} in-house'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Search by name, email or phone', prefixIcon: Icon(Icons.search_rounded, color: C.muted)),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [Expanded(child: Text('GUEST', style: T.label)), Text('LAST STAY', style: T.label)]),
        ),
        if (list.isEmpty) const EmptyState(icon: Icons.person_search_rounded, title: 'No guests found', text: 'Try another name.'),
        if (list.isNotEmpty)
          AdaptiveGrid(minItemWidth: 320, children: [
            for (var i = 0; i < list.length; i++)
              FadeSlideIn(
                index: i,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => go(context, GuestDetailScreen(userId: list[i].user.id, name: list[i].user.name)),
                  child: Row(children: [
                    Avatar(list[i].user.name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(list[i].user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                          if (inHouseIds.contains(list[i].user.id)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: C.text, borderRadius: BorderRadius.circular(4)),
                              child: Text('IN-HOUSE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: C.onText)),
                            ),
                          ],
                        ]),
                        Text('${plural(list[i].bookingsCount, 'booking')} · ${list[i].user.email}', style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(_last(list[i]), style: T.small),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ]),
                ),
              ),
          ]),
      ]),
    );
  }

  String _last(GuestSummary g) {
    if (g.lastStay == null) return 'No stays yet';
    final d = parseYmd(g.lastStay!);
    return sameDay(d, today()) ? 'Today' : fmtShort(d);
  }
}

class GuestDetailScreen extends StatelessWidget {
  const GuestDetailScreen({super.key, required this.userId, required this.name});
  final int userId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    GuestSummary? g;
    for (final x in s.guests) {
      if (x.user.id == userId) g = x;
    }
    final bookings = s.bookings.where((b) => b.userId == userId).toList();
    final stays = bookings.where((b) => b.status == BookingStatus.checkedOut).length;
    final parts = <Widget>[
      AppCard(
        child: Row(children: [
          Avatar(name, size: 60, accent: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g?.user.name ?? name, style: T.h2),
              Text(g == null ? 'Guest' : 'Member since ${fmtFull(parseDateTime(g.user.createdAt))}', style: T.small),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: StatTile(value: stays, label: 'Stays')),
        const SizedBox(width: 10),
        Expanded(child: StatTile(value: g?.spent ?? 0, label: 'Spent', format: (v) => peso(v.round()))),
      ]),
      if (g != null) ...[
        const SectionLabel('Contact', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: g.user.email),
            InfoRow(icon: Icons.phone_iphone_rounded, label: 'Mobile', value: g.user.phone.isEmpty ? '—' : g.user.phone),
          ]),
        ),
      ],
      const SectionLabel('Bookings', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
      if (bookings.isEmpty) Text('No bookings yet.', style: T.bodyMuted),
      for (final b in bookings)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BookingCard(booking: b, onTap: () => go(context, AdminBookingDetail(bookingId: b.id))),
        ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          BackHeader(title: name),
          Expanded(
            child: SplitList(left: parts.sublist(0, 3), right: parts.sublist(3)),
          ),
        ]),
      ),
    );
  }
}
