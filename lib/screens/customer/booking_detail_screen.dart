import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'book_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final int bookingId;

  static String headline(Booking b) {
    final d = daysBetween(today(), b.checkIn);
    return switch (b.status) {
      BookingStatus.pending => 'Waiting for confirmation',
      BookingStatus.confirmed => d <= 0 ? 'See you today' : (d == 1 ? 'See you tomorrow' : (d < 7 ? 'See you on ${wdLong(b.checkIn)}' : 'See you on ${fmtShort(b.checkIn)}')),
      BookingStatus.checkedIn => 'Enjoy your stay',
      BookingStatus.checkedOut => 'Thanks for staying',
      _ => 'Booking cancelled',
    };
  }

  static String subline(Booking b) => switch (b.status) {
        BookingStatus.pending => 'The front desk will confirm your ${b.roomName} soon.',
        BookingStatus.confirmed => 'Check in from ${Hotel.checkIn}, ${fmtDay(b.checkIn)}.',
        BookingStatus.checkedIn => 'Check-out is ${Hotel.checkOut}, ${fmtDay(b.checkOut)}.',
        BookingStatus.checkedOut => 'You stayed ${plural(b.nights, 'night')} in the ${b.roomName}.',
        _ => 'This booking is no longer active.',
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = s.bookingById(bookingId);
    if (b == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const BackHeader(title: 'Booking'),
            if (s.loading) const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: C.accent)),
            if (!s.loading) const EmptyState(icon: Icons.receipt_long_outlined, title: 'Booking not found', text: 'Pull to refresh on the Bookings tab.'),
          ]),
        ),
      );
    }

    final parts = <Widget>[
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusChip(b.status),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  child: Text(headline(b), key: ValueKey(b.status), style: T.h2),
                ),
                const SizedBox(height: 4),
                Text(subline(b), style: T.bodyMuted),
              ]),
            ),
            const SizedBox(width: 12),
            NetImage(b.roomImage, width: 76, height: 76, radius: 10),
          ]),
          if (b.status != BookingStatus.cancelled) ...[const SizedBox(height: 18), ProgressTracker(status: b.status)],
        ]),
      ),
      const SectionLabel('Details', padding: EdgeInsets.fromLTRB(0, 22, 0, 6)),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          InfoRow(icon: Icons.bed_outlined, label: 'Room', value: b.roomName),
          InfoRow(icon: Icons.calendar_month_outlined, label: '${fmtDay(b.checkIn)} → ${fmtDay(b.checkOut)}', value: plural(b.nights, 'night')),
          InfoRow(icon: Icons.group_outlined, label: 'Guests', value: plural(b.guests, 'guest')),
          InfoRow(icon: Icons.payments_outlined, label: b.paymentMethod, value: 'Total', trailing: Text(peso(b.total), style: T.h2)),
        ]),
      ),
      const SectionLabel('Price', padding: EdgeInsets.fromLTRB(0, 22, 0, 6)),
      AppCard(
        child: Column(children: [
          _Line('${b.roomName} × ${plural(b.nights, 'night')}', b.roomTotal),
          for (final a in b.addons) _Line(a.name, a.price),
          Divider(height: 22, color: C.line),
          _Line('Total · pay at the hotel', b.total, bold: true),
        ]),
      ),
      if (b.note.isNotEmpty) ...[const SizedBox(height: 16), NoteBox(title: 'Your note to the front desk', text: b.note)],
      const SizedBox(height: 18),
      Text(
        'Booked ${fmtFull(parseDateTime(b.createdAt))} · ${b.code}\nYou can cancel while a booking is pending or confirmed.',
        textAlign: TextAlign.center,
        style: T.small,
      ),
    ];

    Widget? action;
    if (b.canGuestCancel) {
      action = Btn('Cancel booking', style: BtnStyle.danger, onTap: () async {
        final ok = await confirmDialog(context,
            title: 'Cancel this booking?', message: '${b.roomName}, ${fmtDay(b.checkIn)}. This can\'t be undone.', confirm: 'Cancel booking', danger: true);
        if (ok && context.mounted) await attempt(context, () => AppScope.read(context).cancelBooking(b), success: 'Booking cancelled');
      });
    } else if (b.status == BookingStatus.checkedOut && !b.reviewed) {
      action = Btn('Rate your stay', icon: Icons.star_rounded, onTap: () => sheet(context, _ReviewSheet(booking: b)));
    } else if (!b.isActive) {
      action = Btn('Book again', onTap: () => go(context, BookScreen(roomId: b.roomTypeId, addonIds: [for (final a in b.addons) a.addonId])));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BackHeader(title: 'Booking ${b.code}'),
          Expanded(
            child: SplitList(left: parts.sublist(0, 3), right: parts.sublist(3)),
          ),
        ]),
      ),
      bottomNavigationBar: action == null ? null : BottomBar(child: action),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.bold = false});
  final String label;
  final double amount;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: bold ? T.title : T.bodyMuted)),
          Text(peso(amount), style: bold ? T.title : T.body),
        ]),
      );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking});
  final Booking booking;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int rating = 5;
  final c = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rate your stay', style: T.h2),
          const SizedBox(height: 4),
          Text('${widget.booking.roomName} · ${fmtDay(widget.booking.checkIn)}', style: T.bodyMuted),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              Pressable(
                onTap: () => setState(() => rating = i),
                scale: 0.8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: i <= rating ? 1.0 : 0.85,
                    duration: Motion.medium,
                    curve: Curves.easeOutBack,
                    child: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 42, color: i <= rating ? C.accent : C.faint),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'What did you like? What could be better?')),
          const SizedBox(height: 16),
          Btn('Send review', loading: busy, onTap: () async {
            setState(() => busy = true);
            final ok = await attempt(context, () => AppScope.read(context).addReview(widget.booking, rating, c.text), success: 'Thanks for your review!');
            if (!context.mounted || !mounted) return;
            setState(() => busy = false);
            if (ok) Navigator.of(context).pop();
          }),
        ]),
      );
}
