import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'booking_detail_screen.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.roomId, this.addonIds = const []});
  final int roomId;
  final List<int> addonIds;
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late int roomId = widget.roomId;
  late DateTime checkIn;
  int nights = 1;
  int guests = 2;
  late final Set<int> extras = {...widget.addonIds};
  int payment = 0;
  final note = TextEditingController();
  bool busy = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.of(context);
    final r = s.roomById(roomId);
    checkIn = today();
    if (r != null) {
      guests = clampInt(guests, 1, r.capacity);
      // start on the first day that still has a free room
      for (var i = 0; i < 30; i++) {
        final d = addDays(today(), i);
        if (!s.isClosed(d) && s.freeOn(r, d) > 0) {
          checkIn = d;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState s, RoomType r) async {
    setState(() => busy = true);
    try {
      final b = await s.createBooking(BookingRequest(
        roomTypeId: r.id,
        guests: guests,
        checkIn: checkIn,
        checkOut: addDays(checkIn, nights),
        addonIds: extras.toList(),
        paymentMethod: Hotel.payments[payment],
        note: note.text,
      ));
      if (!mounted) return;
      await _showSent(context, b);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: b.id)));
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rooms = s.visibleRooms;
    final r = s.roomById(roomId);
    if (r == null || rooms.isEmpty) {
      return const Scaffold(body: SafeArea(child: Column(children: [BackHeader(title: 'Book a room'), EmptyState(icon: Icons.bed_outlined, title: 'No rooms available', text: 'Please try again later.')])));
    }
    final days = [for (var i = 0; i < 30; i++) addDays(today(), i)];
    final checkOut = addDays(checkIn, nights);
    final free = s.freeForStay(r, checkIn, nights);
    final closed = s.isClosed(checkIn);
    final ok = free > 0 && !closed && guests <= r.capacity;
    final active = s.addons.where((a) => a.active).toList();
    final addTotal = active.where((a) => extras.contains(a.id)).fold<double>(0, (t, a) => t + a.price);
    final total = r.price * nights + addTotal;

    var i = 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BackHeader(title: 'Book a room'),
          Expanded(
            child: _TwoCol(left: [
              // ------------------------------------------- room
              FadeSlideIn(index: i++, child: const SectionLabel('Room', padding: EdgeInsets.fromLTRB(20, 8, 20, 10))),
              FadeSlideIn(
                index: i++,
                child: SizedBox(
                  height: 62,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, k) => SizedBox(
                      width: 138,
                      child: ChoiceTile(
                        title: rooms[k].name,
                        subtitle: '${peso(rooms[k].price)} · ${rooms[k].capacity} pax',
                        selected: rooms[k].id == roomId,
                        onTap: () => setState(() {
                          roomId = rooms[k].id;
                          guests = clampInt(guests, 1, rooms[k].capacity);
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              // ------------------------------------------- dates
              FadeSlideIn(index: i++, child: SectionLabel('Check-in · ${monLong(checkIn)}')),
              FadeSlideIn(
                index: i++,
                child: DateStrip(
                  days: days,
                  selected: checkIn,
                  onSelect: (d) => setState(() => checkIn = d),
                  isDisabled: (d) => s.isClosed(d) || s.freeOn(r, d) == 0,
                  caption: (d) => s.isClosed(d) ? 'Closed' : (s.freeOn(r, d) == 0 ? 'Full' : '${s.freeOn(r, d)} left'),
                ),
              ),
              FadeSlideIn(
                index: i++,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: AppCard(
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text('Nights', style: T.title)),
                        QtyStepper(value: nights, min: 1, max: 14, onChanged: (v) => setState(() => nights = v)),
                      ]),
                      Divider(height: 24, color: C.line),
                      Row(children: [
                        Expanded(child: Text('Guests', style: T.title)),
                        QtyStepper(value: guests, min: 1, max: r.capacity, onChanged: (v) => setState(() => guests = v)),
                      ]),
                      Divider(height: 24, color: C.line),
                      Row(children: [
                        Icon(Icons.login_rounded, size: 16, color: C.muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${fmtDay(checkIn)}, ${Hotel.checkIn}', style: T.bodyMuted)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.logout_rounded, size: 16, color: C.muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${fmtDay(checkOut)}, ${Hotel.checkOut}', style: T.bodyMuted)),
                      ]),
                    ]),
                  ),
                ),
              ),
              AnimatedSize(
                duration: Motion.medium,
                curve: Motion.curve,
                child: ok
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: NoteBox(
                          title: closed ? 'Closed for check-in' : 'Not available',
                          text: closed
                              ? '${s.closed[ymd(checkIn)]}. Please pick another date.'
                              : '${r.name} is fully booked on at least one of these nights. Try fewer nights, another date or another room.',
                        ),
                      ),
              ),

            ], right: [
              // ------------------------------------------- extras
              if (active.isNotEmpty) ...[
                FadeSlideIn(
                  index: i++,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
                    child: Row(children: [
                      Expanded(child: Text('EXTRAS', style: T.label)),
                      Text('Optional · per stay', style: T.small),
                    ]),
                  ),
                ),
                FadeSlideIn(
                  index: i++,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(children: [
                        for (final a in active)
                          _CheckRow(
                            title: a.name,
                            price: a.price,
                            on: extras.contains(a.id),
                            onTap: () => setState(() => extras.contains(a.id) ? extras.remove(a.id) : extras.add(a.id)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ],

              // ------------------------------------------- payment
              FadeSlideIn(index: i++, child: const SectionLabel('Payment · at the hotel')),
              FadeSlideIn(
                index: i++,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    for (var k = 0; k < Hotel.payments.length; k++) ...[
                      if (k > 0) const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceTile(
                          title: Hotel.payments[k].split(' ').first,
                          subtitle: Hotel.payments[k].split(' ').skip(1).join(' '),
                          selected: payment == k,
                          onTap: () => setState(() => payment = k),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),

              // ------------------------------------------- note
              FadeSlideIn(index: i++, child: const SectionLabel('Note for the front desk')),
              FadeSlideIn(
                index: i++,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(controller: note, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. Early check-in, high floor, celebrating a birthday')),
                ),
              ),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmtShort(checkIn)} → ${fmtShort(checkOut)} · ${plural(nights, 'night')}', style: T.small),
              const SizedBox(height: 2),
              AnimatedNumber(total, format: (v) => peso(v.round()), style: T.h2),
            ]),
          ),
          Btn('Confirm booking', expand: false, loading: busy, onTap: ok ? () => _submit(s, r) : null),
        ]),
      ),
    );
  }
}

/// One list on a phone; two side-by-side columns in landscape / on tablets.
class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});
  final List<Widget> left, right;
  @override
  Widget build(BuildContext context) {
    if (!Screen.wide(context)) return ListView(padding: const EdgeInsets.only(bottom: 24), children: [...left, ...right]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: left)),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [const SizedBox(height: 0), ...right])),
    ]);
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.title, required this.price, required this.on, required this.onTap});
  final String title;
  final double price;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.99,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            AnimatedContainer(
              duration: Motion.medium,
              curve: Curves.easeOutBack,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: on ? C.accent : C.card2,
                borderRadius: BorderRadius.circular(5),
              ),
              child: AnimatedScale(
                scale: on ? 1 : 0,
                duration: Motion.medium,
                curve: Curves.easeOutBack,
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
            Text(peso(price), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// "Booking sent" popup with the orange sticker (reference style).
Future<void> _showSent(BuildContext context, Booking b) => showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xCC000000),
      transitionDuration: const Duration(milliseconds: 420),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
      ),
      pageBuilder: (ctx, _, __) => Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20)),
          child: Material(
            color: Colors.transparent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.rotate(angle: (1 - v) * -0.5, child: Transform.scale(scale: v, child: child)),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.auto_awesome, size: 40, color: Colors.black),
                ),
              ),
              const SizedBox(height: 18),
              Text('Booking sent!', style: T.h2),
              const SizedBox(height: 6),
              Text('${b.code} · ${b.roomName}\nWe\'ll confirm it shortly. You can cancel while it\'s pending.', textAlign: TextAlign.center, style: T.bodyMuted),
              const SizedBox(height: 20),
              Btn('View booking', onTap: () => Navigator.of(ctx).pop()),
            ]),
          ),
        ),
      ),
    );
