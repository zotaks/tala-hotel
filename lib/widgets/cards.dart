import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';
import 'motion.dart';

/// Room row: photo left, details, price right (the reference's "Services" list).
class RoomListCard extends StatelessWidget {
  const RoomListCard({super.key, required this.room, this.onTap, this.freeTonight, this.heroPrefix = 'room'});
  final RoomType room;
  final VoidCallback? onTap;
  final int? freeTonight;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Hero(tag: '$heroPrefix-${room.id}', child: NetImage(room.cover, width: 84, height: 84, radius: 10)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(room.name, style: T.title, overflow: TextOverflow.ellipsis)),
                if (room.popular) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(4)),
                    child: const Text('POPULAR', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 0.6)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text('${room.beds} · ${room.sizeSqm} m²', style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: C.muted),
                Text(' ${room.capacity}', style: T.small),
                if (room.reviewCount > 0) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.star_rounded, size: 14, color: C.accent),
                  Text(' ${room.rating.toStringAsFixed(1)}', style: T.small),
                ],
                if (freeTonight != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(freeTonight == 0 ? 'Full tonight' : '$freeTonight left tonight',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: freeTonight == 0 ? C.faint : (freeTonight! <= 2 ? C.accent : C.muted)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(peso(room.price), style: T.price),
            Text('/ night', style: T.small),
          ]),
        ]),
      );
}

/// Photo tile for horizontal carousels on Home.
class RoomTile extends StatelessWidget {
  const RoomTile({super.key, required this.room, this.onTap, this.width = 168});
  final RoomType room;
  final VoidCallback? onTap;
  final double width;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(tag: 'tile-${room.id}', child: NetImage(room.cover, width: width, height: 118, radius: 12)),
            const SizedBox(height: 8),
            Text(room.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('from ${peso(room.price)}', style: T.small),
          ]),
        ),
      );
}

/// Guest-side booking card (Bookings tab).
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, this.onTap, this.showGuest = false, this.footer});
  final Booking booking;
  final VoidCallback? onTap;
  final bool showGuest;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final dim = b.status == BookingStatus.checkedOut || b.status == BookingStatus.cancelled;
    return AppCard(
      onTap: onTap,
      dim: dim && !showGuest,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(showGuest ? '${b.guestName} · ${b.roomName}' : b.roomName, style: T.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          StatusChip(b.status),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.calendar_today_rounded, size: 14, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('${fmtDay(b.checkIn)} → ${fmtDay(b.checkOut)} · ${plural(b.nights, 'night')}', style: T.bodyMuted, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.receipt_long_rounded, size: 14, color: C.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('${b.code} · ${plural(b.guests, 'guest')} · ${peso(b.total)}', style: T.bodyMuted)),
        ]),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ]),
    );
  }
}

/// Small square stat tile (Today dashboard).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.dot = false, this.format, this.onTap});
  final num value;
  final String label;
  final bool dot;
  final String Function(num)? format;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedNumber(value, format: format, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 4),
          Row(children: [
            if (dot) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text(label, style: T.bodyMuted, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ]),
      );
}
