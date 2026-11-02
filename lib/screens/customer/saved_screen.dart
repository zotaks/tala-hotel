import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'customer_shell.dart';
import 'room_detail_screen.dart';

/// Rooms the guest tapped the heart on.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final saved = s.visibleRooms.where((r) => s.favorites.contains(r.id)).toList();
    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      PageHeader(title: 'Saved', subtitle: saved.isEmpty ? 'Rooms you love, in one place' : plural(saved.length, 'saved room')),
      if (saved.isEmpty)
        EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'Nothing saved yet',
          text: 'Tap the heart on a room to keep it here for later.',
          action: 'Browse rooms',
          onAction: () => CustomerShell.goTab(context, 1),
        ),
      AdaptiveGrid(children: [
        for (var i = 0; i < saved.length; i++)
          FadeSlideIn(
            key: ValueKey(saved[i].id),
            index: i,
            child: Dismissible(
              key: ValueKey('fav${saved[i].id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              onDismissed: (_) => attempt(context, () => AppScope.read(context).toggleFavorite(saved[i].id)),
              child: RoomListCard(
                room: saved[i],
                heroPrefix: 'saved',
                freeTonight: s.freeOn(saved[i], today()),
                onTap: () => go(context, RoomDetailScreen(roomId: saved[i].id, heroTag: 'saved-${saved[i].id}')),
              ),
            ),
          ),
      ]),
      if (saved.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text('Swipe left on a room to remove it.', style: TextStyle(fontSize: 12.5, color: C.muted), textAlign: TextAlign.center),
        ),
    ]);
  }
}
