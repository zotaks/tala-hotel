import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'admin_booking_detail.dart';

/// Night-by-night availability (the reference's "Schedule" screen).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime day = today();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final days = [for (var i = 0; i < 30; i++) addDays(today(), i)];
    final rooms = s.visibleRooms;
    final isClosed = s.isClosed(day);
    final totalUnits = s.totalUnits;
    final booked = rooms.fold<int>(0, (t, r) => t + clampInt(s.bookedOn(r.id, day), 0, r.units));
    final arrivals = s.bookings.where((b) => sameDay(b.checkIn, day) && b.status != BookingStatus.cancelled).toList();

    final canEdit = s.can(Priv.calendarManage);
    final wide = Screen.wide(context);

    final openCard = AppCard(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isClosed ? 'Closed for check-ins' : 'Open for check-ins', style: T.title),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                isClosed ? (s.closed[ymd(day)] ?? 'Closed') : '$booked of $totalUnits rooms booked · ${fmtDay(day)}',
                key: ValueKey('${ymd(day)}$isClosed$booked'),
                style: T.small,
              ),
            ),
          ]),
        ),
        Switch(
          value: !isClosed,
          onChanged: !canEdit
              ? null
              : (open) async {
                  String reason = 'Closed';
                  if (!open) {
                    final r = await _askReason(context);
                    if (r == null) return;
                    reason = r;
                  }
                  if (!context.mounted) return;
                  await attempt(context, () => AppScope.read(context).setClosed(day, !open, reason: reason),
                      success: open ? 'Open for check-ins on ${fmtShort(day)}' : 'Closed ${fmtShort(day)}');
                },
        ),
      ]),
    );

    final roomsSection = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionLabel('Rooms tonight', padding: EdgeInsets.fromLTRB(0, 22, 0, 10)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          for (var i = 0; i < rooms.length; i++) ...[
            if (i > 0) Divider(height: 1, color: C.line),
            _RoomRow(room: rooms[i], booked: s.bookedOn(rooms[i].id, day), editable: canEdit),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(canEdit ? '− / + changes how many rooms of that type exist (all dates).' : 'View only — ask the owner for the calendar privilege to make changes.',
            style: T.small),
      ),
    ]);

    final arrivalsSection = Column(children: [
      SectionLabel('Arrivals · ${fmtDay(day)}', padding: EdgeInsets.fromLTRB(0, wide ? 0 : 22, 0, 10)),
      if (arrivals.isEmpty) AppCard(child: Text('No arrivals on this day.', style: T.bodyMuted)),
      for (var i = 0; i < arrivals.length; i++)
        FadeSlideIn(
          key: ValueKey('arr${arrivals[i].id}${ymd(day)}'),
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () => go(context, AdminBookingDetail(bookingId: arrivals[i].id)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(arrivals[i].guestName, style: T.title),
                    Text('${arrivals[i].roomName} · ${plural(arrivals[i].nights, 'night')}', style: T.small),
                  ]),
                ),
                StatusChip(arrivals[i].status),
              ]),
            ),
          ),
        ),
    ]);

    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      const PageHeader(title: 'Calendar', subtitle: 'Free rooms per night'),
      DateStrip(
        days: days,
        selected: day,
        onSelect: (d) => setState(() => day = d),
        caption: (d) => s.isClosed(d) ? 'Closed' : '${s.totalFreeOn(d)} open',
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [openCard, roomsSection])),
                const SizedBox(width: 16),
                Expanded(child: arrivalsSection),
              ])
            : Column(children: [openCard, roomsSection, arrivalsSection]),
      ),
    ]);
  }

  Future<String?> _askReason(BuildContext context) {
    final c = TextEditingController(text: 'Private event');
    return sheet<String>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Builder(
          builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Close ${fmtDay(day)}?', style: T.h2),
            const SizedBox(height: 4),
            Text('Guests won\'t be able to check in on this day. Existing bookings stay.', style: T.bodyMuted),
            const SizedBox(height: 16),
            Field(label: 'Reason (shown to guests)', controller: c),
            Btn('Close this day', onTap: () => Navigator.of(ctx).pop(c.text.trim().isEmpty ? 'Closed' : c.text.trim())),
          ]),
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.booked, this.editable = true});
  final RoomType room;
  final int booked;
  final bool editable;
  @override
  Widget build(BuildContext context) {
    final full = booked >= room.units;
    final ratio = room.units == 0 ? 1.0 : (booked / room.units).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
              Text(full ? 'Full · $booked of ${room.units}' : '$booked of ${room.units} booked',
                  style: TextStyle(fontSize: 12.5, color: full ? C.text : C.muted, fontWeight: full ? FontWeight.w700 : FontWeight.w400)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(height: 4, color: C.card2),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: ratio),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(widthFactor: v, child: Container(height: 4, color: full ? C.text : C.accent)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        editable
            ? QtyStepper(
                value: room.units,
                min: 0,
                max: 99,
                onChanged: (v) => attempt(context, () => AppScope.read(context).adjustUnits(room, v - room.units)),
              )
            : Text('${room.units} rooms', style: T.small),
      ]),
    );
  }
}
