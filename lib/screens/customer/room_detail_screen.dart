import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'book_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId, required this.heroTag});
  final int roomId;
  final String heroTag;
  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final page = PageController();
  int photo = 0;

  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.roomById(widget.roomId);
    if (r == null) {
      return const Scaffold(body: SafeArea(child: Column(children: [BackHeader(title: 'Room'), EmptyState(icon: Icons.bed_outlined, title: 'Room not found', text: 'It may have been removed.')])));
    }
    final fav = s.favorites.contains(r.id);
    final reviews = s.reviewsFor(r.id);
    final days = [for (var i = 0; i < 7; i++) addDays(today(), i)];
    final imgs = r.images.isEmpty ? [''] : r.images;
    final top = MediaQuery.of(context).padding.top;

    final body = <Widget>[
      Text(r.category.toUpperCase(), style: T.label),
      const SizedBox(height: 6),
      Text(r.name, style: T.h1),
      const SizedBox(height: 8),
      Row(children: [
        if (r.reviewCount > 0) ...[
          Stars(r.rating),
          const SizedBox(width: 6),
          Text('${r.rating.toStringAsFixed(1)} · ${plural(r.reviewCount, 'review')}', style: T.small),
        ] else
          Text('New room · no reviews yet', style: T.small),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        _Spec(icon: Icons.person_outline_rounded, label: 'Up to ${r.capacity}'),
        const SizedBox(width: 8),
        _Spec(icon: Icons.square_foot_rounded, label: '${r.sizeSqm} m²'),
        const SizedBox(width: 8),
        Expanded(child: _Spec(icon: Icons.bed_outlined, label: r.beds, expand: true)),
      ]),
      const SizedBox(height: 18),
      Text(r.description, style: T.bodyMuted.copyWith(fontSize: 14.5, height: 1.5)),
      const SectionLabel('In the room', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in r.amenities)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_rounded, size: 15, color: C.accent),
              const SizedBox(width: 6),
              Text(a, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
      const SectionLabel('Free rooms this week', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
      Row(children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _AvailDay(day: d, free: s.isClosed(d) ? -1 : s.freeOn(r, d), units: r.units),
            ),
          ),
      ]),
      SectionLabel('Guest reviews', padding: const EdgeInsets.fromLTRB(0, 24, 0, 10), action: reviews.isEmpty ? null : '${reviews.length}'),
      if (reviews.isEmpty) Text('Be the first to review this room after your stay.', style: T.bodyMuted),
      for (final v in reviews.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(v.userName, size: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(v.userName, style: const TextStyle(fontWeight: FontWeight.w700))),
                Stars(v.rating.toDouble(), size: 13),
              ]),
              if (v.comment.isNotEmpty) ...[const SizedBox(height: 10), Text(v.comment, style: T.bodyMuted)],
              const SizedBox(height: 6),
              Text(fmtFull(parseDateTime(v.createdAt)), style: T.small),
            ]),
          ),
        ),
    ];

    final wide = Screen.wide(context);
    final gallery = Stack(children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: page,
                  itemCount: imgs.length,
                  onPageChanged: (i) => setState(() => photo = i),
                  itemBuilder: (_, i) {
                    final img = NetImage(imgs[i], radius: 0);
                    return i == 0 ? Hero(tag: widget.heroTag, child: img) : img;
                  },
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0x88000000), const Color(0x00000000), const Color(0x00000000), C.bg.withAlpha(0xCC)],
                        stops: [0, 0.3, 0.7, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 10,
                left: 14,
                right: 14,
                child: Row(children: [
                  SquareIconButton(icon: Icons.arrow_back_ios_new_rounded, color: const Color(0xAA161618), iconColor: Colors.white, onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  _FavButton(
                    on: fav,
                    onTap: () => attempt(context, () => AppScope.read(context).toggleFavorite(r.id)),
                  ),
                ]),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < imgs.length; i++)
                    AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.curve,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == photo ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: i == photo ? Colors.white : const Color(0x88FFFFFF), borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
              ),
            ]);
    final details = [for (var i = 0; i < body.length; i++) FadeSlideIn(index: i, child: body[i])];
    return Scaffold(
      body: wide
          // landscape / tablet: photos on the left, details on the right
          ? Row(children: [
              Expanded(child: gallery),
              Expanded(child: SafeArea(left: false, child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 28), children: details))),
            ])
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(child: SizedBox(height: 320 + top, child: gallery)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverList(delegate: SliverChildListDelegate(details)),
              ),
            ]),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(peso(r.price), style: T.h2),
              Text('per night', style: T.small),
            ]),
          ),
          Btn('Book this room', expand: false, onTap: () => go(context, BookScreen(roomId: r.id))),
        ]),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.label, this.expand = false});
  final IconData icon;
  final String label;
  final bool expand;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: C.muted),
          const SizedBox(width: 6),
          expand
              ? Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))
              : Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _AvailDay extends StatelessWidget {
  const _AvailDay({required this.day, required this.free, required this.units});
  final DateTime day;
  final int free, units;
  @override
  Widget build(BuildContext context) {
    final full = free <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: full ? C.disabled : C.card, borderRadius: BorderRadius.circular(9)),
      child: Column(children: [
        Text(wd(day), style: TextStyle(fontSize: 10.5, color: C.muted)),
        Text('${day.day}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: full ? C.faint : C.text)),
        const SizedBox(height: 2),
        Text(free < 0 ? 'Closed' : (full ? 'Full' : '$free left'),
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: full ? C.faint : (free <= 1 ? C.accent : C.muted))),
      ]),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.85,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: const Color(0xAA161618), borderRadius: BorderRadius.circular(12)),
          child: AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
            child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(on), color: on ? C.accent : Colors.white, size: 22),
          ),
        ),
      );
}

/// Used by the Saved tab too.
String roomSummary(RoomType r) => '${r.beds} · up to ${r.capacity} guests';
