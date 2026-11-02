import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'book_screen.dart';

/// Hotel extras (breakfast, pickup, spa ...). Pick some, then choose a room.
class ExtrasScreen extends StatefulWidget {
  const ExtrasScreen({super.key});
  @override
  State<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends State<ExtrasScreen> {
  final picked = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.addons.where((a) => a.active).toList();
    final total = list.where((a) => picked.contains(a.id)).fold<double>(0, (t, a) => t + a.price);
    final room = s.visibleRooms.isEmpty ? null : s.visibleRooms.firstWhere((r) => r.popular, orElse: () => s.visibleRooms.first);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BackHeader(title: 'Hotel extras'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
              Text('Add these when you book. Prices are per stay and paid at the hotel.', style: T.bodyMuted),
              const SizedBox(height: 16),
              AdaptiveGrid(padding: EdgeInsets.zero, children: [
                for (var i = 0; i < list.length; i++)
                  FadeSlideIn(
                    index: i,
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      color: picked.contains(list[i].id) ? C.card2 : C.card,
                      onTap: () => setState(() => picked.contains(list[i].id) ? picked.remove(list[i].id) : picked.add(list[i].id)),
                      child: Row(children: [
                        NetImage(list[i].image, width: 76, height: 76, radius: 10, icon: Icons.room_service_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(list[i].name, style: T.title),
                            const SizedBox(height: 3),
                            Text(list[i].description, style: T.small),
                            const SizedBox(height: 6),
                            Text(peso(list[i].price), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        AnimatedContainer(
                          duration: Motion.medium,
                          curve: Curves.easeOutBack,
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: picked.contains(list[i].id) ? C.accent : C.card2, borderRadius: BorderRadius.circular(8)),
                          child: AnimatedSwitcher(
                            duration: Motion.fast,
                            child: Icon(picked.contains(list[i].id) ? Icons.check_rounded : Icons.add_rounded,
                                key: ValueKey(picked.contains(list[i].id)), size: 18, color: picked.contains(list[i].id) ? Colors.black : C.text),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: room == null
          ? null
          : BottomBar(
              child: Row(children: [
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(picked.isEmpty ? 'No extras picked' : plural(picked.length, 'extra'), style: T.small),
                    AnimatedNumber(total, format: (v) => peso(v.round()), style: T.h2),
                  ]),
                ),
                Btn('Choose a room', expand: false, onTap: () => go(context, BookScreen(roomId: room.id, addonIds: picked.toList()))),
              ]),
            ),
    );
  }
}
