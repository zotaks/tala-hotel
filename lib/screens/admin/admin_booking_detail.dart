import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'admin_shell.dart';
import 'guests_screen.dart';

class AdminBookingDetail extends StatefulWidget {
  const AdminBookingDetail({super.key, required this.bookingId});
  final int bookingId;
  @override
  State<AdminBookingDetail> createState() => _AdminBookingDetailState();
}

class _AdminBookingDetailState extends State<AdminBookingDetail> {
  final staffNote = TextEditingController();
  bool _filled = false, saving = false;

  @override
  void dispose() {
    staffNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bookingById(widget.bookingId);
    if (b == null) {
      return const Scaffold(body: SafeArea(child: Column(children: [BackHeader(title: 'Booking'), EmptyState(icon: Icons.receipt_long_outlined, title: 'Booking not found', text: 'It may have been removed.')])));
    }
    if (!_filled) {
      staffNote.text = b.staffNote;
      _filled = true;
    }
    final canCancel = b.status == BookingStatus.confirmed && s.can(Priv.bookingsCancel);
    final canManage = s.can(Priv.bookingsManage);

    final parts = <Widget>[
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusChip(b.status),
                const SizedBox(height: 8),
                Text('${firstName(b.guestName)} · ${b.roomName}', style: T.h2),
                const SizedBox(height: 4),
                Text('${fmtDay(b.checkIn)} → ${fmtDay(b.checkOut)} · ${plural(b.nights, 'night')}', style: T.bodyMuted),
              ]),
            ),
            const SizedBox(width: 12),
            NetImage(b.roomImage, width: 72, height: 72, radius: 10),
          ]),
          if (b.status != BookingStatus.cancelled) ...[const SizedBox(height: 18), ProgressTracker(status: b.status)],
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Guest · ${b.guestPhone}',
            value: b.guestName,
            onTap: s.can(Priv.guestsView) ? () => go(context, GuestDetailScreen(userId: b.userId, name: b.guestName)) : null,
          ),
          InfoRow(icon: Icons.bed_outlined, label: '${plural(b.guests, 'guest')} · ${b.code}', value: b.roomName),
          InfoRow(icon: Icons.payments_outlined, label: b.paymentMethod, value: 'Collect at the desk', trailing: Text(peso(b.total), style: T.h2)),
        ]),
      ),
      if (b.addons.isNotEmpty) ...[
        const SectionLabel('Extras to prepare', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
        AppCard(
          child: Column(children: [
            for (final a in b.addons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.check_rounded, size: 16, color: C.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.name)),
                  Text(peso(a.price), style: T.bodyMuted),
                ]),
              ),
          ]),
        ),
      ],
      if (b.note.isNotEmpty) ...[const SizedBox(height: 16), NoteBox(title: "Guest's note", text: b.note)],
      const SectionLabel('Staff note · only staff can see this', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
      TextField(
        controller: staffNote,
        maxLines: 3,
        readOnly: !canManage,
        decoration: InputDecoration(hintText: canManage ? 'e.g. Upgraded to high floor, extra towels sent' : 'No staff note'),
      ),
      const SizedBox(height: 10),
      if (canManage)
        Align(
        alignment: Alignment.centerRight,
        child: Btn('Save note', style: BtnStyle.secondary, expand: false, height: 42, loading: saving, onTap: () async {
          setState(() => saving = true);
          await attempt(context, () => AppScope.read(context).saveStaffNote(b, staffNote.text), success: 'Note saved');
          if (mounted) setState(() => saving = false);
        }),
      ),
      const SizedBox(height: 12),
      Text('Booked ${fmtFull(parseDateTime(b.createdAt))} · updated ${fmtRelative(parseDateTime(b.updatedAt))}', style: T.small, textAlign: TextAlign.center),
    ];

    final hasStep = NextStep.of(b) != null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BackHeader(
            title: 'Booking ${b.code}',
            trailing: canCancel
                ? TextButton(
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: 'Cancel ${b.code}?', message: 'Use this for no-shows or guest requests.', confirm: 'Cancel booking', danger: true);
                      if (ok && context.mounted) await attempt(context, () => AppScope.read(context).setStatus(b, BookingStatus.cancelled), success: 'Booking cancelled');
                    },
                    child: Text('Cancel', style: TextStyle(color: C.danger, fontWeight: FontWeight.w700)),
                  )
                : null,
          ),
          Expanded(
            child: SplitList(left: parts.sublist(0, 3), right: parts.sublist(3)),
          ),
        ]),
      ),
      bottomNavigationBar: canManage && (hasStep || b.status == BookingStatus.confirmed)
          ? BottomBar(
              child: hasStep
                  ? BookingActions(booking: b, compact: false)
                  : Text('Check-in opens on ${fmtDay(b.checkIn)}', textAlign: TextAlign.center, style: T.bodyMuted),
            )
          : null,
    );
  }
}
