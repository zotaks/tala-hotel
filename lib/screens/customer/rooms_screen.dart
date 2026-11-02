import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  int cat = 0;
  int guests = 0; // 0 = any
  bool searching = false;
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cats = ['All', ...{for (final r in s.visibleRooms) r.category}];
    if (cat >= cats.length) cat = 0;
    final query = q.text.trim().toLowerCase();
    final list = s.visibleRooms.where((r) {
      if (cat > 0 && r.category != cats[cat]) return false;
      if (guests > 0 && r.capacity < guests) return false;
      if (query.isNotEmpty && !('${r.name} ${r.description} ${r.amenities.join(' ')}'.toLowerCase().contains(query))) return false;
      return true;
    }).toList();
    final tonight = today();

    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      PageHeader(
        title: 'Rooms',
        subtitle: 'Prices are per night, taxes included',
        actions: [
          SquareIconButton(
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            onTap: () => setState(() {
              searching = !searching;
              if (!searching) q.clear();
            }),
          ),
        ],
      ),
      AnimatedSize(
        duration: Motion.medium,
        curve: Motion.curve,
        child: searching
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: TextField(
                  controller: q,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'Search rooms, e.g. bathtub, view', prefixIcon: Icon(Icons.search_rounded, color: C.muted)),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SectionLabel('Room type', padding: EdgeInsets.fromLTRB(20, 0, 20, 10)),
      FilterChips(options: cats, selected: cat, onSelect: (i) => setState(() => cat = i)),
      const SectionLabel('Guests', padding: EdgeInsets.fromLTRB(20, 18, 20, 10)),
      FilterChips(
        options: const ['Any', '1', '2', '3', '4+'],
        selected: guests,
        onSelect: (i) => setState(() => guests = i),
      ),
      const SizedBox(height: 16),
      // A new key re-runs the staggered entrance whenever the filters change.
      KeyedSubtree(
        key: ValueKey('$cat-$guests-$query'),
        child: Column(
          children: [
            if (list.isEmpty)
              EmptyState(
                icon: Icons.bed_outlined,
                title: 'No rooms match',
                text: 'Try another room type or fewer guests.',
                action: 'Clear filters',
                onAction: () => setState(() {
                  cat = 0;
                  guests = 0;
                  q.clear();
                }),
              ),
            AdaptiveGrid(children: [
              for (var i = 0; i < list.length; i++)
                FadeSlideIn(
                  index: i,
                  child: RoomListCard(
                    room: list[i],
                    freeTonight: s.freeOn(list[i], tonight),
                    onTap: () => go(context, RoomDetailScreen(roomId: list[i].id, heroTag: 'room-${list[i].id}')),
                  ),
                ),
            ]),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: C.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pay when you arrive', style: T.title),
                const SizedBox(height: 4),
                Text('No online payment needed. Settle at the front desk by cash, GCash or card. '
                    'Check-in ${Hotel.checkIn}, check-out ${Hotel.checkOut}.', style: T.bodyMuted),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
