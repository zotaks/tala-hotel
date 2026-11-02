import 'package:flutter/material.dart';

import '../../data/seed_data.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'book_screen.dart';
import 'booking_detail_screen.dart';
import 'customer_shell.dart';
import 'extras_screen.dart';
import 'room_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final next = s.nextStay;
    final rooms = s.visibleRooms;
    final unread = s.bookings.any((b) => b.status == BookingStatus.confirmed && b.isUpcoming);
    final Widget? nextCard = next == null
        ? null
        : Pressable(
            onTap: () => go(context, BookingDetailScreen(bookingId: next.id)),
            child: Container(
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(width: 4, color: next.status == BookingStatus.pending ? C.accent : C.text),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_nextLabel(next), style: T.small)),
                          StatusChip(next.status),
                        ]),
                        const SizedBox(height: 6),
                        Text(next.roomName, style: T.h2),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.schedule_rounded, size: 15, color: C.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('${fmtDay(next.checkIn)} → ${fmtDay(next.checkOut)} · ${plural(next.nights, 'night')}',
                                style: T.bodyMuted, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
    final Widget? highlight = rooms.isEmpty ? null : _HighlightCard(hasStay: next != null, rooms: rooms);
    var i = 0;
    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.card,
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          FadeSlideIn(
            index: i++,
            child: PageHeader(
              title: 'Hi, ${firstName(s.user?.name ?? 'there')}',
              subtitle: next == null ? 'Where will you stay next?' : "Here's what's next for your stay",
              actions: [
                SquareIconButton(icon: Icons.search_rounded, onTap: () => CustomerShell.goTab(context, 1)),
                SquareIconButton(icon: Icons.notifications_none_rounded, badge: unread, onTap: () => sheet(context, const _UpdatesSheet())),
              ],
            ),
          ),
          if (s.loading && s.rooms.isEmpty) const _HomeSkeleton(),
          if (s.loadError != null && s.rooms.isEmpty)
            EmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't load the hotel", text: s.loadError!, action: 'Try again', onAction: s.refresh),

          // ------------------------------------------------ next stay + the one orange highlight card
          // (side by side in landscape, stacked in portrait)
          if (nextCard != null || highlight != null)
            FadeSlideIn(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: nextCard != null && highlight != null
                    ? PairRow(first: nextCard, second: highlight, spacing: Screen.wide(context) ? 12 : 16)
                    : (nextCard ?? highlight!),
              ),
            ),

          // ------------------------------------------------ rooms carousel
          if (rooms.isNotEmpty) ...[
            FadeSlideIn(index: i++, child: SectionLabel('Room types', action: 'See all', onAction: () => CustomerShell.goTab(context, 1))),
            FadeSlideIn(
              index: i++,
              child: SizedBox(
                height: 170,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, k) => RoomTile(
                    room: rooms[k],
                    onTap: () => go(context, RoomDetailScreen(roomId: rooms[k].id, heroTag: 'tile-${rooms[k].id}')),
                  ),
                ),
              ),
            ),
          ],

          // ------------------------------------------------ extras
          if (s.addons.isNotEmpty) ...[
            FadeSlideIn(index: i++, child: SectionLabel('Make it special', action: 'All extras', onAction: () => go(context, const ExtrasScreen()))),
            FadeSlideIn(
              index: i++,
              child: SizedBox(
                height: 128,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: s.addons.where((a) => a.active).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, k) {
                    final a = s.addons.where((a) => a.active).toList()[k];
                    return Pressable(
                      onTap: () => go(context, const ExtrasScreen()),
                      child: SizedBox(
                        width: 120,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          NetImage(a.image, width: 120, height: 82, radius: 10, icon: Icons.room_service_rounded),
                          const SizedBox(height: 6),
                          Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(peso(a.price), style: T.small),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // ------------------------------------------------ amenities
          FadeSlideIn(index: i++, child: const SectionLabel('At the hotel')),
          FadeSlideIn(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in Hotel.amenities)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(9)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_amenityIcon(a), size: 16, color: C.muted),
                      const SizedBox(width: 6),
                      Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ),
          ),
          FadeSlideIn(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(children: [
                  const NetImage(heroPool, height: 150, width: double.infinity, radius: 14),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xDD000000), Color(0x00000000)], begin: Alignment.bottomLeft, end: Alignment.topRight)),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 14,
                    right: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Check-in ${Hotel.checkIn} · Check-out ${Hotel.checkOut}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(Hotel.address, style: T.small.copyWith(color: const Color(0xFFCFCFD4))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _nextLabel(Booking b) {
    final d = daysBetween(today(), b.checkIn);
    if (b.status == BookingStatus.checkedIn) return 'You are checked in · ${b.code}';
    if (d <= 0) return 'Check-in today · ${b.code}';
    if (d == 1) return 'Check-in tomorrow · ${b.code}';
    return 'Next stay · in $d days';
  }

  static IconData _amenityIcon(String a) => switch (a) {
        'Pool' => Icons.pool_rounded,
        'Free Wi-Fi' => Icons.wifi_rounded,
        'Restaurant' => Icons.restaurant_rounded,
        'Gym' => Icons.fitness_center_rounded,
        'Spa' => Icons.spa_rounded,
        'Parking' => Icons.local_parking_rounded,
        _ => Icons.support_agent_rounded,
      };
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.hasStay, required this.rooms});
  final bool hasStay;
  final List<RoomType> rooms;

  @override
  Widget build(BuildContext context) {
    final cheapest = rooms.reduce((a, b) => a.price <= b.price ? a : b);
    final featured = rooms.firstWhere((r) => r.popular, orElse: () => rooms.first);
    final title = hasStay ? 'Make it special' : 'Your first Tala stay';
    final sub = hasStay ? 'Add breakfast, spa or a pickup · from ${peso(400)}' : 'Rooms from ${peso(cheapest.price)} a night';
    return Pressable(
      onTap: () => hasStay ? go(context, const ExtrasScreen()) : go(context, BookScreen(roomId: featured.id)),
      child: Container(
        height: 138,
        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 13, color: Color(0xFF3B1C08)), maxLines: 2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(9)),
                child: Text(hasStay ? 'Browse extras' : 'Book now', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Stack(clipBehavior: Clip.none, children: [
            NetImage(hasStay ? (s(context).addons.isNotEmpty ? s(context).addons.last.image : featured.cover) : featured.cover, width: 104, height: 104, radius: 10),
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome, size: 16, color: C.accent),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  AppState s(BuildContext context) => AppScope.of(context);
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          Skeleton(height: 110, radius: 14),
          SizedBox(height: 16),
          Skeleton(height: 138, radius: 14),
          SizedBox(height: 24),
          Row(children: [Expanded(child: Skeleton(height: 118)), SizedBox(width: 12), Expanded(child: Skeleton(height: 118))]),
        ]),
      );
}

/// Bell icon → latest changes to the guest's bookings.
class _UpdatesSheet extends StatelessWidget {
  const _UpdatesSheet();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final items = s.activity.take(8).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
        Text('Updates', style: T.h2),
        const SizedBox(height: 4),
        Text('Changes to your bookings', style: T.bodyMuted),
        const SizedBox(height: 14),
        if (items.isEmpty) const EmptyState(icon: Icons.notifications_none_rounded, title: 'Nothing yet', text: 'Booking updates from the front desk show up here.'),
        for (var k = 0; k < items.length; k++)
          FadeSlideIn(
            index: k,
            child: InfoRow(
              icon: _icon(items[k].status),
              label: '${items[k].code} · ${fmtRelative(parseDateTime(items[k].updatedAt))}',
              value: _text(items[k]),
              onTap: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: items[k].id)));
              },
            ),
          ),
      ]),
    );
  }

  static IconData _icon(String s) => switch (s) {
        BookingStatus.confirmed => Icons.verified_rounded,
        BookingStatus.checkedIn => Icons.key_rounded,
        BookingStatus.checkedOut => Icons.luggage_rounded,
        BookingStatus.cancelled => Icons.cancel_outlined,
        _ => Icons.hourglass_top_rounded,
      };

  static String _text(Booking b) => switch (b.status) {
        BookingStatus.confirmed => '${b.roomName} is confirmed',
        BookingStatus.checkedIn => 'Welcome! You\'re checked in',
        BookingStatus.checkedOut => 'Thanks for staying with us',
        BookingStatus.cancelled => '${b.roomName} was cancelled',
        _ => '${b.roomName} is waiting for confirmation',
      };
}
